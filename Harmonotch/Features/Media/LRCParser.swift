import Foundation

struct LyricLine: Identifiable, Hashable {
    let id = UUID()
    let time: TimeInterval
    let text: String
}

enum LRCParser {
    /// Parses `[mm:ss.xx]` timestamps. Lines may carry several timestamps, and
    /// metadata tags such as `[ar:...]` are ignored because they have no `mm:ss`.
    static func parse(_ lrc: String) -> [LyricLine] {
        var result: [LyricLine] = []

        for line in lrc.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("[") else { continue }

            var remaining = trimmed
            var timestamps: [TimeInterval] = []

            while remaining.hasPrefix("["), let closeIdx = remaining.firstIndex(of: "]") {
                let tag = String(remaining[remaining.index(after: remaining.startIndex)..<closeIdx])
                remaining = String(remaining[remaining.index(after: closeIdx)...]).trimmingCharacters(in: .whitespaces)

                let parts = tag.components(separatedBy: ":")
                if parts.count == 2,
                   let mins = Double(parts[0]),
                   let secs = Double(parts[1]) {
                    timestamps.append(mins * 60.0 + secs)
                }
            }

            let text = remaining.trimmingCharacters(in: .whitespaces)
            if !text.isEmpty {
                for timestamp in timestamps {
                    result.append(LyricLine(time: timestamp, text: text))
                }
            }
        }

        return result.sorted { $0.time < $1.time }
    }
}
