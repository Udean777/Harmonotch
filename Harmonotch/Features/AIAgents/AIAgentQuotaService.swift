import Combine
import Foundation

final class AIAgentQuotaService: ObservableObject {
  static let shared = AIAgentQuotaService()

  @Published private(set) var hasCompletedInitialScan = false
  @Published private(set) var isScanning = false
  @Published private(set) var agents: [AIAgentStatusItem] = []
  @Published private(set) var lastCheckedAt: Date?

  private init() {}

  func checkInstalledAgents() {
    guard !isScanning else { return }
    isScanning = true

    Task.detached(priority: .userInitiated) {
      let discovered = await Self.probeAllInstalledAgents()
      let now = Date()

      await MainActor.run {
        self.agents = discovered
        self.lastCheckedAt = now
        self.hasCompletedInitialScan = true
        self.isScanning = false

        let currentSelected = UserDefaults.standard[UserDefaultsKeys.selectedNotchAIAgent]
        if !discovered.isEmpty,
           !discovered.contains(where: { $0.kind.rawValue == currentSelected }) {
          let preferred = discovered.first(where: { $0.authStatus.isAuthenticated }) ?? discovered[0]
          UserDefaults.standard[UserDefaultsKeys.selectedNotchAIAgent] = preferred.kind.rawValue
          NotificationCenter.default.post(name: .notchAIAgentChanged, object: preferred.kind.rawValue)
        }
      }
    }
  }

  private static func probeAllInstalledAgents() async -> [AIAgentStatusItem] {
    let home = FileManager.default.homeDirectoryForCurrentUser.path

    return await withTaskGroup(of: (Int, AIAgentStatusItem?).self) { group in
      let allKinds = AIAgentKind.allCases
      for (index, kind) in allKinds.enumerated() {
        group.addTask {
          let item = await probeAgent(kind: kind, home: home)
          return (index, item)
        }
      }

      var collected: [(Int, AIAgentStatusItem)] = []
      for await (idx, item) in group {
        if let item {
          collected.append((idx, item))
        }
      }

      return collected.sorted(by: { $0.0 < $1.0 }).map(\.1)
    }
  }

  private static func probeAgent(kind: AIAgentKind, home: String) async -> AIAgentStatusItem? {
    guard let cli = AIAgentDiscoveryService.discoverInstalledBinary(for: kind, home: home) else {
      return nil
    }

    let now = Date()
    switch kind {
    case .claude:
      return await fetchClaudeQuota(cli: cli, home: home, now: now)
    case .codex:
      return await fetchCodexQuota(cli: cli, home: home, now: now)
    case .opencode:
      return fetchOpenCodeQuota(cli: cli, home: home, now: now)
    case .gemini:
      return await fetchGeminiQuota(cli: cli, home: home, now: now)
    case .copilot:
      return fetchCopilotQuota(cli: cli, home: home, now: now)
    }
  }

  private static func makeFailedStatusItem(
    kind: AIAgentKind,
    cli: AIAgentDiscoveryService.DiscoveredCLI,
    reason: String = L10n.AIAgents.notLoggedInReason,
    checkedAt: Date
  ) -> AIAgentStatusItem {
    AIAgentStatusItem(
      kind: kind,
      binaryPath: cli.displayPath,
      version: cli.version,
      authStatus: .failed(reason: reason),
      metrics: [],
      statusNote: nil,
      checkedAt: checkedAt
    )
  }

