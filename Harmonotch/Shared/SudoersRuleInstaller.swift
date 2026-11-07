import Foundation

nonisolated struct SudoersRuleInstaller {
  let filePath: String
  let ruleContent: String
  let probe: () -> Bool

  func isConfigured() -> Bool {
    probe()
  }

  func install() -> Bool {
    let singleQuotedRule = ruleContent.replacingOccurrences(of: "'", with: "'\\''")
    let shell = "tmp=$(mktemp) && printf '%s\\n' '\(singleQuotedRule)' > \"$tmp\" "
      + "&& chown root:wheel \"$tmp\" && chmod 0440 \"$tmp\" "
      + "&& visudo -c -f \"$tmp\" && mv -f \"$tmp\" \(filePath)"
    let scriptSucceeded = AppleScriptRunner.runAsAdmin(shell: shell)
    return scriptSucceeded && probe()
  }

  func remove() -> Bool {
    let shell = "rm -f \(filePath)"
    let removed = AppleScriptRunner.runAsAdmin(shell: shell)
    return removed && !probe()
  }
}
