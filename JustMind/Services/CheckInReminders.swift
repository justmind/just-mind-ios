import Foundation
import UserNotifications

extension Notification.Name {
    /// Posted when the user taps the weekly check-in notification.
    static let jmOpenWCI = Notification.Name("jmOpenWCI")
}

/// Schedules the weekly between-session check-in nudge. (Change 4.)
///
/// Strategy: keep a single pending notification for the next Sunday 10:00 that
/// is at least 7 days after the last completed Wellbeing Check-In. Completing a
/// check-in pushes that Sunday out, so the nudge only fires when a full week
/// has lapsed without a check-in. Everything is local — no remote scheduling.
enum CheckInReminders {
    static let lastCompletedKey = "ros_last_completed_date"
    private static let requestID = "ros_weekly_checkin"

    static var lastCompleted: Date? {
        UserDefaults.standard.object(forKey: lastCompletedKey) as? Date
    }

    /// Ask for permission. Call during onboarding, not at launch.
    @discardableResult
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Record a completed check-in and reschedule.
    static func recordCompletion(_ date: Date) {
        UserDefaults.standard.set(date, forKey: lastCompletedKey)
        Task { await refreshSchedule() }
    }

    /// (Re)schedule the nudge based on current permission + last completion.
    static func refreshSchedule() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let authorized = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional

        // Always clear the old pending request first.
        center.removePendingNotificationRequests(withIdentifiers: [requestID])
        guard authorized, let fireDate = nextEligibleSunday() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Weekly Check-In"
        content.body = "How are you doing this week? Take 2 minutes to check in."
        content.sound = .default
        content.userInfo = ["deeplink": "wci"]

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: requestID, content: content, trigger: trigger)
        try? await center.add(request)
    }

    /// First Sunday at 10:00 that is in the future and at least 7 days after
    /// the last completion.
    private static func nextEligibleSunday() -> Date? {
        let cal = Calendar.current
        let now = Date()
        let earliest: Date
        if let last = lastCompleted {
            earliest = cal.date(byAdding: .day, value: 7, to: last) ?? now
        } else {
            earliest = now
        }
        let lowerBound = max(now, earliest)

        var comps = DateComponents()
        comps.weekday = 1 // Sunday (Gregorian)
        comps.hour = 10
        comps.minute = 0
        return cal.nextDate(after: lowerBound, matching: comps, matchingPolicy: .nextTime)
    }
}

/// Routes a tapped weekly-check-in notification to the Wellbeing Check-In tab.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        if let deeplink = info["deeplink"] as? String, deeplink == "wci" {
            await MainActor.run {
                NotificationCenter.default.post(name: .jmOpenWCI, object: nil)
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
