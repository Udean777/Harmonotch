import Foundation

/// AppleScript builders for reading and controlling media elements in browser tabs.
/// Scripts never throw: failures come back as an `ERR<TAB>number<TAB>message` line.
enum WebMediaScripts {
  static let mediaURLFragments = [
    "youtube.com", "youtu.be", "open.spotify.com", "soundcloud.com", "twitch.tv", "netflix.com",
    "bilibili.com", "vimeo.com", "dailymotion.com", "music.apple.com", "deezer.com",
    "tidal.com", "bandcamp.com", "disneyplus.com", "primevideo.com", "hulu.com",
    "max.com", "audiomack.com", "tiktok.com", "podcasts.apple.com",
  ]

  static let probeJS = """
    (() => { \
    const all = Array.from(document.querySelectorAll('video, audio')); \
    if (!all.length) return ''; \
    const v = all.find(m => !m.paused && m.currentTime > 0) \
           || all.find(m => !m.paused) \
           || all.find(m => m.currentTime > 0) \
           || all[0]; \
    const md = navigator.mediaSession && navigator.mediaSession.metadata; \
    const art = md && md.artwork && md.artwork.length ? md.artwork[md.artwork.length - 1].src : ''; \
    return JSON.stringify({paused: v.paused, t: v.currentTime, \
    d: isFinite(v.duration) ? v.duration : 0, \
    title: (md && md.title) || document.title, artist: (md && md.artist) || '', art: art}); })()
    """

  static func playJS() -> String {
    "(() => { "
      + "const sp = document.querySelector('[data-testid=\"control-button-play\"]'); "
      + "if (sp) { sp.click(); return 'ok'; } "
      + "const ym = document.querySelector('ytmusic-player-bar #play-pause-button[aria-label*=\"Play\" i], ytmusic-player-bar #play-pause-button'); "
      + "const sc = document.querySelector('.playControl:not(.playing)'); "
      + "if (sc) { sc.click(); return 'ok'; } "
      + "const ytp = document.querySelector('.ytp-play-button'); "
      + "const all = Array.from(document.querySelectorAll('video, audio')); "
      + "const target = all.find(m => m.paused && m.currentTime > 0) || all.find(m => m.paused) || all[0]; "
      + "if (target) { "
      + "  const p = target.play(); "
      + "  if (p && p.catch) { p.catch(() => { if (ytp && target.paused) ytp.click(); }); } "
      + "  return 'ok'; "
      + "} "
      + "if (ym) { ym.click(); return 'ok'; } "
      + "if (ytp) { ytp.click(); return 'ok'; } "
      + "return 'none'; })()"
  }

  static func pauseJS() -> String {
    "(() => { "
      + "let handled = false; "
      + "const sp = document.querySelector('[data-testid=\"control-button-pause\"], [data-testid=\"control-button-playpause\"]'); "
      + "if (sp) { sp.click(); handled = true; } "
      + "const ym = document.querySelector('ytmusic-player-bar #play-pause-button[aria-label*=\"Pause\" i], ytmusic-player-bar .play-pause-button'); "
      + "if (ym) { ym.click(); handled = true; } "
      + "const sc = document.querySelector('.playControl.playing'); "
      + "if (sc) { sc.click(); handled = true; } "
      + "const ytpPlaying = document.querySelector('.html5-video-player.playing-mode .ytp-play-button'); "
      + "if (ytpPlaying) { ytpPlaying.click(); handled = true; } "
      + "const all = Array.from(document.querySelectorAll('video, audio')); "
      + "all.forEach(m => { if (!m.paused) { m.pause(); handled = true; } }); "
      + "return handled ? 'ok' : (all.length ? 'none' : 'no_media'); })()"
  }

  static func seekJS(to seconds: Double) -> String {
    "(() => { const all = Array.from(document.querySelectorAll('video, audio')); "
      + "const v = all.find(m => !m.paused && m.currentTime > 0) || all.find(m => m.currentTime > 0) || all[0]; "
      + "if (!v) return 'none'; v.currentTime = \(max(0, seconds)); return 'ok'; })()"
  }

