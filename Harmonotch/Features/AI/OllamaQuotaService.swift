import Foundation

/// Service that queries the local Ollama daemon on `127.0.0.1:11434` for loaded and installed models.
/// Completely local, private, and read-only.
public final class OllamaQuotaService: AIProviderService, @unchecked Sendable {
    public static let shared = OllamaQuotaService()
    public var provider: AIProviderType { .ollama }

    private let fileManager = FileManager.default
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 0.8
        config.timeoutIntervalForResource = 1.0
        return URLSession(configuration: config)
    }()

    public init() {}

    public func fetchSnapshot() async -> AIAgentQuotaSnapshot? {
        let isOllamaRunning = AntigravityProcessDetector.isProcessRunning(matching: ["ollama"])
        let hasBinary = fileManager.fileExists(atPath: "/opt/homebrew/bin/ollama")
            || fileManager.fileExists(atPath: "/usr/local/bin/ollama")
            || fileManager.fileExists(atPath: "/usr/bin/ollama")

        // First attempt to query the local REST API
        if let liveSnapshot = await queryLiveDaemon() {
            return liveSnapshot
        }

        // If daemon is not answering, check if installed or process is running
        if isOllamaRunning || hasBinary {
            return AIAgentQuotaSnapshot(
                provider: .ollama,
                userTier: isOllamaRunning ? "Starting Daemon" : "Local Standby",
                models: [
                    AIModelQuota(
                        id: "ollama-standby",
                        modelName: "Ollama",
                        label: "Ollama Local Service",
                        remainingFraction: 1.0,
                        resetTime: nil,
                        windowDescription: isOllamaRunning ? "Daemon Initializing" : "Run 'ollama serve' to start"
                    )
                ],
                isConnected: isOllamaRunning,
                endpointDescription: "127.0.0.1:11434",
                lastUpdated: Date()
            )
        }

        return nil
    }

    private func queryLiveDaemon() async -> AIAgentQuotaSnapshot? {
        guard let tagsUrl = URL(string: "http://127.0.0.1:11434/api/tags") else { return nil }

        do {
            let (data, response) = try await session.data(from: tagsUrl)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                return nil
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let modelsArray = json["models"] as? [[String: Any]] else {
                return nil
            }

            var modelQuotas: [AIModelQuota] = []

            for item in modelsArray.prefix(5) {
                guard let name = item["name"] as? String else { continue }
                let sizeBytes = (item["size"] as? Int64) ?? 0
                let sizeGB = Double(sizeBytes) / 1_073_741_824.0

                let details = item["details"] as? [String: Any]
                let paramSize = (details?["parameter_size"] as? String) ?? ""

                let label = paramSize.isEmpty ? name : "\(name) (\(paramSize))"
                let windowDesc = sizeGB > 0 ? String(format: "%.1f GB (Local GGUF)", sizeGB) : "Local GGUF"

                modelQuotas.append(
                    AIModelQuota(
                        id: "ollama-\(name)",
                        modelName: name,
                        label: label,
                        remainingFraction: 1.0,
                        resetTime: nil,
                        windowDescription: windowDesc
                    )
                )
            }

            if modelQuotas.isEmpty {
                modelQuotas.append(
                    AIModelQuota(
                        id: "ollama-ready",
                        modelName: "Ready",
                        label: "No local models pulled yet",
                        remainingFraction: 1.0,
                        resetTime: nil,
                        windowDescription: "Run 'ollama run <model>'"
                    )
                )
            }

            return AIAgentQuotaSnapshot(
                provider: .ollama,
                userTier: "Unlimited Local",
                models: modelQuotas,
                isConnected: true,
                endpointDescription: "127.0.0.1:11434 (Loopback)",
                lastUpdated: Date()
            )
        } catch {
            return nil
        }
    }
}
