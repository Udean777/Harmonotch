import Foundation

/// Service that monitors Cursor IDE local state and running processes.
public final class CursorQuotaService: AIProviderService, @unchecked Sendable {
    public static let shared = CursorQuotaService()
    public var provider: AIProviderType { .cursor }

    private let fileManager = FileManager.default
    private let homeDirectory = FileManager.default.homeDirectoryForCurrentUser

    public init() {}

    public func fetchSnapshot() async -> AIAgentQuotaSnapshot? {
        let isCursorRunning = AntigravityProcessDetector.isProcessRunning(matching: ["Cursor.app", "cursor-server"])
        let appSupportDir = homeDirectory.appendingPathComponent("Library/Application Support/Cursor")
        let appBundle = URL(fileURLWithPath: "/Applications/Cursor.app")

        let isInstalled = fileManager.fileExists(atPath: appSupportDir.path) || fileManager.fileExists(atPath: appBundle.path)

        guard isCursorRunning || isInstalled else {
            return nil
        }

        let models = [
            AIModelQuota(
                id: "cursor-fast",
                modelName: "cursor-fast",
                label: "Claude 3.7 Sonnet / GPT-4o",
                remainingFraction: isCursorRunning ? 1.0 : 0.0,
                resetTime: nil,
                windowDescription: "Fast Premium Requests"
            ),
            AIModelQuota(
                id: "cursor-small",
                modelName: "cursor-small",
                label: "Cursor Small / Tab Completion",
                remainingFraction: 1.0,
                resetTime: nil,
                windowDescription: "Unlimited Tab Autocomplete"
            )
        ]

        return AIAgentQuotaSnapshot(
            provider: .cursor,
            userTier: isCursorRunning ? "Cursor IDE Running" : "Standby (Not Running)",
            models: models,
            isConnected: isCursorRunning,
            endpointDescription: "Local Cursor Client",
            lastUpdated: Date()
        )
    }
}
