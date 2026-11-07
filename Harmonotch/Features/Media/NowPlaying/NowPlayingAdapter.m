// Now-playing adapter loaded into /usr/bin/perl by nowplaying.pl.
//
// macOS 15.4+ refuses MediaRemote reads and commands to apps it did not sign.
// perl is an Apple platform binary, so this adapter runs inside the perl
// process and talks to MediaRemote there. Output is newline-delimited JSON on
// stdout; every command arrives the same way on stdin. Logs go to stderr.
//
// The command path is the one verified on macOS 27: the global
// MRMediaRemoteSendCommand is accepted but silently ignored, so commands go
// through MRMediaRemoteSendCommandToPlayer with a resolved player path.

#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <dispatch/dispatch.h>

typedef void (*MRGetInfoFn)(dispatch_queue_t, void (^)(CFDictionaryRef));
typedef void (*MRGetStringFn)(dispatch_queue_t, void (^)(CFStringRef));
typedef void (*MRGetClientsFn)(dispatch_queue_t, void (^)(NSArray *));
// macOS 15+ signature: (playerPath, BOOL artwork, queue, block(info, cover)).
// The older 3-argument form crashes inside MediaRemote on current systems.
typedef void (*MRGetInfoForPlayerFn)(id, BOOL, dispatch_queue_t,
                                     void (^)(CFDictionaryRef, const void *));
typedef void (*MRGetStateForPlayerFn)(id, dispatch_queue_t, void (^)(unsigned int));
typedef Boolean (*MRSendToPlayerFn)(int32_t, CFDictionaryRef, id, uint32_t, dispatch_queue_t,
                                    void (^)(uint32_t, NSArray *));
typedef CFDataRef (*MRArtworkCopyFn)(const void *);
typedef CFStringRef (*MRClientStringFn)(id);
typedef pid_t (*MRGetClientPIDFn)(id);
typedef void (*MRRegisterNotificationsFn)(dispatch_queue_t);

@interface MRClient : NSObject
- (NSString *)bundleIdentifier;
- (instancetype)initWithBundleIdentifier:(NSString *)bundleID;
- (void)setProcessIdentifier:(int)pid;
@end

@interface MRPlayerPath : NSObject
+ (instancetype)localPlayerPath;
- (void)setClient:(id)client;
- (void)setPlayer:(id)player;
@end

static const char *kFrameworkPath =
    "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote";

static struct {
  void *handle;
  MRGetInfoFn getInfo;
  MRGetStringFn getDisplayID;
  MRGetClientsFn getClients;
  MRGetInfoForPlayerFn getInfoForPlayer;
  MRGetStateForPlayerFn getStateForPlayer;
  MRSendToPlayerFn sendToPlayer;
  MRArtworkCopyFn copyArtwork;
  MRClientStringFn getClientParentBundle;
  MRGetClientPIDFn getClientPID;
  MRRegisterNotificationsFn registerNotifications;
} MR;

// NSString constant names are also the dictionary keys MediaRemote uses.
static NSString *const KeyTitle = @"kMRMediaRemoteNowPlayingInfoTitle";
static NSString *const KeyArtist = @"kMRMediaRemoteNowPlayingInfoArtist";
static NSString *const KeyAlbum = @"kMRMediaRemoteNowPlayingInfoAlbum";
static NSString *const KeyDuration = @"kMRMediaRemoteNowPlayingInfoDuration";
static NSString *const KeyElapsed = @"kMRMediaRemoteNowPlayingInfoElapsedTime";
static NSString *const KeyRate = @"kMRMediaRemoteNowPlayingInfoPlaybackRate";
static NSString *const KeyContentID = @"kMRMediaRemoteNowPlayingInfoContentItemIdentifier";
static NSString *const KeyArtwork = @"kMRMediaRemoteNowPlayingInfoArtworkData";
static NSString *const KeyTimestamp = @"kMRMediaRemoteNowPlayingInfoTimestamp";
static NSString *const OptionSeekPosition = @"kMRMediaRemoteOptionPlaybackPosition";

