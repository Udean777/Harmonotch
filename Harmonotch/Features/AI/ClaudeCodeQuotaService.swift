import Foundation

/// Service that safely inspects local Claude Code CLI configuration and active processes.
/// Strictly read-only: reads `~/.claude/settings.json` and checks Darwin process tables.
public final class ClaudeCodeQuotaService: AIProviderService, @unchecked Sendable {
    public static let shared = ClaudeCodeQuotaService()
    public var provider: AIProviderType { .claude }

    private let fileManager = FileManager.default
    private let homeDirectory = FileManager.default.homeDirectoryForCurrentUser

    public init() {}

    public func fetchSnapshot() async -> AIAgentQuotaSnapshot? {
        let claudeDir = homeDirectory.appendingPathComponent(".claude")
        let claudeJsonFile = homeDirectory.appendingPathComponent(".claude.json")
        let settingsFile = claudeDir.appendingPathComponent("settings.json")

        let isDirPresent = fileManager.fileExists(atPath: claudeDir.path)
        let isConfigPresent = fileManager.fileExists(atPath: claudeJsonFile.path)
        let isProcessRunning = AntigravityProcessDetector.isProcessRunning(matching: ["claude", "claude-code"])

        guard isDirPresent || isConfigPresent || isProcessRunning else {
            return nil
        }

        var configuredModel = "Claude 3.7 Sonnet"
        var subagentModel: String?
        var endpointHost = "api.anthropic.com"
        let tier = isProcessRunning ? "Active CLI Session" : "Configured (Standby)"

        // Read settings.json if present
        if fileManager.fileExists(atPath: settingsFile.path),
           let data = try? Data(contentsOf: settingsFile),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

            if let env = json["env"] as? [String: String] {
                if let base = env["ANTHROPIC_BASE_URL"], let url = URL(string: base) {
                    endpointHost = url.host ?? base
                }
                if let model = env["ANTHROPIC_MODEL"] {
                    configuredModel = model
                }
                if let subagent = env["CLAUDE_CODE_SUBAGENT_MODEL"] {
                    subagentModel = subagent
                }
            } else if let model = json["model"] as? String {
                configuredModel = model
            }
        }

        var models: [AIModelQuota] = []

        let cleanModelName = formatModelName(configuredModel)
        models.append(
            AIModelQuota(
                id: "claude-primary",
                modelName: configuredModel,
                label: cleanModelName,
                remainingFraction: 1.0,
                resetTime: nil,
                windowDescription: "Primary Model"
            )
        )

        if let subagent = subagentModel, subagent != configuredModel {
            models.append(
                AIModelQuota(
                    id: "claude-subagent",
                    modelName: subagent,
                    label: "\(formatModelName(subagent)) (Subagent)",
                    remainingFraction: 1.0,
                    resetTime: nil,
                    windowDescription: "Subagent Task Execution"
                )
            )
        }

        return AIAgentQuotaSnapshot(
            provider: .claude,
            userTier: tier,
            models: models,
            isConnected: isProcessRunning,
            endpointDescription: endpointHost,
            lastUpdated: Date()
        )
    }

    private func formatModelName(_ raw: String) -> String {
        switch raw.lowercased() {
        case "haiku":
            return "Claude 3.5 Haiku"
        case "sonnet":
            return "Claude 3.7 Sonnet"
        case "opus":
            return "Claude 3.7 Opus"
        default:
            return raw
        }
    }
}