  private static func fetchClaudeQuota(
    cli: AIAgentDiscoveryService.DiscoveredCLI,
    home: String,
    now: Date
  ) async -> AIAgentStatusItem {
    let auth = AIAgentDiscoveryService.checkClaudeAuth(binaryPath: cli.binaryPath)
    guard auth.isLoggedIn else {
      return makeFailedStatusItem(kind: .claude, cli: cli, checkedAt: now)
    }

    let claudeCfg = AIAgentDiscoveryService.readClaudeConfig(home: home)
    var metrics: [AIAgentQuotaMetric] = []

    if let model = claudeCfg.model, !model.isEmpty {
      var details: [String] = []
      if let effort = claudeCfg.effort { details.append("Effort: \(effort)") }
      if let provider = claudeCfg.provider { details.append(provider) }
      let resetDesc = details.isEmpty ? nil : details.joined(separator: " • ")

      metrics.append(
        AIAgentQuotaMetric(
          id: "claude-active-model",
          label: L10n.AIAgents.activeModelLabel,
          valueText: model,
          remainingRatio: nil,
          resetDescription: resetDesc
        )
      )
    }

    if let opus = claudeCfg.opusModel, !opus.isEmpty {
      metrics.append(
        AIAgentQuotaMetric(
          id: "claude-opus-model",
          label: "Opus Model",
          valueText: opus,
          remainingRatio: nil,
          resetDescription: nil
        )
      )
    }

    if let sonnet = claudeCfg.sonnetModel, !sonnet.isEmpty, sonnet != claudeCfg.model {
      metrics.append(
        AIAgentQuotaMetric(
          id: "claude-sonnet-model",
          label: "Sonnet Model",
          valueText: sonnet,
          remainingRatio: nil,
          resetDescription: nil
        )
      )
    }

    if let token = readClaudeOAuthToken(home: home),
       let liveMetrics = await fetchAnthropicOAuthQuota(accessToken: token) {
      metrics.append(contentsOf: liveMetrics)
    } else {
      let claudeConfigPath = "\(home)/.claude.json"
      if let data = try? Data(contentsOf: URL(fileURLWithPath: claudeConfigPath)),
         let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        let startups = json["numStartups"] as? Int ?? 0
        let promptCount = json["promptQueueUseCount"] as? Int ?? 0
        metrics.append(
          AIAgentQuotaMetric(
            id: "claude-sessions",
            label: L10n.AIAgents.cliSessions,
            valueText: "\(startups) runs",
            remainingRatio: nil,
            resetDescription: promptCount > 0 ? "\(promptCount) queued prompts" : nil
          )
        )
      }
    }

    let statusDetail = claudeCfg.model ?? (claudeCfg.provider ?? auth.authMethod)
    let note = claudeCfg.provider != nil ? "Provider: \(claudeCfg.provider!)" : L10n.AIAgents.claudeSubscribedNote

