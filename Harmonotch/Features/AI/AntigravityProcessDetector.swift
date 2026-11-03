import Foundation
import Darwin

/// Information about a detected local Antigravity language server process.
public struct AntigravityProcessInfo: Equatable, Sendable {
    public let pid: pid_t
    public let port: Int?
    public let csrfToken: String?

    public init(pid: pid_t, port: Int?, csrfToken: String?) {
        self.pid = pid
        self.port = port
        self.csrfToken = csrfToken
    }
}

/// Safely inspects running system processes in-memory using Darwin `libproc` and `sysctl`
/// to locate Antigravity and its local language server without triggering user permission alerts.
public struct AntigravityProcessDetector: Sendable {
    public init() {}

    /// Scans for running Antigravity or language server processes and extracts port & CSRF token.
    nonisolated public func detectProcess() -> AntigravityProcessInfo? {
        let selfPid = ProcessInfo.processInfo.processIdentifier
        let pids = Self.allPIDs()
        var foundPid: pid_t?
        var detectedPort: Int?
        var detectedCsrfToken: String?

        for pid in pids where pid != selfPid {
            let path = Self.path(for: pid)?.lowercased() ?? ""
            guard !path.contains("harmonotch") else { continue }

            let args = Self.arguments(for: pid) ?? []
            let joined = (args.joined(separator: " ") + " " + path).lowercased()
            guard !joined.contains("harmonotch") else { continue }

            // Look for Antigravity language server, localharness, agy, or Xcode coding assistant agent
            let isAntigravity = joined.contains("antigravity") ||
                                joined.contains("localharness") ||
                                joined.contains("agy_acp_server") ||
                                path.hasSuffix("/agy") ||
                                joined.contains("language_server")
            guard isAntigravity else { continue }

            if foundPid == nil {
                foundPid = pid
            }

            var index = 0
            while index < args.count {
                let arg = args[index]

                if arg == "--extension_server_port" || arg == "--server_port" || arg == "--port" {
                    if index + 1 < args.count, let p = Int(args[index + 1]) {
                        detectedPort = p
                        index += 1
                    }
                } else if arg.starts(with: "--extension_server_port=") {
                    let val = String(arg.dropFirst("--extension_server_port=".count))
                    detectedPort = Int(val)
                } else if arg.starts(with: "--server_port=") {
                    let val = String(arg.dropFirst("--server_port=".count))
                    detectedPort = Int(val)
                } else if arg.starts(with: "--port=") {
                    let val = String(arg.dropFirst("--port=".count))
                    detectedPort = Int(val)
                } else if arg == "--csrf_token" || arg == "--csrfToken" {
                    if index + 1 < args.count {
                        detectedCsrfToken = args[index + 1]
                        index += 1
                    }
                } else if arg.starts(with: "--csrf_token=") {
                    detectedCsrfToken = String(arg.dropFirst("--csrf_token=".count))
                } else if arg.starts(with: "--csrfToken=") {
                    detectedCsrfToken = String(arg.dropFirst("--csrfToken=".count))
                }

                index += 1
            }

            if detectedPort != nil { break }
        }

        guard let pid = foundPid else { return nil }

        // If port was not specified on command line args, check recent CLI log
        if detectedPort == nil {
            detectedPort = Self.extractPortFromRecentLog()
        }

        return AntigravityProcessInfo(pid: pid, port: detectedPort, csrfToken: detectedCsrfToken)
    }

