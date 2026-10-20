import Foundation
import CoreLocation

struct CityPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let province: String
    let latitude: Double
    let longitude: Double
    let timeZoneIdentifier: String

    var coordinates: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static let presets: [CityPreset] = [
        CityPreset(id: "jkt", name: "Jakarta", province: "DKI Jakarta", latitude: -6.2088, longitude: 106.8456, timeZoneIdentifier: "Asia/Jakarta"),
        CityPreset(id: "sby", name: "Surabaya", province: "Jawa Timur", latitude: -7.2575, longitude: 112.7521, timeZoneIdentifier: "Asia/Jakarta"),
        CityPreset(id: "bdg", name: "Bandung", province: "Jawa Barat", latitude: -6.9175, longitude: 107.6191, timeZoneIdentifier: "Asia/Jakarta"),
        CityPreset(id: "mdn", name: "Medan", province: "Sumatera Utara", latitude: 3.5952, longitude: 98.6722, timeZoneIdentifier: "Asia/Jakarta"),
        CityPreset(id: "smg", name: "Semarang", province: "Jawa Tengah", latitude: -6.9667, longitude: 110.4167, timeZoneIdentifier: "Asia/Jakarta"),
        CityPreset(id: "mks", name: "Makassar", province: "Sulawesi Selatan", latitude: -5.1477, longitude: 119.4327, timeZoneIdentifier: "Asia/Makassar"),
        CityPreset(id: "plb", name: "Palembang", province: "Sumatera Selatan", latitude: -2.9761, longitude: 104.7754, timeZoneIdentifier: "Asia/Jakarta"),
        CityPreset(id: "yog", name: "Yogyakarta", province: "DI Yogyakarta", latitude: -7.7956, longitude: 110.3695, timeZoneIdentifier: "Asia/Jakarta"),
        CityPreset(id: "dps", name: "Denpasar", province: "Bali", latitude: -8.6705, longitude: 115.2126, timeZoneIdentifier: "Asia/Makassar"),
        CityPreset(id: "bpn", name: "Balikpapan", province: "Kalimantan Timur", latitude: -1.2379, longitude: 116.8289, timeZoneIdentifier: "Asia/Makassar"),
        CityPreset(id: "bch", name: "Banda Aceh", province: "Aceh", latitude: 5.5483, longitude: 95.3238, timeZoneIdentifier: "Asia/Jakarta"),
        CityPreset(id: "jay", name: "Jayapura", province: "Papua", latitude: -2.5337, longitude: 140.7181, timeZoneIdentifier: "Asia/Jayapura")
    ]

    static var defaultCity: CityPreset {
        presets[0]
    }
}