    return AIAgentStatusItem(
      kind: .claude,
      binaryPath: cli.displayPath,
      version: cli.version,
      authStatus: .authenticated(detail: statusDetail),
      metrics: metrics,
      statusNote: note,
      checkedAt: now
    )
  }

  private static func readClaudeOAuthToken(home: String) -> String? {
    let credPath = "\(home)/.claude/.credentials.json"
    if let data = try? Data(contentsOf: URL(fileURLWithPath: credPath)),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
      for key in ["claudeAiOauth", "oauth"] {
        if let nested = json[key] as? [String: Any],
           let token = (nested["accessToken"] ?? nested["access_token"]) as? String,
           !token.isEmpty {
          return token
        }
      }
      if let token = (json["accessToken"] ?? json["access_token"]) as? String, !token.isEmpty {
        return token
      }
    }
    return nil
  }

  private static func fetchAnthropicOAuthQuota(accessToken: String) async -> [AIAgentQuotaMetric]? {
    guard let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else { return nil }
    var request = URLRequest(url: url)
    request.timeoutInterval = 5.0
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

    guard let (data, response) = try? await URLSession.shared.data(for: request),
          let http = response as? HTTPURLResponse,
          http.statusCode == 200,
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return nil
    }

    var metrics: [AIAgentQuotaMetric] = []
    if let fiveHour = json["five_hour"] as? [String: Any],
       let used = fiveHour["utilization"] as? Double {
      let rem = max(0, min(100, Int((100.0 - used).rounded())))
      metrics.append(
        AIAgentQuotaMetric(
          id: "claude-5h",
          label: "5h Window",
          valueText: "\(rem)% left",
          remainingRatio: Double(rem) / 100.0,
          resetDescription: formatISO8601Reset(fiveHour["resets_at"] as? String)
        )
      )
    }
    if let sevenDay = json["seven_day"] as? [String: Any],
       let used = sevenDay["utilization"] as? Double {
      let rem = max(0, min(100, Int((100.0 - used).rounded())))
      metrics.append(
        AIAgentQuotaMetric(
          id: "claude-7d",
          label: "Weekly Quota",
          valueText: "\(rem)% left",
          remainingRatio: Double(rem) / 100.0,
          resetDescription: formatISO8601Reset(sevenDay["resets_at"] as? String)
        )
      )
    }
    return metrics.isEmpty ? nil : metrics
  }

  private static func fetchCodexQuota(
    cli: AIAgentDiscoveryService.DiscoveredCLI,
    home: String,
    now: Date
  ) async -> AIAgentStatusItem {
    let auth = AIAgentDiscoveryService.checkCodexAuth(home: home)
    guard auth.isLoggedIn else {
      return makeFailedStatusItem(kind: .codex, cli: cli, checkedAt: now)
    }

    let codexCfg = AIAgentDiscoveryService.readCodexConfig(home: home)
    var metrics: [AIAgentQuotaMetric] = []

    if let model = codexCfg.model, !model.isEmpty {
      var details: [String] = []
      if let effort = codexCfg.effort { details.append("Effort: \(effort)") }
      if let tier = codexCfg.tier { details.append("Tier: \(tier)") }
      let resetDesc = details.isEmpty ? nil : details.joined(separator: " • ")

      metrics.append(
        AIAgentQuotaMetric(
          id: "codex-active-model",
          label: L10n.AIAgents.activeModelLabel,
          valueText: model,
          remainingRatio: nil,
          resetDescription: resetDesc
        )
      )
    }

    var planLabel = auth.apiKey != nil ? "API Key" : "ChatGPT OAuth"
    var accountEmail: String?

    if let accessToken = auth.accessToken, !accessToken.isEmpty {
      if let usageResult = await fetchChatGPTWhamUsage(accessToken: accessToken, accountId: auth.accountId) {
        planLabel = usageResult.planLabel
        accountEmail = usageResult.email
        metrics.append(contentsOf: usageResult.metrics)
      }
    }

    let statusDetail = [codexCfg.model, planLabel].compactMap { $0 }.joined(separator: " • ")

    return AIAgentStatusItem(
      kind: .codex,
      binaryPath: cli.displayPath,
      version: cli.version,
      authStatus: .authenticated(detail: statusDetail),
      metrics: metrics,
      statusNote: accountEmail ?? L10n.AIAgents.authenticatedReady,
      checkedAt: now
    )
  }

  private static func fetchChatGPTWhamUsage(
    accessToken: String,
    accountId: String?
  ) async -> (planLabel: String, email: String?, metrics: [AIAgentQuotaMetric])? {
    guard let url = URL(string: "https://chatgpt.com/backend-api/wham/usage") else { return nil }
    var request = URLRequest(url: url)
    request.timeoutInterval = 6.0
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("Harmonotch/1.0", forHTTPHeaderField: "User-Agent")
    if let accountId, !accountId.isEmpty {
      request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-Id")
    }

    guard let (data, response) = try? await URLSession.shared.data(for: request),
          let http = response as? HTTPURLResponse,
          http.statusCode == 200,
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return nil
    }

    let planType = (json["plan_type"] as? String)?.uppercased() ?? "PLUS"
    let email = json["email"] as? String
    var metrics: [AIAgentQuotaMetric] = []

    if let rateLimit = json["rate_limit"] as? [String: Any] {
      if let primary = rateLimit["primary_window"] as? [String: Any],
         let usedPercent = primary["used_percent"] as? Double {
        let remaining = max(0, min(100, Int((100.0 - usedPercent).rounded())))
        let windowSecs = primary["limit_window_seconds"] as? Int ?? 0
        let windowLabel = formatWindowLabel(seconds: windowSecs)
        let resetAt = primary["reset_at"] as? TimeInterval
        metrics.append(
          AIAgentQuotaMetric(
            id: "codex-primary",
            label: windowLabel,
            valueText: "\(remaining)% left",
            remainingRatio: Double(remaining) / 100.0,
            resetDescription: formatEpochReset(resetAt)
          )
        )
      }

      if let secondary = rateLimit["secondary_window"] as? [String: Any],
         let usedPercent = secondary["used_percent"] as? Double {
        let remaining = max(0, min(100, Int((100.0 - usedPercent).rounded())))
        let windowSecs = secondary["limit_window_seconds"] as? Int ?? 0
        let windowLabel = formatWindowLabel(seconds: windowSecs)
        let resetAt = secondary["reset_at"] as? TimeInterval
        metrics.append(
          AIAgentQuotaMetric(
            id: "codex-secondary",
            label: windowLabel,
            valueText: "\(remaining)% left",
            remainingRatio: Double(remaining) / 100.0,
            resetDescription: formatEpochReset(resetAt)
          )
        )
      }
    }

    if let resetCredits = json["rate_limit_reset_credits"] as? [String: Any],
       let available = resetCredits["available_count"] as? Int, available > 0 {
      metrics.append(
        AIAgentQuotaMetric(
          id: "codex-reset-credits",
          label: L10n.AIAgents.resetCredits,
          valueText: "\(available) available",
          remainingRatio: nil,
          resetDescription: nil
        )
      )
    }

    return ("Plan \(planType)", email, metrics)
  }

  private static func fetchOpenCodeQuota(
    cli: AIAgentDiscoveryService.DiscoveredCLI,
    home: String,
    now: Date
  ) -> AIAgentStatusItem {
    let configuredProviders = AIAgentDiscoveryService.checkOpenCodeAuth(home: home)
    guard !configuredProviders.isEmpty else {
      return makeFailedStatusItem(kind: .opencode, cli: cli, checkedAt: now)
    }

    let opencodeCfg = AIAgentDiscoveryService.readOpenCodeConfig(home: home)
    var metrics: [AIAgentQuotaMetric] = []

    if !opencodeCfg.models.isEmpty {
      let primary = opencodeCfg.models.first!
      let otherCount = opencodeCfg.models.count - 1
      let otherDesc = otherCount > 0 ? "+ \(otherCount) more: " + opencodeCfg.models.dropFirst().joined(separator: ", ") : nil

      metrics.append(
        AIAgentQuotaMetric(
          id: "opencode-primary-model",
          label: L10n.AIAgents.activeModelLabel,
          valueText: primary,
          remainingRatio: nil,
          resetDescription: otherDesc
        )
      )
    }

    let cacheDir = "\(home)/.cache/opencode/quota-provider-state"
    if let files = try? FileManager.default.contentsOfDirectory(atPath: cacheDir) {
      for file in files where file.hasSuffix(".json") {
        let fullPath = "\(cacheDir)/\(file)"
        if let data = try? Data(contentsOf: URL(fileURLWithPath: fullPath)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let result = json["result"] as? [String: Any],
           let entries = result["entries"] as? [[String: Any]] {
          for entry in entries {
            guard let semantic = entry["semantic"] as? [String: Any],
                  (semantic["prominence"] as? String) == "primary",
                  let group = entry["group"] as? String,
                  let quantity = entry["quantity"] as? [String: Any],
                  let decimal = quantity["decimal"] as? String,
                  let unit = quantity["unit"] as? [String: Any],
                  let code = unit["code"] as? String
            else { continue }

            metrics.append(
              AIAgentQuotaMetric(
                id: "opencode-\(group)",
                label: "\(group) Balance",
                valueText: "\(code) \(decimal)",
                remainingRatio: nil,
                resetDescription: nil
              )
            )
          }
        }
      }
    }

    let providersSummary = configuredProviders.map { $0.capitalized }.joined(separator: ", ")
    metrics.append(
      AIAgentQuotaMetric(
        id: "opencode-providers",
        label: L10n.AIAgents.connectedProviders,
        valueText: "\(configuredProviders.count) active",
        remainingRatio: nil,
        resetDescription: providersSummary
      )
    )

    let statusDetail = opencodeCfg.models.first ?? "\(configuredProviders.count) Providers"
    let statusNote = !opencodeCfg.models.isEmpty
      ? "\(opencodeCfg.models.count) models configured"
      : "\(configuredProviders.count) providers connected"

    return AIAgentStatusItem(
      kind: .opencode,
      binaryPath: cli.displayPath,
      version: cli.version,
      authStatus: .authenticated(detail: statusDetail),
      metrics: metrics,
      statusNote: statusNote,
      checkedAt: now
    )
  }

  private static func fetchGeminiQuota(
    cli: AIAgentDiscoveryService.DiscoveredCLI,
    home: String,
    now: Date
  ) async -> AIAgentStatusItem {
    let auth = AIAgentDiscoveryService.checkGeminiAuth(home: home)
    guard auth.isLoggedIn else {
      return makeFailedStatusItem(kind: .gemini, cli: cli, checkedAt: now)
    }

    let activeModel = AIAgentDiscoveryService.readGeminiActiveModel(home: home)
    var metrics: [AIAgentQuotaMetric] = []

    if let model = activeModel, !model.isEmpty {
      metrics.append(
        AIAgentQuotaMetric(
          id: "gemini-active-model",
          label: L10n.AIAgents.activeModelLabel,
          valueText: model,
          remainingRatio: nil,
          resetDescription: nil
        )
      )
    }

    let usageMetrics = await Task.detached(priority: .userInitiated) {
      fetchGeminiUsageMetrics(binaryPath: cli.binaryPath)
    }.value

    if let usageMetrics, !usageMetrics.isEmpty {
      metrics.append(contentsOf: usageMetrics)
    } else if let email = auth.email, !email.isEmpty {
      metrics.append(
        AIAgentQuotaMetric(
          id: "gemini-account",
          label: L10n.AIAgents.accountLabel,
          valueText: email,
          remainingRatio: nil,
          resetDescription: auth.expiry.flatMap { formatISO8601Reset($0, prefix: "Token valid") }
        )
      )
    }

    let statusDetail = activeModel ?? auth.authMethod
    let note = auth.email

    return AIAgentStatusItem(
      kind: .gemini,
      binaryPath: cli.displayPath,
      version: cli.version,
      authStatus: .authenticated(detail: statusDetail),
      metrics: metrics,
      statusNote: note,
      checkedAt: now
    )
  }

  nonisolated private static func fetchGeminiUsageMetrics(binaryPath: String) -> [AIAgentQuotaMetric]? {
    let out = AIAgentDiscoveryService.runCommand(
      executable: binaryPath,
      arguments: ["-p", "/usage", "--output-format", "json"],
      timeout: 6.0
    )

    guard out.exitCode == 0, !out.stdout.isEmpty else {
      return nil
    }

    guard let data = out.stdout.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let command = json["command"] as? [String: Any],
          let cmdData = command["data"] as? [String: Any],
          let groups = cmdData["groups"] as? [[String: Any]]
    else {
      return parseGeminiTsvUsage(out.stdout)
    }

    var result: [AIAgentQuotaMetric] = []
    for (gIdx, group) in groups.enumerated() {
      let groupName = (group["name"] as? String) ?? "Model Group"
      guard let buckets = group["buckets"] as? [[String: Any]] else { continue }

      for (bIdx, bucket) in buckets.enumerated() {
        let bucketId = (bucket["id"] as? String) ?? "gemini-bucket-\(gIdx)-\(bIdx)"
        let window = bucket["window"] as? String
        let bucketName = (bucket["name"] as? String) ?? "Limit"
        let fraction = bucket["remaining_fraction"] as? Double
        let resetTime = bucket["reset_time"] as? String

        let windowLabel: String
        if let window, !window.isEmpty {
          windowLabel = window == "5h" ? "5h Limit" : (window == "weekly" ? "Weekly Limit" : window.capitalized)
        } else {
          windowLabel = bucketName
        }

        let label = "\(groupName) • \(windowLabel)"
        let pct = fraction.map { Int(($0 * 100.0).rounded()) } ?? 100
        let clampedPct = max(0, min(100, pct))
        let valueText = "\(clampedPct)% left"
        let ratio = fraction.map { max(0.0, min(1.0, $0)) }
        let resetDesc = resetTime.flatMap { formatISO8601Reset($0) }

        result.append(
          AIAgentQuotaMetric(
            id: bucketId,
            label: label,
            valueText: valueText,
            remainingRatio: ratio,
            resetDescription: resetDesc
          )
        )
      }
    }

    return result.isEmpty ? nil : result
  }

  nonisolated private static func parseGeminiTsvUsage(_ raw: String) -> [AIAgentQuotaMetric]? {
    var result: [AIAgentQuotaMetric] = []
    let lines = raw.components(separatedBy: .newlines)
    for (idx, line) in lines.enumerated() {
      let cols = line.components(separatedBy: "\t")
      guard cols.count >= 3 else { continue }
      let groupName = cols[0].trimmingCharacters(in: .whitespaces)
      let limitName = cols[1].trimmingCharacters(in: .whitespaces)
      let pctStr = cols[2].trimmingCharacters(in: .whitespaces)
      let resetStr = cols.count >= 4 ? cols[3].trimmingCharacters(in: .whitespaces) : nil

      let digits = pctStr.filter { $0.isNumber }
      let pctInt = Int(digits) ?? 100
      let ratio = Double(pctInt) / 100.0
      let label = "\(groupName) • \(limitName.replacingOccurrences(of: " Remaining", with: ""))"

      result.append(
        AIAgentQuotaMetric(
          id: "gemini-tsv-\(idx)",
          label: label,
          valueText: "\(pctInt)% left",
          remainingRatio: ratio,
          resetDescription: resetStr.flatMap { formatISO8601Reset($0) }
        )
      )
    }
    return result.isEmpty ? nil : result
  }

  private static func fetchCopilotQuota(
    cli: AIAgentDiscoveryService.DiscoveredCLI,
    home: String,
    now: Date
  ) -> AIAgentStatusItem {
    let isLoggedIn = AIAgentDiscoveryService.checkCopilotAuth(home: home)
    guard isLoggedIn else {
      return makeFailedStatusItem(kind: .copilot, cli: cli, checkedAt: now)
    }

    let copilotInfo = AIAgentDiscoveryService.readCopilotAccount(cli: cli, home: home)
    var metrics: [AIAgentQuotaMetric] = []

    if let user = copilotInfo.login {
      metrics.append(
        AIAgentQuotaMetric(
          id: "copilot-account",
          label: L10n.AIAgents.accountLabel,
          valueText: user,
          remainingRatio: nil,
          resetDescription: copilotInfo.email
        )
      )
    }

    let statusDetail = copilotInfo.login ?? "GitHub OAuth"
    let statusNote = copilotInfo.copilotInstalled
      ? "Copilot CLI ready"
      : "GitHub CLI logged in • Extension not installed"

    return AIAgentStatusItem(
      kind: .copilot,
      binaryPath: cli.displayPath,
      version: cli.version,
      authStatus: .authenticated(detail: statusDetail),
      metrics: metrics,
      statusNote: statusNote,
      checkedAt: now
    )
  }

  private static func formatWindowLabel(seconds: Int) -> String {
    if seconds <= 0 { return L10n.AIAgents.quotaWindow }
    let hours = seconds / 3600
    if hours == 5 { return "5h Window" }
    if hours == 24 { return "Daily Quota" }
    let days = hours / 24
    if days == 7 { return "Weekly Quota" }
    if days >= 28 { return "Monthly Quota" }
    if days > 0 { return "\(days)d Quota" }
    return "\(hours)h Quota"
  }

  private static func formatEpochReset(_ epoch: TimeInterval?) -> String? {
    guard let epoch, epoch > 0 else { return nil }
    let resetDate = Date(timeIntervalSince1970: epoch)
    return formatRemainingReset(to: resetDate)
  }

  nonisolated private static func formatISO8601Reset(_ iso: String?, prefix: String = "Resets") -> String? {
    guard let iso, !iso.isEmpty else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let date = formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
    guard let resetDate = date else { return nil }
    return formatRemainingReset(to: resetDate, prefix: prefix)
  }

  nonisolated private static func formatRemainingReset(to date: Date, prefix: String = "Resets") -> String? {
    let diff = Int(date.timeIntervalSinceNow)
    guard diff > 0 else { return nil }
    let days = diff / 86400
    let hours = (diff % 86400) / 3600
    let mins = (diff % 3600) / 60
    if days > 0 {
      return "\(prefix) in \(days)d \(hours)h"
    } else if hours > 0 {
      return "\(prefix) in \(hours)h \(mins)m"
    } else {
      return "\(prefix) in \(max(1, mins))m"
    }
  }
}
