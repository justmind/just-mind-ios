import Foundation
import SwiftUI

enum UserPreferences {
    enum Keys {
        static let onboardingComplete = "jm.onboardingComplete"
        static let preferredName = "jm.preferredName"
        static let appLockEnabled = "jm.appLockEnabled"
        static let nextAppointment = "jm.nextAppointment"
        static let preferredBlogTopics = "jm.preferredBlogTopics"
        static let appOpenCount = "jm.appOpenCount"
    }
}

@propertyWrapper
struct UserDefault<Value> {
    let key: String
    let defaultValue: Value
    var wrappedValue: Value {
        get { (UserDefaults.standard.object(forKey: key) as? Value) ?? defaultValue }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

@Observable
final class AppPreferences {
    var preferredName: String {
        didSet { UserDefaults.standard.set(preferredName, forKey: UserPreferences.Keys.preferredName) }
    }
    var onboardingComplete: Bool {
        didSet { UserDefaults.standard.set(onboardingComplete, forKey: UserPreferences.Keys.onboardingComplete) }
    }
    var appLockEnabled: Bool {
        didSet { UserDefaults.standard.set(appLockEnabled, forKey: UserPreferences.Keys.appLockEnabled) }
    }
    var nextAppointment: Date? {
        didSet {
            if let nextAppointment {
                UserDefaults.standard.set(nextAppointment, forKey: UserPreferences.Keys.nextAppointment)
            } else {
                UserDefaults.standard.removeObject(forKey: UserPreferences.Keys.nextAppointment)
            }
        }
    }
    /// Curated blog topic labels the user chose during onboarding (e.g.
    /// "Anxiety", "Parenting"). Empty = show everything.
    var preferredBlogTopics: [String] {
        didSet { UserDefaults.standard.set(preferredBlogTopics, forKey: UserPreferences.Keys.preferredBlogTopics) }
    }

    init() {
        let d = UserDefaults.standard
        self.preferredName = d.string(forKey: UserPreferences.Keys.preferredName) ?? ""
        self.onboardingComplete = d.bool(forKey: UserPreferences.Keys.onboardingComplete)
        self.appLockEnabled = d.bool(forKey: UserPreferences.Keys.appLockEnabled)
        self.nextAppointment = d.object(forKey: UserPreferences.Keys.nextAppointment) as? Date
        self.preferredBlogTopics = d.stringArray(forKey: UserPreferences.Keys.preferredBlogTopics) ?? []
    }

    func resetAll() {
        let d = UserDefaults.standard
        for key in [
            UserPreferences.Keys.onboardingComplete,
            UserPreferences.Keys.preferredName,
            UserPreferences.Keys.appLockEnabled,
            UserPreferences.Keys.nextAppointment,
            UserPreferences.Keys.preferredBlogTopics,
            UserPreferences.Keys.appOpenCount
        ] {
            d.removeObject(forKey: key)
        }
        preferredName = ""
        onboardingComplete = false
        appLockEnabled = false
        nextAppointment = nil
        preferredBlogTopics = []
    }
}
