import Foundation

/// Service that monitors GitHub Copilot agent and local configuration.
public final class CopilotQuotaService: AIProviderService, @unchecked Sendable {
    public static let shared = CopilotQuotaService()
    public var provider: AIProviderType { .copilot }

    private let fileManager = FileManager.default
    private let homeDirectory = FileManager.default.homeDirectoryForCurrentUser

    public init() {}

    public func fetchSnapshot() async -> AIAgentQuotaSnapshot? {
        let isCopilotRunning = AntigravityProcessDetector.isProcessRunning(matching: ["copilot-agent", "copilot-language-server"])
        let configDir = homeDirectory.appendingPathComponent(".config/github-copilot")
        let appSupportDir = homeDirectory.appendingPathComponent("Library/Application Support/github-copilot")

        let isConfigured = fileManager.fileExists(atPath: configDir.path) || fileManager.fileExists(atPath: appSupportDir.path)

        guard isCopilotRunning || isConfigured else {
            return nil
        }

        let models = [
            AIModelQuota(
                id: "copilot-completions",
                modelName: "copilot-completions",
                label: "GitHub Copilot Completions",
                remainingFraction: 1.0,
                resetTime: nil,
                windowDescription: "Active Subscription"
            ),
            AIModelQuota(
                id: "copilot-chat",
                modelName: "copilot-chat",
                label: "Copilot Chat / Claude 3.7",
                remainingFraction: 1.0,
                resetTime: nil,
                windowDescription: "Interactive Workspace Chat"
            )
        ]

        return AIAgentQuotaSnapshot(
            provider: .copilot,
            userTier: isCopilotRunning ? "Agent Active" : "Configured (Standby)",
            models: models,
            isConnected: isCopilotRunning,
            endpointDescription: "Local Copilot Agent",
            lastUpdated: Date()
        )
    }
}