static dispatch_queue_t WorkQueue;
static dispatch_queue_t StdinQueue;
static dispatch_source_t RefreshCoalesceTimer;
static NSLock *WriteLock;
static NSObject *StateLock;
static NSMutableDictionary<NSString *, NSString *> *LastSignaturesBySource;
static NSMutableDictionary<NSString *, NSString *> *LastArtworkKeyBySource;

static void *Symbol(const char *name) {
  if (!MR.handle) return NULL;
  return dlsym(MR.handle, name);
}

/// Reads a MediaRemote notification name from its exported string constant.
/// Some names differ from the symbol (macOS 27 adds a leading underscore),
/// so a literal would silently never fire.
static NSString *StringConstant(const char *name) {
  void *symbol = Symbol(name);
  if (!symbol) return nil;
  NSString *value = *(NSString *__unsafe_unretained *)symbol;
  return [value isKindOfClass:[NSString class]] ? value : nil;
}

static BOOL LoadMediaRemote(void) {
  MR.handle = dlopen(kFrameworkPath, RTLD_NOW);
  if (!MR.handle) {
    fprintf(stderr, "nowplaying: dlopen failed: %s\n", dlerror());
    return NO;
  }
  MR.getInfo = (MRGetInfoFn)Symbol("MRMediaRemoteGetNowPlayingInfo");
  MR.getDisplayID =
      (MRGetStringFn)Symbol("MRMediaRemoteGetNowPlayingApplicationDisplayID");
  MR.getClients = (MRGetClientsFn)Symbol("MRMediaRemoteGetNowPlayingClients");
  MR.getInfoForPlayer = (MRGetInfoForPlayerFn)Symbol("MRMediaRemoteGetNowPlayingInfoForPlayer");
  MR.getStateForPlayer = (MRGetStateForPlayerFn)Symbol("MRMediaRemoteGetPlaybackStateForPlayer");
  MR.sendToPlayer =
      (MRSendToPlayerFn)Symbol("MRMediaRemoteSendCommandToPlayer");
  MR.copyArtwork =
      (MRArtworkCopyFn)Symbol("MRNowPlayingArtworkCopyImageData");
  MR.getClientParentBundle =
      (MRClientStringFn)Symbol("MRNowPlayingClientGetParentAppBundleIdentifier");
  MR.getClientPID =
      (MRGetClientPIDFn)Symbol("MRNowPlayingClientGetProcessIdentifier");
  MR.registerNotifications =
      (MRRegisterNotificationsFn)Symbol("MRMediaRemoteRegisterForNowPlayingNotifications");
  return MR.getInfo && MR.getDisplayID && MR.getClients && MR.sendToPlayer &&
         MR.registerNotifications;
}

static void EmitJSON(NSDictionary *object) {
  NSData *data = [NSJSONSerialization dataWithJSONObject:object options:0 error:NULL];
  if (!data) return;
  [WriteLock lock];
  fwrite(data.bytes, 1, data.length, stdout);
  fputc('\n', stdout);
  fflush(stdout);
  [WriteLock unlock];
}

static NSString *StringValue(NSDictionary *info, NSString *key) {
  id value = info[key];
  return [value isKindOfClass:[NSString class]] ? value : @"";
}

static double DoubleValue(NSDictionary *info, NSString *key) {
  id value = info[key];
  return [value isKindOfClass:[NSNumber class]] ? [value doubleValue] : 0;
}

static NSData *ArtworkDataFromCover(const void *cover) {
  if (!cover || !MR.copyArtwork) return nil;
  CFDataRef data = MR.copyArtwork(cover);
  return data ? (__bridge_transfer NSData *)data : nil;
}

