import Foundation

enum AIAgentKind: String, CaseIterable, Identifiable {
  case claude = "claude"
  case codex = "codex"
  case opencode = "opencode"
  case gemini = "gemini"
  case copilot = "copilot"

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .claude:
      return "Claude Code"
    case .codex:
      return "OpenAI Codex"
    case .opencode:
      return "OpenCode CLI"
    case .gemini:
      return "Antigravity / Gemini"
    case .copilot:
      return "GitHub Copilot"
    }
  }

  var shortName: String {
    switch self {
    case .claude:
      return "Claude"
    case .codex:
      return "Codex"
    case .opencode:
      return "OpenCode"
    case .gemini:
      return "Gemini"
    case .copilot:
      return "Copilot"
    }
  }

  var icon: String {
    switch self {
    case .claude:
      return "sparkles"
    case .codex:
      return "terminal.fill"
    case .opencode:
      return "cpu.fill"
    case .gemini:
      return "wand.and.stars"
    case .copilot:
      return "chevron.left.forwardslash.chevron.right"
    }
  }

  var loginCommandHint: String {
    switch self {
    case .claude:
      return "claude auth login"
    case .codex:
      return "codex login"
    case .opencode:
      return "opencode auth login"
    case .gemini:
      return "agy --login"
    case .copilot:
      return "gh auth login"
    }
  }
}

enum AIAgentAuthStatus: Equatable {
  case authenticated(detail: String?)
  case failed(reason: String)

  var isAuthenticated: Bool {
    if case .authenticated = self {
      return true
    }
    return false
  }
}

struct AIAgentQuotaMetric: Identifiable, Equatable {
  let id: String
  let label: String
  let valueText: String
  let remainingRatio: Double?
  let resetDescription: String?
}

struct AIAgentStatusItem: Identifiable, Equatable {
  let kind: AIAgentKind
  let binaryPath: String
  let version: String?
  let authStatus: AIAgentAuthStatus
  let metrics: [AIAgentQuotaMetric]
  let statusNote: String?
  let checkedAt: Date

  var id: String { kind.rawValue }

  var quotaProgressMetrics: [AIAgentQuotaMetric] {
    metrics.filter { $0.remainingRatio != nil }
  }

  var metadataMetrics: [AIAgentQuotaMetric] {
    metrics.filter { $0.remainingRatio == nil }
  }

  var primaryQuotaMetric: AIAgentQuotaMetric? {
    quotaProgressMetrics.first
  }

  var activeModelSummary: String? {
    if let modelMetric = metadataMetrics.first(where: { $0.id.contains("model") }) {
      return modelMetric.valueText
    }
    if case .authenticated(let detail) = authStatus, let detail, !detail.isEmpty {
      return detail
    }
    return metadataMetrics.first?.valueText
  }
}
