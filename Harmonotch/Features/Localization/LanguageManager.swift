import SwiftUI
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case indonesian = "id"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .indonesian:
            return "Bahasa Indonesia"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .english:
            return "en_US"
        case .indonesian:
            return "id_ID"
        }
    }
}

extension UserDefaultsKeys {
    static let appLanguage = UserDefaultsKey<AppLanguage>(name: "Harmonotch_AppLanguage", defaultValue: .english)
}

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard[UserDefaultsKeys.appLanguage] = currentLanguage
            NotificationCenter.default.post(name: .languageDidChange, object: currentLanguage)
        }
    }

    init() {
        self.currentLanguage = UserDefaults.standard[UserDefaultsKeys.appLanguage]
    }

    func setLanguage(_ language: AppLanguage) {
        guard language != currentLanguage else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            self.currentLanguage = language
        }
    }
}

extension Notification.Name {
    static let languageDidChange = Notification.Name("Harmonotch_LanguageDidChange")
}
