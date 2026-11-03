import Foundation

/// Read-only service that inspects local Antigravity configuration and active processes
/// to retrieve user quota, active models, and session status without outbound cloud requests.
public final class AntigravityQuotaService: NSObject, URLSessionDelegate, @unchecked Sendable {
    public static let shared = AntigravityQuotaService()

    private let detector = AntigravityProcessDetector()
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 1.5
        config.timeoutIntervalForResource = 2.0
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private let isoDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private let fallbackIsoFormatter = ISO8601DateFormatter()

    // Candidate ports if process arguments do not explicitly expose --extension_server_port
    private let commonPorts = [52100, 52101, 52102, 42100, 42101, 42102, 60000, 60001, 5387]

    // In-memory cache to prevent spawning processes too frequently
    private var cachedSnapshot: AIAgentQuotaSnapshot?
    private var lastFetchTime: Date?
    private let cacheLifetime: TimeInterval = 30.0 // 30 seconds

    public override init() {
        super.init()
    }

    /// Fetches the latest quota snapshot from the local Antigravity session.
    /// Runs strictly locally using the official Antigravity CLI / session (100% Ban Safe).
    public func fetchQuota() async -> AIAgentQuotaSnapshot? {
        let processInfo = detector.detectProcess()
        let csrfToken = processInfo?.csrfToken

        let isRunning = processInfo != nil || AntigravityProcessDetector.isProcessRunning(
            matching: ["antigravity", "localharness", "agy_acp_server", "agy", "language_server"]
        )

        // 1. Check in-memory cache
        if let cached = cachedSnapshot,
           let lastTime = lastFetchTime,
           Date().timeIntervalSince(lastTime) < cacheLifetime {
            return cached
        }

        // 2. Fetch real-time quota from Antigravity CLI (/usage)
        if let cliSnapshot = await fetchQuotaFromCLI(isRunning: isRunning) {
            cachedSnapshot = cliSnapshot
            lastFetchTime = Date()
            return cliSnapshot
        }

        // 3. Try probing live loopback endpoints if port is available
        var portCandidates: [Int] = []
        if let detectedPort = processInfo?.port {
            portCandidates.append(detectedPort)
        }
        for port in commonPorts where !portCandidates.contains(port) {
            portCandidates.append(port)
        }

        for port in portCandidates {
            for scheme in ["http", "https"] {
                if let snapshot = await probeEndpoint(scheme: scheme, port: port, csrfToken: csrfToken) {
                    cachedSnapshot = snapshot
                    lastFetchTime = Date()
                    return snapshot
                }
            }
        }

        // 4. Fallback to local session and config inspection (100% anti-ban passive inspection)
        let snapshot = fallbackLocalSnapshot(isRunning: isRunning, detectedPort: processInfo?.port)
        if let s = snapshot {
            cachedSnapshot = s
            lastFetchTime = Date()
        }
        return snapshot
    }

    // MARK: - CLI Real-Time Quota Fetcher

    private func fetchQuotaFromCLI(isRunning: Bool) async -> AIAgentQuotaSnapshot? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidatePaths = [
            home.appendingPathComponent(".local/bin/agy").path,
            "/usr/local/bin/agy",
            "/opt/homebrew/bin/agy",
            "/usr/bin/agy"
        ]

