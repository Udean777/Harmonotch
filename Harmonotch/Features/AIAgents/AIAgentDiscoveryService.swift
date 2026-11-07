import Foundation

enum AIAgentDiscoveryService {
  struct DiscoveredCLI: Equatable {
    let kind: AIAgentKind
    let binaryPath: String
    let displayPath: String
    let version: String?
  }

  static func discoverInstalledBinary(for kind: AIAgentKind, home: String = FileManager.default.homeDirectoryForCurrentUser.path) -> DiscoveredCLI? {
    guard let binaryPath = resolveBinaryPath(for: kind, home: home) else {
      return nil
    }
    let version = resolveVersion(for: kind, binaryPath: binaryPath, home: home)
    return DiscoveredCLI(
      kind: kind,
      binaryPath: binaryPath,
      displayPath: abbreviateHome(binaryPath, home: home),
      version: version
    )
  }

  static func resolveBinaryPath(for kind: AIAgentKind, home: String) -> String? {
    let fm = FileManager.default
    let candidates: [String]

    switch kind {
    case .claude:
      candidates = [
        "\(home)/.local/bin/claude",
        "\(home)/.claude/local/claude",
        "/opt/homebrew/bin/claude",
        "/usr/local/bin/claude",
        "\(home)/.bun/bin/claude"
      ]
    case .codex:
      candidates = [
        "\(home)/.bun/bin/codex",
        "\(home)/.local/bin/codex",
        "/opt/homebrew/bin/codex",
        "/usr/local/bin/codex"
      ]
    case .opencode:
      candidates = [
        "\(home)/.opencode/bin/opencode",
        "\(home)/.local/bin/opencode",
        "/opt/homebrew/bin/opencode",
        "/usr/local/bin/opencode",
        "\(home)/.bun/bin/opencode"
      ]
    case .gemini:
      candidates = [
        "\(home)/.gemini/bin/agy",
        "\(home)/.local/bin/gemini",
        "/opt/homebrew/bin/gemini",
        "/usr/local/bin/gemini",
        "\(home)/.bun/bin/gemini"
      ]
    case .copilot:
      candidates = [
        "/opt/homebrew/bin/gh",
        "/usr/local/bin/gh",
        "\(home)/.local/bin/gh",
        "/usr/bin/gh"
      ]
    }

    for path in candidates {
      if fm.isExecutableFile(atPath: path) {
        return path
      }
    }
    return nil
  }

  static func resolveVersion(for kind: AIAgentKind, binaryPath: String, home: String) -> String? {
    switch kind {
    case .claude:
      let out = runCommand(executable: binaryPath, arguments: ["--version"], timeout: 2.5)
      return parseCleanVersion(out.stdout)

    case .codex:
      let versionPath = "\(home)/.codex/version.json"
      if let data = try? Data(contentsOf: URL(fileURLWithPath: versionPath)),
         let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
         let ver = (json["version"] ?? json["latest_version"]) as? String {
        return ver
      }
      let out = runCommand(executable: binaryPath, arguments: ["--version"], timeout: 2.5)
      return parseCleanVersion(out.stdout)

    case .opencode:
      let out = runCommand(executable: binaryPath, arguments: ["--version"], timeout: 2.5)
      return parseCleanVersion(out.stdout)

    case .gemini:
      let verPath = "\(home)/.gemini/bin/agy.version.json"
      if let data = try? Data(contentsOf: URL(fileURLWithPath: verPath)),
         let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
         let v = (json["version"] ?? json["shortVersion"]) as? String {
        return v
      }
      return nil

    case .copilot:
      return nil
    }
  }

