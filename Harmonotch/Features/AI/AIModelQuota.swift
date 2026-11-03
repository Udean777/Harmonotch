import Foundation

public enum AIProviderType: String, CaseIterable, Identifiable, Codable {
    case antigravity = "antigravity"
    case claude = "claude"
    case ollama = "ollama"
    case cursor = "cursor"
    case copilot = "copilot"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .antigravity:
            return "Google Antigravity"
        case .claude:
            return "Claude Code"
        case .ollama:
            return "Ollama"
        case .cursor:
            return "Cursor"
        case .copilot:
            return "GitHub Copilot"
        }
    }

    public var shortName: String {
        switch self {
        case .antigravity:
            return "Antigravity"
        case .claude:
            return "Claude"
        case .ollama:
            return "Ollama"
        case .cursor:
            return "Cursor"
        case .copilot:
            return "Copilot"
        }
    }

    public var iconName: String {
        switch self {
        case .antigravity:
            return "sparkles"
        case .claude:
            return "brain"
        case .ollama:
            return "cpu"
        case .cursor:
            return "chevron.left.forwardslash.chevron.right"
        case .copilot:
            return "airplane"
        }
    }
}

public struct AIModelQuota: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let modelName: String
    public let label: String
    /// Remaining quota as a fraction between 0.0 and 1.0 (e.g. 0.85 = 85%)
    public let remainingFraction: Double
    public let resetTime: Date?
    public let windowDescription: String?

    public init(
        id: String,
        modelName: String,
        label: String,
        remainingFraction: Double,
        resetTime: Date? = nil,
        windowDescription: String? = nil
    ) {
        self.id = id
        self.modelName = modelName
        self.label = label
        self.remainingFraction = max(0.0, min(1.0, remainingFraction))
        self.resetTime = resetTime
        self.windowDescription = windowDescription
    }

    public var remainingPercentage: Int {
        Int((remainingFraction * 100).rounded())
    }

    public var formattedResetCountdown: String? {
        guard let resetTime = resetTime else { return nil }
        let now = Date()
        let interval = resetTime.timeIntervalSince(now)
        guard interval > 0 else { return "Resetting now" }

        let days = Int(interval) / 86400
        let hours = (Int(interval) % 86400) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

public struct AIAgentQuotaSnapshot: Equatable, Sendable {
    public let provider: AIProviderType
    public let userTier: String?
    public let models: [AIModelQuota]
    public let isConnected: Bool
    public let endpointDescription: String
    public let lastUpdated: Date

    public init(
        provider: AIProviderType,
        userTier: String? = nil,
        models: [AIModelQuota] = [],
        isConnected: Bool = false,
        endpointDescription: String = "127.0.0.1 (Loopback)",
        lastUpdated: Date = Date()
    ) {
        self.provider = provider
        self.userTier = userTier
        self.models = models
        self.isConnected = isConnected
        self.endpointDescription = endpointDescription
        self.lastUpdated = lastUpdated
    }
}

/// Common protocol for local AI Agent telemetry providers.
public protocol AIProviderService: Sendable {
    var provider: AIProviderType { get }
    func fetchSnapshot() async -> AIAgentQuotaSnapshot?
}