static void EmitState(NSDictionary *info, NSString *displayID, NSString *clientID,
                      NSNumber *overrideState) {
  if (displayID.length == 0) return;
  NSString *title = StringValue(info, KeyTitle);
  NSString *artist = StringValue(info, KeyArtist);
  NSString *album = StringValue(info, KeyAlbum);
  double duration = DoubleValue(info, KeyDuration);
  double elapsed = DoubleValue(info, KeyElapsed);
  double rate = DoubleValue(info, KeyRate);
  BOOL playing = NO;
  if (overrideState != nil) {
    unsigned int st = [overrideState unsignedIntValue];
    // 0 = Unknown, 1 = Playing, 2 = Paused, 3 = Stopped, 4 = Interrupted, 5 = Seeking
    if (st == 1) {
      playing = YES;
      if (rate <= 0) {
        rate = 1.0;
      }
    } else if (st >= 2 && st <= 4) {
      playing = NO;
      rate = 0.0;
    } else {
      // st == 0 (Unknown) or st == 5 (Seeking): fall back to rate
      playing = rate > 0.5;
      if (!playing) {
        rate = 0.0;
      }
    }
  } else {
    playing = rate > 0.5;
    if (!playing) {
      rate = 0.0;
    }
  }

  NSDate *timestamp = [info[KeyTimestamp] isKindOfClass:[NSDate class]] ? info[KeyTimestamp] : nil;
  if (playing && timestamp) {
    // Elapsed is only stamped at `timestamp`; extrapolate so 1s refreshes stay in sync.
    elapsed = MAX(0, elapsed + [[NSDate date] timeIntervalSinceDate:timestamp] * rate);
  }
  NSString *contentID = StringValue(info, KeyContentID);
  if (contentID.length == 0) {
    contentID = [NSString stringWithFormat:@"%@|%@", title, artist];
  }
  // A browser publishes one client per tab; key state by client + content so
  // tabs do not overwrite each other's last signature.
  NSString *clientKey = clientID.length ? clientID : displayID;
  NSString *stateKey = [NSString stringWithFormat:@"%@|%@", clientKey, contentID];

  NSData *artwork = [info[KeyArtwork] isKindOfClass:[NSData class]] ? info[KeyArtwork] : nil;
  // QuickTime rotates contentID on every command; artwork follows displayID + track.
  NSString *artworkKey = [NSString stringWithFormat:@"%@|%@|%@|%@", displayID, title, artist, album];
  if (title.length == 0 && artist.length == 0) {
    artworkKey = [NSString stringWithFormat:@"%@|%@", displayID, contentID];
  }

  // Elapsed only needs sub-second precision; paused state stays stable.
  double bucket = playing ? round(elapsed * 2) / 2 : 0;
  NSString *signature = [NSString stringWithFormat:@"%@|%@|%@|%@|%@|%d|%.1f", displayID,
                                                   title, artist, album, contentID, playing, bucket];

  BOOL emit = NO;
  BOOL artworkChanged = NO;
  @synchronized(StateLock) {
    if (title.length == 0 && artist.length == 0 && !playing) {
      // This client has stopped / cleared its media.
      BOOL hadState = NO;
      NSString *prefix = [NSString stringWithFormat:@"%@|", clientKey];
      for (NSString *key in LastSignaturesBySource.allKeys) {
        if ([key hasPrefix:prefix]) {
          [LastSignaturesBySource removeObjectForKey:key];
          [LastArtworkKeyBySource removeObjectForKey:key];
          hadState = YES;
        }
      }
      emit = hadState;
    } else {
      NSString *lastArt = LastArtworkKeyBySource[stateKey];
      BOOL keyChanged = ![artworkKey isEqualToString:lastArt];
      artworkChanged = artwork.length > 0 && keyChanged;
      NSString *lastSig = LastSignaturesBySource[stateKey];
      emit = artworkChanged || ![signature isEqualToString:lastSig];
      if (emit) {
        LastSignaturesBySource[stateKey] = signature;
        // Only remember the key once artwork actually arrived. Marking it on
        // an empty poll made MediaRemote's first artwork-less read permanent,
        // so the cover never showed for that track.
        if (artworkChanged) {
          LastArtworkKeyBySource[stateKey] = artworkKey;
        }
      }
    }
  }
  if (!emit) return;

  NSMutableDictionary *out = [NSMutableDictionary dictionary];
  out[@"event"] = @"state";
  out[@"source"] = displayID;
  out[@"title"] = title;
  out[@"artist"] = artist;
  out[@"album"] = album;
  out[@"duration"] = @(duration);
  out[@"elapsed"] = @(elapsed);
  out[@"rate"] = @(rate);
  out[@"playing"] = @(playing);
  out[@"contentID"] = contentID;
  if (artworkChanged) {
    out[@"artwork"] = [artwork base64EncodedStringWithOptions:0];
  }
  EmitJSON(out);
}

