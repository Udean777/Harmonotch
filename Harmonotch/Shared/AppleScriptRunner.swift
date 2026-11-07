import Foundation

nonisolated enum AppleScriptRunner {
  private static let queueKey = DispatchSpecificKey<Void>()

  static let queue: DispatchQueue = {
    let q = DispatchQueue(label: "com.harmonotch.applescript", qos: .utility)
    q.setSpecific(key: queueKey, value: ())
    return q
  }()

  nonisolated(unsafe) private static var scriptCache: [String: NSAppleScript] = [:]

  /// Escapes backslashes and double quotes for embedding inside an AppleScript string literal.
  static func escapeStringLiteral(_ text: String) -> String {
    text
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
  }

  /// Wraps a string in quotes with AppleScript literal escaping.
  static func quotedLiteral(_ text: String) -> String {
    "\"\(escapeStringLiteral(text))\""
  }

  static func execute(_ source: String) -> String? {
    var result: String?
    let work = {
      guard let scriptObject = cachedScript(source) else { return }
      var error: NSDictionary?
      let output = scriptObject.executeAndReturnError(&error)
      if error == nil {
        result = output.stringValue
      } else if let error {
        NSLog("[Harmonotch:AppleScript] execute error: %@", error)
      }
    }

    if DispatchQueue.getSpecific(key: queueKey) != nil {
      work()
    } else {
      queue.sync(execute: work)
    }
    return result
  }

  static func executeData(_ source: String) -> Data? {
    let work = { () -> Data? in
      guard let scriptObject = cachedScript(source) else { return nil }
      var error: NSDictionary?
      let output = scriptObject.executeAndReturnError(&error)
      guard error == nil else {
        if let error {
          NSLog("[Harmonotch:AppleScript] executeData error: %@", error)
        }
        return nil
      }
      return output.data
    }

    if DispatchQueue.getSpecific(key: queueKey) != nil {
      return work()
    }
    return queue.sync(execute: work)
  }

  static func executeAsync(_ source: String) {
    queue.async {
      _ = execute(source)
    }
  }

  static func runAsAdmin(shell: String) -> Bool {
    let scriptSource = "do shell script \(quotedLiteral(shell)) with administrator privileges"
    var errorDict: NSDictionary?
    guard let appleScript = NSAppleScript(source: scriptSource) else { return false }
    _ = appleScript.executeAndReturnError(&errorDict)
    return errorDict == nil
  }

  private static func cachedScript(_ source: String) -> NSAppleScript? {
    if let cached = scriptCache[source] { return cached }
    guard let newScript = NSAppleScript(source: source) else { return nil }
    scriptCache[source] = newScript
    return newScript
  }
}