  static func nextJS() -> String {
    "(() => { const b = document.querySelector('.ytp-next-button, ytmusic-player-bar .next-button, "
      + "[data-testid=\"control-button-skip-forward\"]'); if (b) { b.click(); return 'ok'; } return 'none'; })()"
  }

  static func previousJS() -> String {
    "(() => { const b = document.querySelector('.ytp-prev-button, ytmusic-player-bar .previous-button, "
      + "[data-testid=\"control-button-skip-back\"]'); "
      + "if (b && getComputedStyle(b).display !== 'none') { b.click(); return 'ok'; } "
      + "const all = Array.from(document.querySelectorAll('video, audio')); "
      + "const v = all.find(m => !m.paused && m.currentTime > 0) || all.find(m => m.currentTime > 0) || all[0]; "
      + "if (v) v.currentTime = 0; return 'ok'; })()"
  }

  private static var urlCondition: String {
    mediaURLFragments.map { "u contains \"\($0)\"" }.joined(separator: " or ")
  }

  /// Lists every media tab with its player state. Safari and Chromium share one shape.
  static func probe(browser: String) -> String {
    let isSafari = BrowserCatalog.scriptKind(forBrowserName: browser) == .safari
    let tabsName = "tabs of w"
    let run =
      isSafari
      ? "do JavaScript \(AppleScriptRunner.quotedLiteral(probeJS)) in t"
      : "execute t javascript \(AppleScriptRunner.quotedLiteral(probeJS))"
    let checkAudible = isSafari ? "" : """
                      set isAudible to false
                      try
                          set isAudible to (audible of t)
                      end try
    """
    let condition = isSafari ? "(\(urlCondition))" : "(\(urlCondition) or isAudible)"
    return """
      set out to ""
      set errText to ""
      try
          tell application \(AppleScriptRunner.quotedLiteral(browser))
              repeat with wi from 1 to count of windows
                  set w to window wi
                  repeat with ti from 1 to count of \(tabsName)
                      set t to tab ti of w
                      set u to URL of t
                      \(checkAudible)
                      if \(condition) then
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
    let isSafari = BrowserCatalog.scriptKind(forBrowserName: browser) == .safari
    let run =
      isSafari
      ? "do JavaScript \(AppleScriptRunner.quotedLiteral(js)) in t"
      : "execute t javascript \(AppleScriptRunner.quotedLiteral(js))"
    let findAudible = isSafari ? "" : """
              repeat with wi from 1 to count of windows
                  set w to window wi
                  repeat with ti from 1 to count of tabs of w
                      set t to tab ti of w
                      try
                          if audible of t then
                              return \(run)
                          end if
                      end try
                  end repeat
              end repeat
    """
    let fallbackActiveTab = isSafari ? """
              try
                  set t to current tab of front window
                  return \(run)
              end try
    """ : """
              try
                  set t to active tab of front window
                  return \(run)
              end try
    """

    return """
      try
          tell application \(AppleScriptRunner.quotedLiteral(browser))
              set targetURL to \(AppleScriptRunner.quotedLiteral(url))
              if targetURL is not "" then
                  repeat with wi from 1 to count of windows
                      set w to window wi
                      repeat with ti from 1 to count of tabs of w
                          set t to tab ti of w
                          set currentURL to ""
                          try
                              set currentURL to URL of t
                          end try
                          if currentURL is targetURL or currentURL contains targetURL or targetURL contains currentURL then
                              return \(run)
                          end if
                      end repeat
                  end repeat
              end if
              \(findAudible)
              \(fallbackActiveTab)
          end tell
      on error eMsg number eNum
          return "ERR" & tab & eNum & tab & eMsg
      end try
      return "ERR" & tab & "0" & tab & "tab not found"
      """
  }
}
