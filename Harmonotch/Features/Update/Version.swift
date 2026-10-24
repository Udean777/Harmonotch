import Foundation

enum Version {
    /// Compares dotted numeric versions. Non-numeric suffixes (`1.2.3-beta`) are
    /// truncated and missing components count as zero (`1.2` == `1.2.0`).
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let candidateParts = numericParts(candidate)
        let currentParts = numericParts(current)
        let count = max(candidateParts.count, currentParts.count)

        for i in 0..<count {
            let lhs = i < candidateParts.count ? candidateParts[i] : 0
            let rhs = i < currentParts.count ? currentParts[i] : 0
            if lhs > rhs { return true }
            if lhs < rhs { return false }
        }
        return false
    }

    private static func numericParts(_ version: String) -> [Int] {
        let cleaned = version.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
        return cleaned.split(separator: ".").compactMap { $0.prefix(while: \.isNumber) }.compactMap { Int($0) }
    }
}