// MARK: - Commands

static NSArray *ClientsSync(void) {
  __block NSArray *clients = nil;
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  MR.getClients(WorkQueue, ^(NSArray *value) {
    clients = value;
    dispatch_semaphore_signal(sem);
  });
  dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC));
  return clients;
}

static NSString *DisplayIDSync(void) {
  __block NSString *displayID = @"";
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  MR.getDisplayID(WorkQueue, ^(CFStringRef value) {
    displayID = value ? (__bridge NSString *)value : @"";
    dispatch_semaphore_signal(sem);
  });
  dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC));
  return displayID;
}

static NSString *ParentBundleOfClient(id client) {
  if (!client || !MR.getClientParentBundle) return @"";
  CFStringRef value = MR.getClientParentBundle(client);
  return value ? (__bridge NSString *)value : @"";
}

static id ClientForBundleID(NSArray *clients, NSString *bundleID) {
  if (clients.count == 0 || bundleID.length == 0) return nil;
  for (id client in clients) {
    NSString *bundle = ((MRClient *)client).bundleIdentifier;
    if ([bundle isKindOfClass:[NSString class]] && [bundle isEqualToString:bundleID]) {
      return client;
    }
  }
  // Browser/helper clients report their own bundle ID; a command targeted at
  // the parent app (e.g. com.apple.Safari) still needs to reach them.
  for (id client in clients) {
    NSString *parent = ParentBundleOfClient(client);
    if (parent.length > 0 && [parent isEqualToString:bundleID]) {
      return client;
    }
  }
  return nil;
}

static id ClientForDisplayID(NSArray *clients, NSString *displayID) {
  if (clients.count == 0) return nil;
  id matched = ClientForBundleID(clients, displayID);
  return matched ?: clients.firstObject;
}

static id PlayerPathForBundle(NSString *bundleID, pid_t pid) {
  if (bundleID.length == 0) return nil;
  id pathClass = NSClassFromString(@"MRPlayerPath");
  id clientClass = NSClassFromString(@"MRClient");
  if (!pathClass || !clientClass) return nil;
  id path = [[(id)pathClass localPlayerPath] copy];
  id client = [[clientClass alloc] initWithBundleIdentifier:bundleID];
  if (!path || !client) return nil;
  if (pid > 0 && [client respondsToSelector:@selector(setProcessIdentifier:)]) {
    [client setProcessIdentifier:pid];
  }
  [path setClient:client];
  // Nil resolves this app's active player; "default" is a different session.
  [path setPlayer:nil];
  return path;
}

static id PlayerPathForClient(id client) {
  if (!client) return nil;
  NSString *bundleID = ((MRClient *)client).bundleIdentifier;
  pid_t pid = (MR.getClientPID != NULL) ? MR.getClientPID(client) : 0;
  return [bundleID isKindOfClass:[NSString class]] ? PlayerPathForBundle(bundleID, pid) : nil;
}

static void RefreshState(void);

static void ScheduleRefresh(void) {
  dispatch_async(WorkQueue, ^{
    if (RefreshCoalesceTimer) {
      dispatch_source_cancel(RefreshCoalesceTimer);
      RefreshCoalesceTimer = nil;
    }
    RefreshCoalesceTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, WorkQueue);
    dispatch_source_set_timer(RefreshCoalesceTimer,
                              dispatch_time(DISPATCH_TIME_NOW, 40 * NSEC_PER_MSEC),
                              DISPATCH_TIME_FOREVER, 10 * NSEC_PER_MSEC);
    dispatch_source_set_event_handler(RefreshCoalesceTimer, ^{
      if (RefreshCoalesceTimer) {
        dispatch_source_cancel(RefreshCoalesceTimer);
        RefreshCoalesceTimer = nil;
      }
      RefreshState();
    });
    dispatch_resume(RefreshCoalesceTimer);
  });
}