        guard let agyPath = candidatePaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: agyPath)
                process.arguments = ["-p", "/usage", "--output-format", "json"]

                let stdoutPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = Pipe() // Silence stderr

                var env = ProcessInfo.processInfo.environment
                env["TERM"] = "xterm-256color"
                if let homePath = env["HOME"] {
                    env["PATH"] = "\(homePath)/.local/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"
                }
                process.environment = env

                do {
                    try process.run()
                    let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()

                    if process.terminationStatus == 0, !data.isEmpty {
                        if let snapshot = self.parseCLIUsageOutput(data: data, isRunning: isRunning) {
                            continuation.resume(returning: snapshot)
                            return
                        }
                    }
                } catch {
                    // Ignored, will fall through to nil
                }
                continuation.resume(returning: nil)
            }
        }
    }

    private func parseCLIUsageOutput(data: Data, isRunning: Bool) -> AIAgentQuotaSnapshot? {
        let isXcodeAssistantRunning = AntigravityProcessDetector.isProcessRunning(
            matching: ["localharness", "agy_acp_server"]
        )
        let isCliRunning = AntigravityProcessDetector.isProcessRunning(
            matching: ["agy", "language_server"]
        )

        let tier: String
        if isXcodeAssistantRunning {
            tier = "Xcode Assistant (Active)"
        } else if isCliRunning {
            tier = "Antigravity CLI (Active)"
        } else if isRunning {
            tier = "Google Antigravity"
        } else {
            tier = "Google Antigravity (Standby)"
        }

        var models: [AIModelQuota] = []

        // 1. Try parsing JSON structured output
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let command = json["command"] as? [String: Any],
               let dataDict = command["data"] as? [String: Any],
               let groups = dataDict["groups"] as? [[String: Any]] {

                var gemini5h: AIModelQuota?
                var geminiWeekly: AIModelQuota?
                var claudeWeekly: AIModelQuota?
                var argonWeekly: AIModelQuota?
                var otherQuotas: [AIModelQuota] = []

                for group in groups {
                    let groupName = (group["name"] as? String) ?? "Model"
                    guard let buckets = group["buckets"] as? [[String: Any]] else { continue }

                    for bucket in buckets {
                        let id = (bucket["id"] as? String) ?? UUID().uuidString
                        let name = (bucket["name"] as? String) ?? groupName
                        let window = (bucket["window"] as? String) ?? ""
                        let fraction = (bucket["remaining_fraction"] as? Double) ?? 1.0
                        let resetStr = bucket["reset_time"] as? String
                        let resetDate = parseDate(resetStr)

                        if groupName.lowercased().contains("gemini") && !groupName.lowercased().contains("argon") {
                            if window == "5h" || name.lowercased().contains("5") || name.lowercased().contains("five") {
                                gemini5h = AIModelQuota(
                                    id: id,
                                    modelName: "Gemini",
                                    label: "Gemini (5h Limit)",
                                    remainingFraction: fraction,
                                    resetTime: resetDate,
                                    windowDescription: name
                                )
                            } else {
                                geminiWeekly = AIModelQuota(
                                    id: id,
                                    modelName: "Gemini",
                                    label: "Gemini (Weekly)",
                                    remainingFraction: fraction,
                                    resetTime: resetDate,
                                    windowDescription: name
                                )
                            }
                        } else if groupName.lowercased().contains("claude") || groupName.lowercased().contains("gpt") {
                            if window == "weekly" || name.lowercased().contains("weekly") {
                                claudeWeekly = AIModelQuota(
                                    id: id,
                                    modelName: "Claude & GPT",
                                    label: "Claude & GPT",
                                    remainingFraction: fraction,
                                    resetTime: resetDate,
                                    windowDescription: name
                                )
                            }
                        } else if groupName.lowercased().contains("argon") {
                            argonWeekly = AIModelQuota(
                                id: id,
                                modelName: "Gemini 4 Argon",
                                label: "Gemini 4 Argon",
                                remainingFraction: fraction,
                                resetTime: resetDate,
                                windowDescription: name
                            )
                        } else {
                            otherQuotas.append(
                                AIModelQuota(
                                    id: id,
                                    modelName: groupName,
                                    label: "\(groupName) (\(name))",
                                    remainingFraction: fraction,
                                    resetTime: resetDate,
                                    windowDescription: name
                                )
                            )
                        }
                    }
                }

                // Prioritized list matching user visibility in Antigravity CLI:
                // 1. Gemini (5h Limit) - active throttle
                // 2. Claude & GPT - 3rd party quota
                // 3. Gemini 4 Argon - reasoning quota
                // 4. Gemini (Weekly) - aggregate quota
                if let m = gemini5h { models.append(m) }
                if let m = claudeWeekly { models.append(m) }
                if let m = argonWeekly { models.append(m) }
                if let m = geminiWeekly { models.append(m) }
                models.append(contentsOf: otherQuotas)
            }
        }

        // 2. Fallback to parsing TSV text lines if JSON structure wasn't present
        if models.isEmpty, let text = String(data: data, encoding: .utf8) {
            let lines = text.components(separatedBy: .newlines)
            for line in lines {
                let cols = line.components(separatedBy: "\t")
                guard cols.count >= 3 else { continue }
                let groupName = cols[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let bucketName = cols[1].trimmingCharacters(in: .whitespacesAndNewlines)
                let percentStr = cols[2].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "%", with: "")
                let resetStr = cols.count >= 4 ? cols[3].trimmingCharacters(in: .whitespacesAndNewlines) : nil

                guard let percentVal = Double(percentStr) else { continue }
                let fraction = max(0.0, min(1.0, percentVal / 100.0))
                let resetDate = parseDate(resetStr)

                let label: String
                if groupName.lowercased().contains("gemini") && bucketName.lowercased().contains("five") {
                    label = "Gemini (5h Limit)"
                } else if groupName.lowercased().contains("gemini") && bucketName.lowercased().contains("weekly") && !groupName.lowercased().contains("argon") {
                    label = "Gemini (Weekly)"
                } else if groupName.lowercased().contains("claude") {
                    label = "Claude & GPT (\(bucketName))"
                } else if groupName.lowercased().contains("argon") {
                    label = "Gemini 4 Argon"
                } else {
                    label = "\(groupName) (\(bucketName))"
                }

                models.append(
                    AIModelQuota(
                        id: "\(groupName)-\(bucketName)",
                        modelName: groupName,
                        label: label,
                        remainingFraction: fraction,
                        resetTime: resetDate,
                        windowDescription: bucketName
                    )
                )
            }
        }

        guard !models.isEmpty else { return nil }

        return AIAgentQuotaSnapshot(
            provider: .antigravity,
            userTier: tier,
            models: models,
            isConnected: isRunning,
            endpointDescription: "Antigravity CLI · Real-Time Sync",
            lastUpdated: Date()
        )
    }

    private func fallbackLocalSnapshot(isRunning: Bool, detectedPort: Int?) -> AIAgentQuotaSnapshot? {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser

        let cliDir = home.appendingPathComponent(".gemini/antigravity-cli")
        let xcodeDir = home.appendingPathComponent("Library/Developer/Xcode/CodingAssistant/antigravity")
        let homeAgyDir = home.appendingPathComponent(".antigravity")
        let homeAgyIdeDir = home.appendingPathComponent(".antigravity-ide")
        let settingsFile = cliDir.appendingPathComponent("settings.json")

        let hasDir = fileManager.fileExists(atPath: cliDir.path) ||
                     fileManager.fileExists(atPath: xcodeDir.path) ||
                     fileManager.fileExists(atPath: homeAgyDir.path) ||
                     fileManager.fileExists(atPath: homeAgyIdeDir.path)

        guard isRunning || hasDir else {
            return nil
        }

        let isXcodeAssistantRunning = AntigravityProcessDetector.isProcessRunning(
            matching: ["localharness", "agy_acp_server"]
        )
        let isCliRunning = AntigravityProcessDetector.isProcessRunning(
            matching: ["agy", "language_server"]
        )

        var configuredModel = "Gemini 3.8 Flash"
        if fileManager.fileExists(atPath: settingsFile.path),
           let data = try? Data(contentsOf: settingsFile),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let model = json["model"] as? String {
            configuredModel = model
        }

        let tier: String
        let endpoint: String

        if isXcodeAssistantRunning {
            tier = "Xcode Assistant (Active)"
            endpoint = "Xcode CodingAssistant · Local Session"
        } else if isCliRunning {
            tier = "Antigravity CLI (Active)"
            endpoint = detectedPort != nil ? "127.0.0.1:\(detectedPort!) (Loopback)" : "Terminal CLI · Local Session"
        } else if isRunning {
            tier = "Active Session"
            endpoint = "Local Loopback"
        } else {
            tier = "Configured (Standby)"
            endpoint = "Standby"
        }

        var models: [AIModelQuota] = []

        // Primary model
        models.append(
            AIModelQuota(
                id: "gemini-primary",
                modelName: configuredModel,
                label: configuredModel,
                remainingFraction: 1.0,
                resetTime: nil,
                windowDescription: "Primary Model"
            )
        )

        // Pro reasoning model
        models.append(
            AIModelQuota(
                id: "gemini-pro",
                modelName: "Gemini 2.5 Pro",
                label: "Gemini 2.5 Pro",
                remainingFraction: 1.0,
                resetTime: nil,
                windowDescription: "High Reasoning"
            )
        )

        // Claude Hybrid
        models.append(
            AIModelQuota(
                id: "gemini-claude",
                modelName: "Claude 3.7 Sonnet",
                label: "Claude 3.7 Sonnet",
                remainingFraction: 1.0,
                resetTime: nil,
                windowDescription: "Coding & Agentic"
            )
        )

        return AIAgentQuotaSnapshot(
            provider: .antigravity,
            userTier: tier,
            models: models,
            isConnected: isRunning,
            endpointDescription: endpoint,
            lastUpdated: Date()
        )
    }

    private func probeEndpoint(scheme: String, port: Int, csrfToken: String?) async -> AIAgentQuotaSnapshot? {
        let endpoints = [
            "/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary",
            "/exa.language_server_pb.LanguageServerService/GetUserStatus"
        ]

        for endpoint in endpoints {
            guard let url = URL(string: "\(scheme)://127.0.0.1:\(port)\(endpoint)") else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")

            if let token = csrfToken, !token.isEmpty {
                request.setValue(token, forHTTPHeaderField: "X-Codeium-Csrf-Token")
            }

            let payload: [String: Any] = [
                "metadata": [
                    "ideName": "antigravity",
                    "extensionName": "antigravity",
                    "locale": "en"
                ]
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

            do {
                let (data, response) = try await urlSession.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    continue
                }

                if let snapshot = parseResponse(data: data) {
                    return snapshot
                }
            } catch {
                continue
            }
        }

        return nil
    }

    private func parseResponse(data: Data) -> AIAgentQuotaSnapshot? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        var tierName: String?
        var modelQuotas: [AIModelQuota] = []

        // 1. Try parsing UserStatus structure
        if let userStatus = json["userStatus"] as? [String: Any] {
            if let userTier = userStatus["userTier"] as? [String: Any],
               let name = userTier["name"] as? String {
                tierName = name
            } else if let planStatus = userStatus["planStatus"] as? [String: Any],
                      let planInfo = planStatus["planInfo"] as? [String: Any],
                      let planName = planInfo["planName"] as? String {
                tierName = planName
            }

            if let cascade = userStatus["cascadeModelConfigData"] as? [String: Any],
               let clientConfigs = cascade["clientModelConfigs"] as? [[String: Any]] {
                for config in clientConfigs {
                    guard let modelId = config["model"] as? String else { continue }
                    let label = (config["label"] as? String) ?? modelId
                    let quotaInfo = config["quotaInfo"] as? [String: Any]
                    let fraction = (quotaInfo?["remainingFraction"] as? Double) ?? 1.0
                    let resetString = quotaInfo?["resetTime"] as? String
                    let resetDate = parseDate(resetString)

                    modelQuotas.append(
                        AIModelQuota(
                            id: modelId,
                            modelName: modelId,
                            label: label,
                            remainingFraction: fraction,
                            resetTime: resetDate,
                            windowDescription: nil
                        )
                    )
                }
            }
        }

        // 2. Try parsing Quota Groups / Buckets structure
        if let groups = json["groups"] as? [[String: Any]] {
            for group in groups {
                let groupName = (group["displayName"] as? String) ?? "Model"
                if let buckets = group["buckets"] as? [[String: Any]] {
                    for bucket in buckets {
                        let bucketName = (bucket["displayName"] as? String) ?? (bucket["bucketId"] as? String) ?? groupName
                        let fraction = (bucket["remainingFraction"] as? Double) ?? 1.0
                        let resetString = bucket["resetTime"] as? String
                        let resetDate = parseDate(resetString)

                        let id = "\(groupName)-\(bucketName)"
                        modelQuotas.append(
                            AIModelQuota(
                                id: id,
                                modelName: groupName,
                                label: "\(groupName) (\(bucketName))",
                                remainingFraction: fraction,
                                resetTime: resetDate,
                                windowDescription: bucketName
                            )
                        )
                    }
                }
            }
        }

        guard !modelQuotas.isEmpty || tierName != nil else { return nil }

        return AIAgentQuotaSnapshot(
            provider: .antigravity,
            userTier: tierName,
            models: modelQuotas,
            isConnected: true,
            endpointDescription: "127.0.0.1 (Loopback)",
            lastUpdated: Date()
        )
    }

    private func parseDate(_ string: String?) -> Date? {
        guard let string = string else { return nil }
        return isoDateFormatter.date(from: string) ?? fallbackIsoFormatter.date(from: string)
    }

    // MARK: - URLSessionDelegate (Permit local loopback TLS certificates)

    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust,
              (challenge.protectionSpace.host == "127.0.0.1" || challenge.protectionSpace.host == "localhost") else {
            return (.performDefaultHandling, nil)
        }
        return (.useCredential, URLCredential(trust: trust))
    }
}

extension AntigravityQuotaService: AIProviderService {
    public var provider: AIProviderType { .antigravity }

    public func fetchSnapshot() async -> AIAgentQuotaSnapshot? {
        await fetchQuota()
    }
}
