import Foundation

enum ClamshellNotifier {
    static func sendLowBatteryWarning(capacity: Int) {
        UserNotificationService.post(
            identifier: "Harmonotch_Clamshell_60Warning",
            title: L10n.Clamshell.warningNotificationTitle,
            body: L10n.Clamshell.warningNotificationBody(capacity: capacity)
        )
    }
}