static void RefreshState(void) {
  if (MR.getClients && MR.getInfoForPlayer) {
    MR.getClients(WorkQueue, ^(NSArray *clients) {
      if (clients.count > 0) {
        for (id client in clients) {
          NSString *bundleID = ((MRClient *)client).bundleIdentifier;
          if (![bundleID isKindOfClass:[NSString class]] || bundleID.length == 0) continue;
          NSString *parentBundle = ParentBundleOfClient(client);
          NSString *presentationID = parentBundle.length > 0 ? parentBundle : bundleID;
          id playerPath = PlayerPathForClient(client);
          if (!playerPath) continue;
          MR.getInfoForPlayer(playerPath, YES, WorkQueue, ^(CFDictionaryRef infoRef, const void *cover) {
            NSDictionary *info = infoRef ? (__bridge NSDictionary *)infoRef : @{};
            NSData *artwork = ArtworkDataFromCover(cover);
            if (artwork) {
              NSMutableDictionary *withArtwork = [info mutableCopy];
              withArtwork[KeyArtwork] = artwork;
              info = withArtwork;
            }
            if (MR.getStateForPlayer) {
              MR.getStateForPlayer(playerPath, WorkQueue, ^(unsigned int state) {
                EmitState(info, presentationID, bundleID, @(state));
              });
            } else {
              EmitState(info, presentationID, bundleID, nil);
            }
          });
        }

        if (MR.getDisplayID && MR.getInfo) {
          MR.getDisplayID(WorkQueue, ^(CFStringRef value) {
            NSString *displayID = value ? (__bridge NSString *)value : @"";
            if (displayID.length > 0 && !ClientForBundleID(clients, displayID)) {
              MR.getInfo(WorkQueue, ^(CFDictionaryRef information) {
                NSDictionary *info = information ? (__bridge NSDictionary *)information : @{};
                EmitState(info, displayID, displayID, nil);
              });
            }
          });
        }
        return;
      }

      if (MR.getInfo && MR.getDisplayID) {
        MR.getInfo(WorkQueue, ^(CFDictionaryRef information) {
          NSDictionary *info = information ? (__bridge NSDictionary *)information : @{};
          MR.getDisplayID(WorkQueue, ^(CFStringRef value) {
            NSString *displayID = value ? (__bridge NSString *)value : @"";
            EmitState(info, displayID, displayID, nil);
          });
        });
      }
    });
    return;
  }

  if (MR.getInfo && MR.getDisplayID) {
    MR.getInfo(WorkQueue, ^(CFDictionaryRef information) {
      NSDictionary *info = information ? (__bridge NSDictionary *)information : @{};
      MR.getDisplayID(WorkQueue, ^(CFStringRef value) {
        NSString *displayID = value ? (__bridge NSString *)value : @"";
        EmitState(info, displayID, displayID, nil);
      });
    });
  }
}

static void HandleCommand(NSDictionary *command) {
  NSString *commandID = [command[@"id"] isKindOfClass:[NSString class]] ? command[@"id"] : @"";
  NSString *name = [command[@"cmd"] isKindOfClass:[NSString class]] ? command[@"cmd"] : @"";
  NSString *target = [command[@"target"] isKindOfClass:[NSString class]] ? command[@"target"] : nil;

  int32_t code = -1;
  NSDictionary *options = nil;
  if ([name isEqualToString:@"play"]) {
    code = 0;
  } else if ([name isEqualToString:@"pause"]) {
    code = 1;
  } else if ([name isEqualToString:@"toggle"]) {
    code = 2;
  } else if ([name isEqualToString:@"next"]) {
    code = 4;
  } else if ([name isEqualToString:@"previous"]) {
    code = 5;
  } else if ([name isEqualToString:@"seek"]) {
    code = 24;
    double position = [command[@"position"] isKindOfClass:[NSNumber class]]
                          ? [command[@"position"] doubleValue]
                          : 0;
    options = @{OptionSeekPosition: @(MAX(0, position))};
  }

  BOOL sent = NO;
  if (code >= 0) {
    NSArray *clients = ClientsSync();
    id client = nil;
    if (target.length > 0) {
      client = ClientForBundleID(clients, target);
    }
    if (!client) {
      client = ClientForDisplayID(clients, DisplayIDSync());
    }
    id path = PlayerPathForClient(client);
    if (path) {
      sent = MR.sendToPlayer(code, (__bridge CFDictionaryRef)options, path, 0, WorkQueue,
                             ^(uint32_t error, NSArray *responses) {});
    }
  }

  EmitJSON(@{@"event": @"result", @"id": commandID, @"ok": @(sent)});
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), WorkQueue, ^{
    RefreshState();
  });
}

