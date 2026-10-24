import Foundation

enum Compass {
    static func cardinal(for degrees: Double, isEnglish: Bool) -> String {
        let cardinalsEN = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let cardinalsID = ["U", "UTL", "TL", "TTL", "T", "TTG", "TG", "STG", "S", "SBD", "BD", "BBD", "B", "BBL", "BL", "UBL"]
        let list = isEnglish ? cardinalsEN : cardinalsID
        let normalized = (degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        let index = Int(((normalized + 11.25) / 22.5).rounded(.down)) % 16
        return list[max(0, min(15, index))]
    }
}
