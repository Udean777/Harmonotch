import Foundation

/// State of one media element found in a browser tab.
nonisolated struct WebMediaSnapshot: Equatable {
  var browser: String
  var windowIndex: Int
  var tabIndex: Int
  var url: String
  var title: String
  var artist: String
  var artworkURL: String
  var isPaused: Bool
  var currentTime: Double
  var duration: Double
}

/// Why a browser could not be read or controlled. Both are fixed by the user.
nonisolated enum WebMediaProbeError: Equatable {
  /// macOS Automation permission for the browser was denied.
  case automationDenied(browser: String)
  /// The browser refuses JavaScript from Apple Events.
  case javascriptDisabled(browser: String)
}

/// Pure parsing and selection logic for the AppleScript output of the browser probe.
/// Kept free of AppKit so `Tests/run-tests.sh` can compile it on its own.
nonisolated enum WebMediaParser {
  /// One tab per line: `window<TAB>tab<TAB>url<TAB>json`.
  /// A failure is reported as `ERR<TAB>number<TAB>message`.
  static func parse(output: String, browser: String) -> [WebMediaSnapshot] {
    var snapshots: [WebMediaSnapshot] = []
    for line in output.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
      let fields = line.split(separator: "\t", maxSplits: 3, omittingEmptySubsequences: false)
      guard fields.count == 4,
        let window = Int(fields[0]), let tab = Int(fields[1]),
        let data = fields[3].data(using: .utf8),
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
      else { continue }

      let current = finite(object["t"])
      let duration = finite(object["d"])
      snapshots.append(
        WebMediaSnapshot(
          browser: browser, windowIndex: window, tabIndex: tab, url: String(fields[2]),
          title: (object["title"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
          artist: (object["artist"] as? String ?? "").trimmingCharacters(
            in: .whitespacesAndNewlines),
          artworkURL: object["art"] as? String ?? "",
          isPaused: object["paused"] as? Bool ?? true,
          currentTime: current, duration: duration))
    }
    return snapshots
  }

  /// Extracts the error from an `ERR<TAB>number<TAB>message` line, if the output holds one.
  static func error(from output: String, browser: String) -> WebMediaProbeError? {
    for line in output.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
      let fields = line.split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false)
      guard fields.count == 3, fields[0] == "ERR" else { continue }
      return classify(code: Int(fields[1]) ?? 0, message: String(fields[2]), browser: browser)
    }
    return nil
  }

  static func classify(code: Int, message: String, browser: String) -> WebMediaProbeError? {
    if code == -1743 { return .automationDenied(browser: browser) }
    let lower = message.lowercased()
    if lower.contains("apple events") || lower.contains("allow javascript") {
      return .javascriptDisabled(browser: browser)
    }
    return nil
  }

  /// A playing tab wins. Otherwise the tab the user was last shown (`preferredURL`) stays,
  /// then any paused tab that has progressed.
  static func pick(from snapshots: [WebMediaSnapshot], preferredURL: String? = nil)
    -> WebMediaSnapshot?
  {
    if let playing = snapshots.first(where: { !$0.isPaused }) { return playing }
    if let preferredURL, let same = snapshots.first(where: { $0.url == preferredURL }) {
      return same
    }
    return snapshots.first(where: { $0.currentTime > 0 })
  }

  private static func finite(_ value: Any?) -> Double {
    guard let number = (value as? NSNumber)?.doubleValue, number.isFinite, number >= 0 else {
      return 0
    }
    return number
  }
}