static void ReadCommands(void) {
  NSFileHandle *input = [NSFileHandle fileHandleWithStandardInput];
  NSData *newline = [@"\n" dataUsingEncoding:NSUTF8StringEncoding];
  NSMutableData *buffer = [NSMutableData data];
  while (YES) {
    NSData *chunk = [input availableData];
    if (chunk.length == 0) break;
    [buffer appendData:chunk];
    while (YES) {
      NSRange range = [buffer rangeOfData:newline options:0 range:NSMakeRange(0, buffer.length)];
      if (range.location == NSNotFound) break;
      NSData *line = [buffer subdataWithRange:NSMakeRange(0, range.location)];
      [buffer replaceBytesInRange:NSMakeRange(0, NSMaxRange(range)) withBytes:NULL length:0];
      if (line.length == 0) continue;
      NSDictionary *command = [NSJSONSerialization JSONObjectWithData:line options:0 error:NULL];
      if ([command isKindOfClass:[NSDictionary class]]) {
        dispatch_async(WorkQueue, ^{
          HandleCommand(command);
        });
      } else {
        EmitJSON(@{@"event": @"error", @"message": @"invalid command"});
      }
    }
  }
  exit(0);
}

static void ObserveChanges(void) {
  NSMutableArray<NSString *> *names = [@[
    @"kMRMediaRemoteNowPlayingInfoDidChangeNotification",
    @"kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
    @"kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
    @"kMRMediaRemoteNowPlayingApplicationClientStateDidChange",
    @"kMRMediaRemoteNowPlayingPlaybackQueueDidChangeNotification",
    // Player-level changes, not only the system's current player. Firefox in
    // particular posts pause here, and missing it left the app waiting for
    // the one-second poll before it stopped showing playback.
    @"kMRMediaRemotePlayerIsPlayingDidChangeNotification",
    @"kMRMediaRemotePlayerNowPlayingInfoDidChangeNotification",
    @"kMRMediaRemoteNowPlayingPlayerStateDidChange",
  ] mutableCopy];
  NSString *playbackState = StringConstant("kMRMediaRemotePlayerPlaybackStateDidChangeNotification");
  if (playbackState) [names addObject:playbackState];

  for (NSString *name in names) {
    [[NSNotificationCenter defaultCenter] addObserverForName:name
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
                                                    ScheduleRefresh();
                                                  }];
  }
}

void hnp_run(void) {
  WorkQueue = dispatch_queue_create("com.harmonotch.nowplaying.work", DISPATCH_QUEUE_SERIAL);
  StdinQueue = dispatch_queue_create("com.harmonotch.nowplaying.stdin", DISPATCH_QUEUE_SERIAL);
  WriteLock = [NSLock new];
  StateLock = [NSObject new];
  LastSignaturesBySource = [NSMutableDictionary new];
  LastArtworkKeyBySource = [NSMutableDictionary new];

  if (!LoadMediaRemote()) {
    EmitJSON(@{@"event": @"error", @"message": @"MediaRemote unavailable"});
    exit(1);
  }

  MR.registerNotifications(dispatch_get_main_queue());
  ObserveChanges();

  dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, WorkQueue);
  dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, NSEC_PER_SEC / 2, 100 * NSEC_PER_MSEC);
  dispatch_source_set_event_handler(timer, ^{
    RefreshState();
  });
  dispatch_resume(timer);

  dispatch_async(StdinQueue, ^{
    ReadCommands();
  });
  dispatch_async(WorkQueue, ^{
    RefreshState();
  });

  [[NSRunLoop mainRunLoop] run];
}
