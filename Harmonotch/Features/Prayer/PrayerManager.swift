import Foundation
import CoreLocation
#if compiler(>=6.4)
import MapKit
#endif
import Combine
import UserNotifications

struct PrayerScheduleItem: Identifiable, Hashable {
    let id: String
    let name: String
    let arabicName: String
    let iconName: String
    let time: Date
    let timeString: String
    var isCurrent: Bool
    var isNext: Bool
}

final class PrayerManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = PrayerManager()

    @Published var selectedCity: CityPreset {
        didSet {
            UserDefaults.standard.set(selectedCity.id, forKey: "Harmonotch_SelectedCityId")
            recalculatePrayerTimes()
        }
    }
    @Published var useGPS: Bool {
        didSet {
            UserDefaults.standard.set(useGPS, forKey: "Harmonotch_UseGPS")
            if useGPS {
                locationManager.requestWhenInUseAuthorization()
                locationManager.startUpdatingLocation()
            } else {
                locationManager.stopUpdatingLocation()
                recalculatePrayerTimes()
            }
        }
    }
    @Published var currentLocationName: String = "Jakarta"
    @Published var prayerItems: [PrayerScheduleItem] = []
    @Published var nextPrayerItem: PrayerScheduleItem?
    @Published var currentPrayerItem: PrayerScheduleItem?
    @Published var hijriDateString: String = ""
    @Published var gregorianDateString: String = ""
    @Published var activeAdzanAlertPrayer: String? = nil
    @Published var qiblaHeading: Double = 0.0
    @Published var qiblaString: String = ""
    @Published var imsakTimeString: String = ""

    private let locationManager = CLLocationManager()
    private var customGPSCoordinates: CLLocationCoordinate2D?
    private var checkTimer: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private var lastTriggeredPrayerKey: String = ""
    private var lastCalculationDate: Date = Date()

    private let calendar = Calendar.current
    private let hijriCalendar = Calendar(identifier: .islamicUmmAlQura)
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone.current
        return f
    }()
    private let gregorianFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMMM yyyy"
        return f
    }()
    private let hijriFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .islamicUmmAlQura)
        return f
    }()

    override init() {
        let savedCityId = UserDefaults.standard.string(forKey: "Harmonotch_SelectedCityId") ?? CityPreset.defaultCity.id
        let initialCity = CityPreset.presets.first(where: { $0.id == savedCityId }) ?? CityPreset.defaultCity
        self.selectedCity = initialCity
        self.useGPS = UserDefaults.standard.bool(forKey: "Harmonotch_UseGPS")

        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.distanceFilter = 5000

        requestNotificationPermissions()
        recalculatePrayerTimes()
        startPeriodicTimer()
        setupDayChangeListener()

        if useGPS {
            locationManager.startUpdatingLocation()
        }
    }

    private func setupDayChangeListener() {
        NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.recalculatePrayerTimes()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .languageDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.recalculatePrayerTimes()
            }
            .store(in: &cancellables)
    }

    func recalculatePrayerTimes() {
        let cal = Calendar.current
        let today = Date()
        self.lastCalculationDate = today

        let dateComponents = cal.dateComponents([.year, .month, .day], from: today)

        let lat: Double
        let lon: Double
        let locationLabel: String

        if useGPS, let gps = customGPSCoordinates {
            lat = gps.latitude
            lon = gps.longitude
            locationLabel = currentLocationName.isEmpty ? "Lokasi Saya" : currentLocationName
        } else {
            lat = selectedCity.latitude
            lon = selectedCity.longitude
            locationLabel = selectedCity.name
        }

        self.currentLocationName = locationLabel
        self.gregorianDateString = formatGregorianDate(today)
        self.hijriDateString = formatHijriDate(today)

        let coords = Coordinates(latitude: lat, longitude: lon)
        var params = CalculationMethod.singapore.params
        // Standar Kemenag RI (Ihtiyat +2 menit pengaman)
        params.methodAdjustments = PrayerAdjustments(fajr: 2, sunrise: -2, dhuhr: 2, asr: 2, maghrib: 2, isha: 2)

        guard let prayers = PrayerTimes(coordinates: coords, date: dateComponents, calculationParameters: params) else {
            return
        }

        let qibla = Qibla(coordinates: coords)
        let heading = (qibla.direction * 10).rounded() / 10
        self.qiblaHeading = heading
        let cardinal = compassCardinal(for: heading)
        self.qiblaString = "\(Int(heading.rounded()))° \(cardinal)"

        let imsakDate = prayers.fajr.addingTimeInterval(-10 * 60)
        self.imsakTimeString = timeFormatter.string(from: imsakDate)

        let rawList: [(id: String, name: String, ar: String, icon: String, date: Date)] = [
            ("subuh", L10n.Prayer.localizedPrayerName("fajr"), "الفجر", "sunrise.fill", prayers.fajr),
            ("terbit", L10n.Prayer.localizedPrayerName("sunrise"), "الشروق", "sun.horizon.fill", prayers.sunrise),
            ("dzuhur", L10n.Prayer.localizedPrayerName("dhuhr"), "الظهر", "sun.max.fill", prayers.dhuhr),
            ("ashar", L10n.Prayer.localizedPrayerName("asr"), "العصر", "sun.haze.fill", prayers.asr),
            ("maghrib", L10n.Prayer.localizedPrayerName("maghrib"), "المغرب", "sunset.fill", prayers.maghrib),
            ("isya", L10n.Prayer.localizedPrayerName("isha"), "العشاء", "moon.stars.fill", prayers.isha)
        ]

        let now = Date()
        var current: PrayerScheduleItem?
        var next: PrayerScheduleItem?

        let mainPrayers = rawList.filter { $0.id != "terbit" }
        for (index, p) in mainPrayers.enumerated() {
            if now < p.date {
                next = PrayerScheduleItem(
                    id: p.id,
                    name: p.name,
                    arabicName: p.ar,
                    iconName: p.icon,
                    time: p.date,
                    timeString: timeFormatter.string(from: p.date),
                    isCurrent: false,
                    isNext: true
                )
                if index > 0 {
                    let prev = mainPrayers[index - 1]
                    current = PrayerScheduleItem(
                        id: prev.id,
                        name: prev.name,
                        arabicName: prev.ar,
                        iconName: prev.icon,
                        time: prev.date,
                        timeString: timeFormatter.string(from: prev.date),
                        isCurrent: true,
                        isNext: false
                    )
                } else if let last = mainPrayers.last {
                    current = PrayerScheduleItem(
                        id: last.id,
                        name: last.name,
                        arabicName: last.ar,
                        iconName: last.icon,
                        time: last.date,
                        timeString: timeFormatter.string(from: last.date),
                        isCurrent: true,
                        isNext: false
                    )
                }
                break
            }
        }

        if next == nil, let first = mainPrayers.first {
            next = PrayerScheduleItem(
                id: first.id,
                name: first.name,
                arabicName: first.ar,
                iconName: first.icon,
                time: first.date,
                timeString: timeFormatter.string(from: first.date),
                isCurrent: false,
                isNext: true
            )
            if let isya = mainPrayers.last {
                current = PrayerScheduleItem(
                    id: isya.id,
                    name: isya.name,
                    arabicName: isya.ar,
                    iconName: isya.icon,
                    time: isya.date,
                    timeString: timeFormatter.string(from: isya.date),
                    isCurrent: true,
                    isNext: false
                )
            }
        }

        self.nextPrayerItem = next
        self.currentPrayerItem = current

        self.prayerItems = rawList.map { item in
            PrayerScheduleItem(
                id: item.id,
                name: item.name,
                arabicName: item.ar,
                iconName: item.icon,
                time: item.date,
                timeString: timeFormatter.string(from: item.date),
                isCurrent: item.id == current?.id,
                isNext: item.id == next?.id
            )
        }
    }

    private func startPeriodicTimer() {
        checkTimer = Timer.publish(every: 15, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkTimeAndTriggerAdzanIfNeeded()
            }
    }

    private func checkTimeAndTriggerAdzanIfNeeded() {
        let now = Date()
        let cal = self.calendar

        if !cal.isDate(now, inSameDayAs: lastCalculationDate) {
            recalculatePrayerTimes()
            return
        }

        let nowComponents = cal.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let adzanPrayers = prayerItems.filter { $0.id != "terbit" }

        for prayer in adzanPrayers {
            let pComponents = cal.dateComponents([.year, .month, .day, .hour, .minute], from: prayer.time)

            if nowComponents.year == pComponents.year &&
                nowComponents.month == pComponents.month &&
                nowComponents.day == pComponents.day &&
                nowComponents.hour == pComponents.hour &&
                nowComponents.minute == pComponents.minute {

                let triggerKey = "\(nowComponents.year!)-\(nowComponents.month!)-\(nowComponents.day!)_\(prayer.id)"

                if lastTriggeredPrayerKey != triggerKey {
                    lastTriggeredPrayerKey = triggerKey
                    triggerAdzan(for: prayer)
                    recalculatePrayerTimes()
                }
                break
            }
        }

        if let next = nextPrayerItem, now >= next.time {
            recalculatePrayerTimes()
        }
    }

    func triggerAdzan(for prayer: PrayerScheduleItem) {
        self.activeAdzanAlertPrayer = prayer.name
        AdzanPlayer.shared.play(prayerName: prayer.name)
        sendUserNotification(prayerName: prayer.name, timeString: prayer.timeString)
    }

    func dismissAdzanAlert() {
        AdzanPlayer.shared.stop()
        self.activeAdzanAlertPrayer = nil
    }

    private func formatGregorianDate(_ date: Date) -> String {
        gregorianFormatter.locale = Locale(identifier: LanguageManager.shared.currentLanguage.localeIdentifier)
        return gregorianFormatter.string(from: date)
    }

    private func formatHijriDate(_ date: Date) -> String {
        hijriFormatter.locale = Locale(identifier: LanguageManager.shared.currentLanguage.localeIdentifier)
        if LanguageManager.shared.currentLanguage == .english {
            hijriFormatter.dateFormat = "d MMMM yyyy 'AH'"
        } else {
            hijriFormatter.dateFormat = "d MMMM yyyy 'H'"
        }
        return hijriFormatter.string(from: date)
    }

    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                print("[PrayerManager] Izin notifikasi aktif.")
            }
        }
    }

    private func sendUserNotification(prayerName: String, timeString: String) {
        let content = UNMutableNotificationContent()
        content.title = "Waktu Sholat \(prayerName)"
        content.body = "Telah masuk waktu sholat \(prayerName) (\(timeString)) untuk wilayah \(currentLocationName)."
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, useGPS else { return }
        self.customGPSCoordinates = location.coordinate

        locationManager.stopUpdatingLocation()

#if compiler(>=6.4)
        if #available(macOS 26.0, *) {
            if let request = MKReverseGeocodingRequest(location: location) {
                request.getMapItems { [weak self] mapItems, _ in
                    let city = mapItems?.first?.addressRepresentations?.cityName
                        ?? mapItems?.first?.address?.shortAddress
                        ?? mapItems?.first?.name
                    if let city = city, !city.isEmpty {
                        DispatchQueue.main.async {
                            self?.currentLocationName = city
                            self?.recalculatePrayerTimes()
                        }
                    }
                }
                return
            }
        }
#endif

        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            if let city = placemarks?.first?.locality ?? placemarks?.first?.subAdministrativeArea {
                DispatchQueue.main.async {
                    self?.currentLocationName = city
                    self?.recalculatePrayerTimes()
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationManager.stopUpdatingLocation()
        print("[PrayerManager] Location error: \(error.localizedDescription)")
    }

    private func compassCardinal(for degrees: Double) -> String {
        let isEnglish = LanguageManager.shared.currentLanguage == .english
        let cardinalsEN = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let cardinalsID = ["U", "UTL", "TL", "TTL", "T", "TTG", "TG", "STG", "S", "SBD", "BD", "BBD", "B", "BBL", "BL", "UBL"]
        let list = isEnglish ? cardinalsEN : cardinalsID
        let index = Int(((degrees + 11.25).truncatingRemainder(dividingBy: 360) / 22.5)) % 16
        return list[max(0, min(15, index))]
    }
}
