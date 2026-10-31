import Foundation
import AppKit

/// Direct low-level wrapper around macOS MediaRemote.framework commands.
/// Controls whichever audio or video source is currently registered in macOS Now Playing
/// (Safari, YouTube in WebKit, Chrome, Spotify, Apple Music, QuickTime, Podcasts, etc.)
/// without requiring brittle AppleScript or browser JavaScript automation permissions.
enum MediaRemoteController {
    private typealias MRMediaRemoteSendCommandFunction = @convention(c) (Int32, CFDictionary?) -> Bool

    private static let sendCommandFn: MRMediaRemoteSendCommandFunction? = {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW) else {
            NSLog("[Harmonotch:MediaRemote] Failed to dlopen MediaRemote.framework")
            return nil
        }
        guard let sym = dlsym(handle, "MRMediaRemoteSendCommand") else {
            NSLog("[Harmonotch:MediaRemote] Failed to resolve MRMediaRemoteSendCommand symbol")
            return nil
        }
        return unsafeBitCast(sym, to: MRMediaRemoteSendCommandFunction.self)
    }()

    // Command Codes from MediaRemote.framework:
    // 0 = Play
    // 1 = Pause
    // 2 = TogglePlayPause
    // 3 = Stop
    // 4 = NextTrack
    // 5 = PreviousTrack
    // 6 = BeginFastForward
    // 7 = EndFastForward
    // 8 = BeginRewind
    // 9 = EndRewind
    // 24 = SeekToPosition

    @discardableResult
    static func sendCommand(_ command: Int32, options: CFDictionary? = nil) -> Bool {
        guard let fn = sendCommandFn else { return false }
        let success = fn(command, options)
        NSLog("[Harmonotch:MediaRemote] sendCommand(%d) -> %@", command, success ? "success" : "failed")
        return success
    }

    @discardableResult
    static func play() -> Bool {
        return sendCommand(0)
    }

    @discardableResult
    static func pause() -> Bool {
        return sendCommand(1)
    }

    @discardableResult
    static func togglePlayPause(currentlyPlaying: Bool? = nil) -> Bool {
        if let playing = currentlyPlaying {
            // Explicit Play or Pause is significantly more reliable across WebKit/Safari/YouTube
            return playing ? pause() : play()
        }
        // Fallback to TogglePlayPause
        return sendCommand(2)
    }

    @discardableResult
    static func next() -> Bool {
        return sendCommand(4)
    }

    @discardableResult
    static func previous() -> Bool {
        return sendCommand(5)
    }

    @discardableResult
    static func seek(to seconds: Double) -> Bool {
        let options: [String: Any] = ["kMRMediaRemoteOptionPlaybackPosition": seconds]
        return sendCommand(24, options: options as CFDictionary)
    }
}
