import Foundation

struct Version: Comparable, Hashable, LosslessStringConvertible, CustomStringConvertible, Sendable {
    let components: [Int]
    let rawString: String

    init(_ string: String) {
        self.rawString = string
        let cleaned = string.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
        self.components = cleaned.split(separator: ".")
            .compactMap { $0.prefix(while: \.isNumber) }
            .compactMap { Int($0) }
    }

    var description: String { rawString }

    static func == (lhs: Version, rhs: Version) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for i in 0..<count {
            let left = i < lhs.components.count ? lhs.components[i] : 0
            let right = i < rhs.components.count ? rhs.components[i] : 0
            if left != right { return false }
        }
        return true
    }

    func hash(into hasher: inout Hasher) {
        var trimmed = components
        while trimmed.last == 0 {
            trimmed.removeLast()
        }
        hasher.combine(trimmed)
    }

    static func < (lhs: Version, rhs: Version) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for i in 0..<count {
            let left = i < lhs.components.count ? lhs.components[i] : 0
            let right = i < rhs.components.count ? rhs.components[i] : 0
            if left < right { return true }
            if left > right { return false }
        }
        return false
    }

    /// Compares dotted numeric versions. Non-numeric suffixes (`1.2.3-beta`) are
    /// truncated and missing components count as zero (`1.2` == `1.2.0`).
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        Version(candidate) > Version(current)
    }
}
