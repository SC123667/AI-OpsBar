import Foundation
import UserNotifications

@MainActor
final class MonitorNotificationManager {
    private var hasRequestedAuthorization = false

    func requestAuthorizationIfNeeded(enabled: Bool) {
        guard enabled, !hasRequestedAuthorization else {
            return
        }

        hasRequestedAuthorization = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func notifyServiceTransition(
        serviceName: String,
        previous: ProbeState?,
        current: ProbeState,
        detail: String,
        settings: NotificationSettings
    ) {
        guard settings.enabled else {
            return
        }

        if current == .pass, !settings.notifyOnRecovery {
            return
        }

        guard shouldNotify(previous: previous, current: current) else {
            return
        }

        scheduleNotification(
            identifier: "service.\(serviceName).\(current.rawValue)",
            title: title(for: serviceName, current: current),
            body: detail
        )
    }

    func notifyQuotaWarning(serviceName: String, quota: QuotaSnapshot, settings: NotificationSettings) {
        guard settings.enabled, settings.notifyOnQuotaWarning else {
            return
        }

        let title = "\(serviceName) \(L10n.text(.notificationQuotaTitleSuffix))"
        scheduleNotification(
            identifier: "quota.\(serviceName)",
            title: title,
            body: quota.compactText
        )
    }

    private func shouldNotify(previous: ProbeState?, current: ProbeState) -> Bool {
        guard let previous else {
            return current != .pass
        }

        if previous == current {
            return false
        }

        if previous == .pass {
            return current != .pass
        }

        return current == .pass || current == .fail
    }

    private func title(for serviceName: String, current: ProbeState) -> String {
        switch current {
        case .pass:
            return "\(serviceName) \(L10n.text(.notificationRecovered))"
        case .warning:
            return "\(serviceName) \(L10n.text(.notificationWarning))"
        case .fail:
            return "\(serviceName) \(L10n.text(.notificationFailed))"
        }
    }

    private func scheduleNotification(identifier: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
