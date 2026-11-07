import Foundation

public nonisolated enum BrowserScriptKind: Equatable, Sendable {
  case safari
  case chromium
  case none
}

public nonisolated struct BrowserCatalogEntry: Equatable, Sendable {
  public let name: String
  public let bundleIDs: [String]
  public let scriptKind: BrowserScriptKind
}

public nonisolated enum BrowserCatalog {
  public static let entries: [BrowserCatalogEntry] = [
    BrowserCatalogEntry(
      name: "Safari",
      bundleIDs: [
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
        "com.apple.WebKit.GPU",
        "com.apple.WebKit.WebContent",
      ],
      scriptKind: .safari
    ),
    BrowserCatalogEntry(
      name: "Google Chrome",
      bundleIDs: [
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "com.google.Chrome.beta",
        "com.google.Chrome.dev",
      ],
      scriptKind: .chromium
    ),
    BrowserCatalogEntry(
      name: "Arc",
      bundleIDs: ["company.thebrowser.Browser"],
      scriptKind: .chromium
    ),
    BrowserCatalogEntry(
      name: "Brave Browser",
      bundleIDs: [
        "com.brave.Browser",
        "com.brave.Browser.beta",
        "com.brave.Browser.nightly",
      ],
      scriptKind: .chromium
    ),
    BrowserCatalogEntry(
      name: "Microsoft Edge",
      bundleIDs: [
        "com.microsoft.edgemac",
        "com.microsoft.edgemac.Beta",
        "com.microsoft.edgemac.Dev",
        "com.microsoft.edgemac.Canary",
      ],
      scriptKind: .chromium
    ),
    BrowserCatalogEntry(
      name: "Opera",
      bundleIDs: [
        "com.operasoftware.Opera",
        "com.operasoftware.OperaGX",
      ],
      scriptKind: .chromium
    ),
    BrowserCatalogEntry(
      name: "Vivaldi",
      bundleIDs: ["com.vivaldi.Vivaldi"],
      scriptKind: .chromium
    ),
    BrowserCatalogEntry(
      name: "Firefox",
      bundleIDs: [
        "org.mozilla.firefox",
        "org.mozilla.firefoxdeveloperedition",
        "org.mozilla.nightly",
      ],
      scriptKind: .none
    ),
    BrowserCatalogEntry(
      name: "Zen Browser",
      bundleIDs: [
        "app.zen-browser.zen",
        "org.mozilla.plugincontainer",
      ],
      scriptKind: .none
    ),
  ]

  private static let byLowerBundleID: [String: BrowserCatalogEntry] = {
    var map: [String: BrowserCatalogEntry] = [:]
    for entry in entries {
      for id in entry.bundleIDs {
        map[id.lowercased()] = entry
      }
    }
    return map
  }()

  private static let byLowerName: [String: BrowserCatalogEntry] = {
    var map: [String: BrowserCatalogEntry] = [:]
    for entry in entries {
      map[entry.name.lowercased()] = entry
    }
    return map
  }()

  public static var scriptableEntries: [BrowserCatalogEntry] {
    entries.filter { $0.scriptKind != .none }
  }

  public static func entry(forBundleID bundleID: String) -> BrowserCatalogEntry? {
    byLowerBundleID[bundleID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()]
  }

  public static func entry(forBrowserName name: String) -> BrowserCatalogEntry? {
    byLowerName[name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()]
  }

  public static func isBrowser(bundleID: String) -> Bool {
    entry(forBundleID: bundleID) != nil
  }

  public static func isSafari(bundleID: String) -> Bool {
    entry(forBundleID: bundleID)?.scriptKind == .safari
  }

  public static func scriptKind(forBrowserName name: String) -> BrowserScriptKind {
    entry(forBrowserName: name)?.scriptKind ?? (name == "Safari" ? .safari : .chromium)
  }

  public static func primaryBundleID(forBrowserName name: String) -> String {
    entry(forBrowserName: name)?.bundleIDs.first ?? "com.apple.Safari"
  }
}