    /// Checks whether any currently running process matches the given query strings in its arguments or executable path.
    nonisolated public static func isProcessRunning(matching substrings: [String]) -> Bool {
        let selfPid = ProcessInfo.processInfo.processIdentifier
        let pids = allPIDs()
        let lowerSubstrings = substrings.map { $0.lowercased() }

        for pid in pids where pid != selfPid {
            if let path = path(for: pid)?.lowercased() {
                guard !path.contains("harmonotch") else { continue }
                for sub in lowerSubstrings {
                    if path.contains(sub) || path.hasSuffix("/\(sub)") {
                        return true
                    }
                }
            }
            guard let args = arguments(for: pid), !args.isEmpty else { continue }
            let joined = args.joined(separator: " ").lowercased()
            guard !joined.contains("harmonotch") else { continue }
            for sub in lowerSubstrings {
                if joined.contains(sub) {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Darwin Process Queries

    nonisolated private static func allPIDs() -> [pid_t] {
        let countEstimate = proc_listallpids(nil, 0)
        guard countEstimate > 0 else { return [] }

        var buffer = [pid_t](repeating: 0, count: Int(countEstimate) + 64)
        let actualCount = proc_listallpids(&buffer, Int32(buffer.count * MemoryLayout<pid_t>.size))
        guard actualCount > 0 else { return [] }

        // proc_listallpids returns the count of items in buffer, not the byte size
        return buffer.prefix(Int(actualCount)).filter { $0 > 0 }
    }

    nonisolated private static func path(for pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4096)
        let bytes = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard bytes > 0 else { return nil }
        return String(cString: buffer)
    }

    nonisolated private static func arguments(for pid: pid_t) -> [String]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size: Int = 16384
        var buffer = [CChar](repeating: 0, count: size)

        let status = sysctl(&mib, 3, &buffer, &size, nil, 0)
        guard status == 0, size >= MemoryLayout<Int32>.size else {
            return nil
        }

        return buffer.withUnsafeBytes { rawBuffer -> [String]? in
            guard let baseAddress = rawBuffer.baseAddress else { return nil }

            let argc = baseAddress.load(as: Int32.self)
            var pointer = baseAddress.advanced(by: MemoryLayout<Int32>.size)
            let endAddress = baseAddress.advanced(by: size)

            // 1. Skip executable path
            while pointer < endAddress && pointer.load(as: UInt8.self) != 0 {
                pointer = pointer.advanced(by: 1)
            }

            // 2. Skip null bytes
            while pointer < endAddress && pointer.load(as: UInt8.self) == 0 {
                pointer = pointer.advanced(by: 1)
            }

            // 3. Extract argc strings
            var arguments: [String] = []
            for _ in 0..<argc {
                guard pointer < endAddress else { break }
                let arg = String(cString: pointer.assumingMemoryBound(to: CChar.self))
                arguments.append(arg)
                pointer = pointer.advanced(by: arg.utf8.count + 1)
            }

            return arguments
        }
    }

    nonisolated private static func extractPortFromRecentLog() -> Int? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let logDir = home.appendingPathComponent(".gemini/antigravity-cli/log")
        guard let files = try? FileManager.default.contentsOfDirectory(at: logDir, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles) else {
            return nil
        }
        let sortedLogs = files
            .filter { $0.lastPathComponent.hasPrefix("cli-") && $0.pathExtension == "log" }
            .compactMap { url -> (URL, Date)? in
                guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                      let date = values.contentModificationDate else { return nil }
                return (url, date)
            }
            .sorted { $0.1 > $1.1 }

        guard let latest = sortedLogs.first, Date().timeIntervalSince(latest.1) < 86400 else {
            return nil
        }

        guard let fileHandle = try? FileHandle(forReadingFrom: latest.0) else { return nil }
        defer { try? fileHandle.close() }
        let headerData = fileHandle.readData(ofLength: 4096)
        guard let text = String(data: headerData, encoding: .utf8) else { return nil }

        for line in text.components(separatedBy: .newlines) {
            if line.contains("Language server listening on random port at") && line.contains("for HTTP") {
                let parts = line.components(separatedBy: " ")
                if let idx = parts.firstIndex(of: "at"), idx + 1 < parts.count, let port = Int(parts[idx + 1]) {
                    return port
                }
            }
        }
        return nil
    }
}
