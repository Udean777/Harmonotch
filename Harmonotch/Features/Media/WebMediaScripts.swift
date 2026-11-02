import Foundation

/// AppleScript builders for reading and controlling media elements in browser tabs.
/// Scripts never throw: failures come back as an `ERR<TAB>number<TAB>message` line.
enum WebMediaScripts {
  static let mediaURLFragments = [
    "youtube.com", "youtu.be", "open.spotify.com", "soundcloud.com", "twitch.tv", "netflix.com",
  ]

  static let probeJS = """
    (() => { const v = document.querySelector('video') || document.querySelector('audio'); \
    if (!v) return ''; \
    const md = navigator.mediaSession && navigator.mediaSession.metadata; \
    const art = md && md.artwork && md.artwork.length ? md.artwork[md.artwork.length - 1].src : ''; \
    return JSON.stringify({paused: v.paused, t: v.currentTime, \\
    d: isFinite(v.duration) ? v.duration : 0, \\
    title: (md && md.title) || document.title, artist: (md && md.artist) || '', art: art}); })()
    """

  static func playJS() -> String {
    "(() => { const v = document.querySelector('video') || document.querySelector('audio'); "
      + "if (!v) return 'none'; const p = v.play(); "
      + "if (p && p.catch) p.catch(() => { const b = document.querySelector('.ytp-play-button'); "
      + "if (b && v.paused) b.click(); }); return 'ok'; })()"
  }

  static func pauseJS() -> String {
    "(() => { const v = document.querySelector('video') || document.querySelector('audio'); "
      + "if (!v) return 'none'; v.pause(); return 'ok'; })()"
  }

  static func seekJS(to seconds: Double) -> String {
    "(() => { const v = document.querySelector('video') || document.querySelector('audio'); "
      + "if (!v) return 'none'; v.currentTime = \(max(0, seconds)); return 'ok'; })()"
  }

  static func nextJS() -> String {
    "(() => { const b = document.querySelector('.ytp-next-button, ytmusic-player-bar .next-button, "
      + "[data-testid=\"control-button-skip-forward\"]'); if (b) b.click(); return 'ok'; })()"
  }

  static func previousJS() -> String {
    "(() => { const b = document.querySelector('.ytp-prev-button, ytmusic-player-bar .previous-button, "
      + "[data-testid=\"control-button-skip-back\"]'); "
      + "if (b && getComputedStyle(b).display !== 'none') { b.click(); return 'ok'; } "
      + "const v = document.querySelector('video') || document.querySelector('audio'); "
      + "if (v) v.currentTime = 0; return 'ok'; })()"
  }

  private static var urlCondition: String {
    mediaURLFragments.map { "u contains \"\($0)\"" }.joined(separator: " or ")
  }

  private static func literal(_ text: String) -> String {
    let escaped =
      text
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
    return "\"\(escaped)\""
  }

  /// Lists every media tab with its player state. Safari and Chromium share one shape.
  static func probe(browser: String) -> String {
    let isSafari = browser == "Safari"
    let tabsName = "tabs of w"
    let run =
      isSafari
      ? "do JavaScript \(literal(probeJS)) in t"
      : "execute t javascript \(literal(probeJS))"
    return """
      set out to ""
      set errText to ""
      try
          tell application \(literal(browser))
              repeat with wi from 1 to count of windows
                  set w to window wi
                  repeat with ti from 1 to count of \(tabsName)
                      set t to tab ti of w
                      set u to URL of t
                      if \(urlCondition) then
                          try
                              set r to \(run)
                              if r is not missing value and r is not "" then
                                  set out to out & wi & tab & ti & tab & u & tab & r & linefeed
                              end if
                          on error eMsg number eNum
                              set errText to "ERR" & tab & eNum & tab & eMsg
                          end try
                      end if
                  end repeat
              end repeat
          end tell
      on error eMsg number eNum
          return "ERR" & tab & eNum & tab & eMsg
      end try
      if out is "" and errText is not "" then return errText
      return out
      """
  }

  /// Runs `js` in the tab whose URL equals `url`, so a tab that moved is still found.
  static func control(browser: String, url: String, js: String) -> String {
    let isSafari = browser == "Safari"
    let run =
      isSafari
      ? "do JavaScript \(literal(js)) in t"
      : "execute t javascript \(literal(js))"
    return """
      try
          tell application \(literal(browser))
              repeat with wi from 1 to count of windows
                  set w to window wi
                  repeat with ti from 1 to count of tabs of w
                      set t to tab ti of w
                      if (URL of t) is \(literal(url)) then
                          return \(run)
                      end if
                  end repeat
              end repeat
          end tell
      on error eMsg number eNum
          return "ERR" & tab & eNum & tab & eMsg
      end try
      return "ERR" & tab & "0" & tab & "tab not found"
      """
  }
}