  static func checkClaudeAuth(binaryPath: String) -> (isLoggedIn: Bool, authMethod: String) {
    let authOut = runCommand(executable: binaryPath, arguments: ["auth", "status"], timeout: 3.0)
    guard let data = authOut.stdout.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return (false, "OAuth")
    }
    let isLoggedIn = (json["loggedIn"] as? Bool) ?? false
    let rawMethod = (json["authMethod"] as? String) ?? "OAuth"
    let method = rawMethod == "oauth_token" ? "OAuth" : rawMethod
    return (isLoggedIn, method)
  }

  static func checkCodexAuth(home: String) -> (isLoggedIn: Bool, accessToken: String?, accountId: String?, apiKey: String?) {
    let authPath = "\(home)/.codex/auth.json"
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: authPath)),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return (false, nil, nil, nil)
    }

    let apiKey = (json["OPENAI_API_KEY"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let tokens = json["tokens"] as? [String: Any]
    let accessToken = (tokens?["access_token"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let accountId = tokens?["account_id"] as? String

    let isLoggedIn = (accessToken != nil && !accessToken!.isEmpty) || (apiKey != nil && !apiKey!.isEmpty)
    return (isLoggedIn, accessToken, accountId, apiKey)
  }

  static func checkOpenCodeAuth(home: String) -> [String] {
    let authPath = "\(home)/.local/share/opencode/auth.json"
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: authPath)),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return []
    }
    return Array(json.keys).sorted()
  }

  static func checkGeminiAuth(home: String) -> (isLoggedIn: Bool, email: String?, authMethod: String, expiry: String?) {
    let oauthPath = "\(home)/.gemini/antigravity-cli/antigravity-oauth-token"
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: oauthPath)),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let tokenDict = json["token"] as? [String: Any],
          let accessToken = tokenDict["access_token"] as? String,
          !accessToken.isEmpty
    else {
      return (false, nil, "OAuth", nil)
    }
    let email = json["id_token_email"] as? String
    let authMethod = (json["auth_method"] as? String)?.capitalized ?? "OAuth"
    let expiryString = tokenDict["expiry"] as? String
    return (true, email, authMethod, expiryString)
  }

  static func readGeminiActiveModel(home: String) -> String? {
    let settingsPath = "\(home)/.gemini/antigravity-cli/settings.json"
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: settingsPath)),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let model = json["model"] as? String,
          !model.isEmpty
    else {
      return nil
    }
    return model
  }

  struct CodexConfig: Equatable {
    let model: String?
    let effort: String?
    let tier: String?
  }

  static func readCodexConfig(home: String) -> CodexConfig {
    let configPath = "\(home)/.codex/config.toml"
    guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
      return CodexConfig(model: nil, effort: nil, tier: nil)
    }

    func extractValue(for key: String) -> String? {
      let pattern = "^\\s*" + NSRegularExpression.escapedPattern(for: key) + "\\s*=\\s*\"([^\"]+)\""
      guard let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines),
            let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
            match.numberOfRanges > 1,
            let range = Range(match.range(at: 1), in: content) else {
        return nil
      }
      return String(content[range])
    }

    return CodexConfig(
      model: extractValue(for: "model"),
      effort: extractValue(for: "model_reasoning_effort"),
      tier: extractValue(for: "service_tier")
    )
  }

  struct ClaudeConfig: Equatable {
    let model: String?
    let provider: String?
    let opusModel: String?
    let sonnetModel: String?
    let effort: String?
  }

  static func readClaudeConfig(home: String) -> ClaudeConfig {
    let settingsPath = "\(home)/.claude/settings.json"
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: settingsPath)),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return ClaudeConfig(model: nil, provider: nil, opusModel: nil, sonnetModel: nil, effort: nil)
    }

    let env = json["env"] as? [String: Any] ?? [:]
    let model = (env["ANTHROPIC_MODEL"] as? String) ?? (json["model"] as? String)
    let rawBaseURL = env["ANTHROPIC_BASE_URL"] as? String
    var providerName: String?
    if let raw = rawBaseURL {
      if raw.lowercased().contains("deepseek") {
        providerName = "DeepSeek (api.deepseek.com)"
      } else if let host = URL(string: raw)?.host {
        providerName = host
      } else {
        providerName = raw
      }
    }
    let opus = env["ANTHROPIC_DEFAULT_OPUS_MODEL"] as? String
    let sonnet = env["ANTHROPIC_DEFAULT_SONNET_MODEL"] as? String

    var effort: String?
    if let m = model, let modelSettings = json["modelSettings"] as? [String: Any] {
      let baseKey = m.components(separatedBy: "[").first ?? m
      if let specific = modelSettings[baseKey] as? [String: Any] {
        effort = specific["effortLevel"] as? String
      }
    }

    return ClaudeConfig(
      model: model,
      provider: providerName,
      opusModel: opus,
      sonnetModel: sonnet,
      effort: effort
    )
  }

  struct OpenCodeConfig: Equatable {
    let models: [String]
  }

  static func readOpenCodeConfig(home: String) -> OpenCodeConfig {
    let configPath = "\(home)/.config/opencode/opencode.jsonc"
    guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
      return OpenCodeConfig(models: [])
    }

    let pattern = "\"name\":\\s*\"([^\"]+)\""
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
      return OpenCodeConfig(models: [])
    }

    let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
    var foundModels: [String] = []
    for match in matches where match.numberOfRanges > 1 {
      if let range = Range(match.range(at: 1), in: content) {
        let name = String(content[range])
        if !foundModels.contains(name) {
          foundModels.append(name)
        }
      }
    }

    return OpenCodeConfig(models: foundModels)
  }

  struct CopilotAccount: Equatable {
    let login: String?
    let name: String?
    let email: String?
    let copilotInstalled: Bool
  }

  static func readCopilotAccount(cli: DiscoveredCLI, home: String) -> CopilotAccount {
    let hostsPath = "\(home)/.config/gh/hosts.yml"
    var loginFromHost: String?
    if let content = try? String(contentsOfFile: hostsPath, encoding: .utf8) {
      let pattern = "user:\\s*([^\\s]+)"
      if let regex = try? NSRegularExpression(pattern: pattern),
         let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
         match.numberOfRanges > 1,
         let range = Range(match.range(at: 1), in: content) {
        loginFromHost = String(content[range])
      }
    }

    let copilotCheck = runCommand(executable: cli.binaryPath, arguments: ["copilot", "--version"], timeout: 2.0)
    let copilotInstalled = copilotCheck.exitCode == 0 && !copilotCheck.stderr.contains("not installed")

    let apiCheck = runCommand(
      executable: cli.binaryPath,
      arguments: ["api", "user", "--jq", ".login + \"|\" + (.name // \"\") + \"|\" + (.email // \"\")"],
      timeout: 2.5
    )
    if apiCheck.exitCode == 0 {
      let parts = apiCheck.stdout.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "|")
      if parts.count >= 3 {
        let l = parts[0].isEmpty ? loginFromHost : parts[0]
        let n = parts[1].isEmpty ? nil : parts[1]
        let e = parts[2].isEmpty ? nil : parts[2]
        return CopilotAccount(login: l, name: n, email: e, copilotInstalled: copilotInstalled)
      }
    }

    return CopilotAccount(login: loginFromHost, name: nil, email: nil, copilotInstalled: copilotInstalled)
  }

  static func checkCopilotAuth(home: String) -> Bool {
    let hostsPath = "\(home)/.config/gh/hosts.yml"
    guard let content = try? String(contentsOfFile: hostsPath, encoding: .utf8) else {
      return false
    }
    return content.contains("oauth_token") || content.contains("user:")
  }

  static func runCommand(
    executable: String,
    arguments: [String],
    timeout: TimeInterval
  ) -> (exitCode: Int32, stdout: String, stderr: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments

    var env = ProcessInfo.processInfo.environment
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let extraPaths = [
      "\(home)/.gemini/bin",
      "\(home)/.local/bin",
      "\(home)/.bun/bin",
      "\(home)/.opencode/bin",
      "/opt/homebrew/bin",
      "/usr/local/bin",
      "/usr/bin",
      "/bin"
    ]
    let currentPath = env["PATH"] ?? "/usr/bin:/bin"
    env["PATH"] = (extraPaths + [currentPath]).joined(separator: ":")
    process.environment = env

    let outPipe = Pipe()
    let errPipe = Pipe()
    process.standardOutput = outPipe
    process.standardError = errPipe

    do {
      try process.run()
    } catch {
      return (-1, "", error.localizedDescription)
    }

    let deadline = Date().addingTimeInterval(timeout)
    while process.isRunning && Date() < deadline {
      Thread.sleep(forTimeInterval: 0.04)
    }
    if process.isRunning {
      process.terminate()
      return (-2, "", "Timed out")
    }

    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
    let stdout = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let stderr = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return (process.terminationStatus, stdout, stderr)
  }

  static func parseCleanVersion(_ raw: String) -> String? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    let firstLine = trimmed.components(separatedBy: .newlines).first ?? trimmed
    let tokens = firstLine.components(separatedBy: .whitespaces)
    if let versionToken = tokens.first(where: { $0.first?.isNumber == true }) {
      return versionToken
    }
    return String(firstLine.prefix(24))
  }

  static func abbreviateHome(_ path: String, home: String) -> String {
    if path.hasPrefix(home) {
      return "~" + path.dropFirst(home.count)
    }
    return path
  }
}
