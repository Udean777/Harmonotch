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
typedef Boolean (*MRSendToPlayerFn)(int32_t, CFDictionaryRef, id, uint32_t, dispatch_queue_t,
                                    void (^)(void));
typedef void (*MRRegisterNotificationsFn)(dispatch_queue_t);

@interface MRClient : NSObject
- (NSString *)bundleIdentifier;
@end

@interface MRPlayerPath : NSObject
- (instancetype)initWithOrigin:(id)origin client:(id)client player:(id)player;
- (id)localResolvedPlayerPath;
@end

static const char *kFrameworkPath =
    "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote";

static struct {
  void *handle;
  MRGetInfoFn getInfo;
  MRGetStringFn getDisplayID;
  MRGetClientsFn getClients;
  MRSendToPlayerFn sendToPlayer;
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
static NSLock *WriteLock;
static NSObject *StateLock;
static NSString *LastSignature;
static NSString *LastArtworkKey;

static void *Symbol(const char *name) {
  if (!MR.handle) return NULL;
  return dlsym(MR.handle, name);
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
  MR.sendToPlayer =
      (MRSendToPlayerFn)Symbol("MRMediaRemoteSendCommandToPlayer");
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

static void EmitState(NSDictionary *info, NSString *displayID) {
  NSString *title = StringValue(info, KeyTitle);
  NSString *artist = StringValue(info, KeyArtist);
  NSString *album = StringValue(info, KeyAlbum);
  double duration = DoubleValue(info, KeyDuration);
  double elapsed = DoubleValue(info, KeyElapsed);
  double rate = DoubleValue(info, KeyRate);
  BOOL playing = rate > 0.5;
  NSDate *timestamp = [info[KeyTimestamp] isKindOfClass:[NSDate class]] ? info[KeyTimestamp] : nil;
  if (playing && timestamp) {
    // Elapsed is only stamped at `timestamp`; extrapolate so 1s refreshes stay in sync.
    elapsed = MAX(0, elapsed + [[NSDate date] timeIntervalSinceDate:timestamp] * rate);
  }
  NSString *contentID = StringValue(info, KeyContentID);
  if (contentID.length == 0) {
    contentID = [NSString stringWithFormat:@"%@|%@", title, artist];
  }

  NSData *artwork = [info[KeyArtwork] isKindOfClass:[NSData class]] ? info[KeyArtwork] : nil;
  // QuickTime rotates contentID on every command; artwork follows the track, not the item.
  NSString *artworkKey = [NSString stringWithFormat:@"%@|%@|%@", title, artist, album];
  if (title.length == 0 && artist.length == 0) artworkKey = contentID;

  // Elapsed only needs sub-second precision; paused state stays stable.
  double bucket = playing ? round(elapsed * 2) / 2 : 0;
  NSString *signature = [NSString stringWithFormat:@"%@|%@|%@|%@|%@|%d|%.1f", displayID,
                                                   title, artist, album, contentID, playing, bucket];

  BOOL emit = NO;
  BOOL artworkChanged = NO;
  @synchronized(StateLock) {
    artworkChanged = artwork.length > 0 && ![artworkKey isEqualToString:LastArtworkKey];
    emit = artworkChanged || ![signature isEqualToString:LastSignature];
    if (emit) {
      LastSignature = signature;
      if (artworkChanged) LastArtworkKey = artworkKey;
    }
  }
  if (!emit) return;

  NSMutableDictionary *out = [NSMutableDictionary dictionary];
  out[@"event"] = @"state";
  out[@"source"] = displayID.length ? displayID : @"";
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

static void RefreshState(void) {
  if (!MR.getInfo) return;
  MR.getInfo(WorkQueue, ^(CFDictionaryRef information) {
    NSDictionary *info = information ? (__bridge NSDictionary *)information : @{};
    MR.getDisplayID(WorkQueue, ^(CFStringRef value) {
      NSString *displayID = value ? (__bridge NSString *)value : @"";
      EmitState(info, displayID);
    });
  });
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

static id ClientForDisplayID(NSArray *clients, NSString *displayID) {
  if (clients.count == 0) return nil;
  for (id client in clients) {
    NSString *bundle = ((MRClient *)client).bundleIdentifier;
    if ([bundle isKindOfClass:[NSString class]] && [bundle isEqualToString:displayID]) {
      return client;
    }
  }
  return clients.firstObject;
}

static id PlayerPathForClient(id client) {
  Class pathClass = NSClassFromString(@"MRPlayerPath");
  if (!pathClass || !client) return nil;
  id path = [[pathClass alloc] initWithOrigin:nil client:client player:nil];
  if (!path) return nil;
  id resolved = [path localResolvedPlayerPath];
  return resolved ?: path;
}

static void HandleCommand(NSDictionary *command) {
  NSString *commandID = [command[@"id"] isKindOfClass:[NSString class]] ? command[@"id"] : @"";
  NSString *name = [command[@"cmd"] isKindOfClass:[NSString class]] ? command[@"cmd"] : @"";

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
    id client = ClientForDisplayID(clients, DisplayIDSync());
    id path = PlayerPathForClient(client);
    if (path) {
      sent = MR.sendToPlayer(code, (__bridge CFDictionaryRef)options, path, 0, WorkQueue, ^{});
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
  NSArray<NSString *> *names = @[
    @"kMRMediaRemoteNowPlayingInfoDidChangeNotification",
    @"kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
    @"kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
    @"kMRMediaRemoteNowPlayingApplicationClientStateDidChange",
    @"kMRMediaRemoteNowPlayingPlaybackQueueDidChangeNotification",
  ];
  for (NSString *name in names) {
    [[NSNotificationCenter defaultCenter] addObserverForName:name
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification *note) {
                                                    dispatch_async(WorkQueue, ^{
                                                      RefreshState();
                                                    });
                                                  }];
  }
}

void hnp_run(void) {
  WorkQueue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
  WriteLock = [NSLock new];
  StateLock = [NSObject new];

  if (!LoadMediaRemote()) {
    EmitJSON(@{@"event": @"error", @"message": @"MediaRemote unavailable"});
    exit(1);
  }

  MR.registerNotifications(WorkQueue);
  ObserveChanges();

  dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, WorkQueue);
  dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, NSEC_PER_SEC, 200 * NSEC_PER_MSEC);
  dispatch_source_set_event_handler(timer, ^{
    RefreshState();
  });
  dispatch_resume(timer);

  dispatch_async(WorkQueue, ^{
    ReadCommands();
  });
  RefreshState();

  dispatch_main();
}
