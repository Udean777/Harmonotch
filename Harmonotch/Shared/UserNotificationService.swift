import Foundation
import UserNotifications

nonisolated enum UserNotificationService {
  static func requestAuthorization(
    options: UNAuthorizationOptions = [.alert, .sound, .badge],
    completion: ((Bool) -> Void)? = nil
  ) {
    UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, _ in
      completion?(granted)
    }
  }

  static func post(
    identifier: String,
    title: String,
    body: String,
    sound: UNNotificationSound? = .default,
    trigger: UNNotificationTrigger? = nil
  ) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = sound

    let request = UNNotificationRequest(
      identifier: identifier,
      content: content,
      trigger: trigger
    )

    UNUserNotificationCenter.current().add(request) { error in
      if let error {
        NSLog("[Harmonotch:Notification] Failed to deliver notification (%@): %@", identifier, error.localizedDescription)
      }
    }
  }
}
