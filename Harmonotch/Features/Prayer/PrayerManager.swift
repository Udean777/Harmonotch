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
            UserDefaults.standard.set(selectedCity.id, forKey: UserDefaultsKeys.selectedCityId)
            recalculatePrayerTimes()
        }
    }
    @Published var useGPS: Bool {
        didSet {
            UserDefaults.standard.set(useGPS, forKey: UserDefaultsKeys.useGPS)
            if useGPS {
                locationManager.requestWhenInUseAuthorization()
                locationManager.startUpdatingLocation()
            } else {
                locationManager.stopUpdatingLocation()
                recalculatePrayerTimes()
            }
        }
    }
    @Published var jumatOffsetMinutes: Int {
        didSet {
            UserDefaults.standard.set(jumatOffsetMinutes, forKey: UserDefaultsKeys.jumatOffsetMinutes)
            recalculatePrayerTimes()
        }
    }
    @Published var currentLocationName: String = "Jakarta"
    @Published var prayerItems: [PrayerScheduleItem] = []
    @Published var nextPrayerItem: PrayerScheduleItem?
    @Published var currentPrayerItem: PrayerScheduleItem?
    @Published var hijriDateString: String = ""
    @Published var activeAdzanAlertPrayer: String? = nil
    @Published var qiblaHeading: Double = 0.0
    @Published var qiblaString: String = ""
    @Published var imsakTimeString: String = ""
    /// Name of the calculation method behind the displayed times.
    let calculationMethodName = "Singapore (MUIS)"

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
    private let hijriFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .islamicUmmAlQura)
        return f
    }()

    override init() {
        let savedCityId = UserDefaults.standard.string(forKey: UserDefaultsKeys.selectedCityId) ?? CityPreset.defaultCity.id
        let initialCity = CityPreset.presets.first(where: { $0.id == savedCityId }) ?? CityPreset.defaultCity
        self.selectedCity = initialCity
        self.useGPS = UserDefaults.standard.bool(forKey: UserDefaultsKeys.useGPS)
        self.jumatOffsetMinutes = UserDefaults.standard.integer(forKey: UserDefaultsKeys.jumatOffsetMinutes)

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
            locationLabel = currentLocationName.isEmpty ? L10n.Prayer.myLocation : currentLocationName
        } else {
            lat = selectedCity.latitude
            lon = selectedCity.longitude
            locationLabel = selectedCity.name
        }

        let timeZone: TimeZone
        if useGPS, customGPSCoordinates != nil {
            timeZone = .current
        } else {
            timeZone = TimeZone(identifier: selectedCity.timeZoneIdentifier) ?? .current
        }
        timeFormatter.timeZone = timeZone
        hijriFormatter.timeZone = timeZone

        self.currentLocationName = locationLabel
        self.hijriDateString = formatHijriDate(today)

        let coords = Coordinates(latitude: lat, longitude: lon)
        var params = CalculationMethod.singapore.params
        params.methodAdjustments = PrayerAdjustments(fajr: 2, sunrise: -2, dhuhr: 2, asr: 2, maghrib: 2, isha: 2)

        guard let prayers = PrayerTimes(coordinates: coords, date: dateComponents, calculationParameters: params) else {
            // Never keep showing a schedule that belongs to a previous location or method.
            self.prayerItems = []
            self.nextPrayerItem = nil
            self.currentPrayerItem = nil
            self.imsakTimeString = ""
            return
        }

        let qibla = Qibla(coordinates: coords)
        let heading = (qibla.direction * 10).rounded() / 10
        self.qiblaHeading = heading
        let cardinal = Compass.cardinal(
            for: heading,
            isEnglish: LanguageManager.shared.currentLanguage == .english
        )
        self.qiblaString = "\(Int(heading.rounded()))° \(cardinal)"

        let imsakDate = prayers.fajr.addingTimeInterval(-10 * 60)
        self.imsakTimeString = timeFormatter.string(from: imsakDate)

        let isFriday = cal.component(.weekday, from: today) == 6
        let jumatDate = prayers.dhuhr.addingTimeInterval(TimeInterval(jumatOffsetMinutes * 60))

        let rawList: [(id: String, name: String, ar: String, icon: String, date: Date)] = [
            ("subuh", L10n.Prayer.localizedPrayerName("fajr"), "الفجر", "sunrise.fill", prayers.fajr),
            ("terbit", L10n.Prayer.localizedPrayerName("sunrise"), "الشروق", "sun.horizon.fill", prayers.sunrise),
            isFriday
                ? ("jumat", L10n.Prayer.localizedPrayerName("jumat"), "الجمعة", "person.3.fill", jumatDate)
                : ("dzuhur", L10n.Prayer.localizedPrayerName("dhuhr"), "الظهر", "sun.max.fill", prayers.dhuhr),
            ("ashar", L10n.Prayer.localizedPrayerName("asr"), "العصر", "sun.haze.fill", prayers.asr),
            ("maghrib", L10n.Prayer.localizedPrayerName("maghrib"), "المغرب", "sunset.fill", prayers.maghrib),
            ("isya", L10n.Prayer.localizedPrayerName("isha"), "العشاء", "moon.stars.fill", prayers.isha)
        ]

        func item(_ id: String, _ name: String, _ ar: String, _ icon: String, _ date: Date) -> PrayerScheduleItem {
            PrayerScheduleItem(
                id: id,
                name: name,
                arabicName: ar,
                iconName: icon,
                time: date,
                timeString: timeFormatter.string(from: date),
                isCurrent: false,
                isNext: false
            )
        }

        let mainPrayers = rawList.filter { $0.id != "terbit" }
        let yesterday = cal.date(byAdding: .day, value: -1, to: today) ?? today
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today) ?? today
        let yesterdayIsha = PrayerTimes(
            coordinates: coords,
            date: cal.dateComponents([.year, .month, .day], from: yesterday),
            calculationParameters: params
        ).map { PrayerMoment(id: "isya", date: $0.isha) }
        let tomorrowFajr = PrayerTimes(
            coordinates: coords,
            date: cal.dateComponents([.year, .month, .day], from: tomorrow),
            calculationParameters: params
        ).map { PrayerMoment(id: "subuh", date: $0.fajr) }

        let position = PrayerScheduleResolver.position(
            now: Date(),
            yesterdayIsha: yesterdayIsha,
            today: mainPrayers.map { PrayerMoment(id: $0.id, date: $0.date) },
            tomorrowFajr: tomorrowFajr
        )

        func label(for moment: PrayerMoment) -> PrayerScheduleItem {
            if let known = rawList.first(where: { $0.id == moment.id }) {
                return item(known.id, known.name, known.ar, known.icon, moment.date)
            }
            return item("subuh", L10n.Prayer.localizedPrayerName("fajr"), "الفجر", "sunrise.fill", moment.date)
        }

        var next = position.next.map(label(for:))
        next?.isNext = true
        var current = position.current.map(label(for:))
        current?.isCurrent = true

        self.nextPrayerItem = next
        self.currentPrayerItem = current

        // Rows keep today's times; Current/Next are matched by id so that
        // yesterday's Isha or tomorrow's Fajr still highlight the right row.
        self.prayerItems = rawList.map { raw in
            var row = item(raw.id, raw.name, raw.ar, raw.icon, raw.date)
            row.isCurrent = raw.id == current?.id
            row.isNext = raw.id == next?.id
            return row
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

                guard let year = nowComponents.year,
                      let month = nowComponents.month,
                      let day = nowComponents.day else { continue }

                let triggerKey = "\(year)-\(month)-\(day)_\(prayer.id)"

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
                NSLog("[Harmonotch:Prayer] Notification permission granted.")
            }
        }
    }

    private func sendUserNotification(prayerName: String, timeString: String) {
        let content = UNMutableNotificationContent()
        content.title = L10n.Prayer.notificationTitle(name: prayerName)
        content.body = L10n.Prayer.notificationBody(
            name: prayerName,
            time: timeString,
            location: currentLocationName
        )
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
        NSLog("[Harmonotch:Prayer] Location error: %@", error.localizedDescription)
    }

}
