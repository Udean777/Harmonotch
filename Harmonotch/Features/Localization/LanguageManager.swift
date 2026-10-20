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

    var shortCode: String {
        switch self {
        case .english:
            return "EN"
        case .indonesian:
            return "ID"
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

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "Harmonotch_AppLanguage")
            NotificationCenter.default.post(name: .languageDidChange, object: currentLanguage)
        }
    }

    init() {
        let savedCode = UserDefaults.standard.string(forKey: "Harmonotch_AppLanguage") ?? AppLanguage.english.rawValue
        self.currentLanguage = AppLanguage(rawValue: savedCode) ?? .english
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
