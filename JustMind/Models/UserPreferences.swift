import Foundation
import SwiftUI

enum UserPreferences {
    enum Keys {
        static let onboardingComplete = "jm.onboardingComplete"
        static let preferredName = "jm.preferredName"
        static let appLockEnabled = "jm.appLockEnabled"
        static let nextAppointment = "jm.nextAppointment"
        static let newsletterSubscribed = "jm.newsletterSubscribed"
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
    var newsletterSubscribed: Bool {
        didSet { UserDefaults.standard.set(newsletterSubscribed, forKey: UserPreferences.Keys.newsletterSubscribed) }
    }

    init() {
        let d = UserDefaults.standard
        self.preferredName = d.string(forKey: UserPreferences.Keys.preferredName) ?? ""
        self.onboardingComplete = d.bool(forKey: UserPreferences.Keys.onboardingComplete)
        self.appLockEnabled = d.bool(forKey: UserPreferences.Keys.appLockEnabled)
        self.nextAppointment = d.object(forKey: UserPreferences.Keys.nextAppointment) as? Date
        self.newsletterSubscribed = d.bool(forKey: UserPreferences.Keys.newsletterSubscribed)
    }

    func resetAll() {
        let d = UserDefaults.standard
        for key in [
            UserPreferences.Keys.onboardingComplete,
            UserPreferences.Keys.preferredName,
            UserPreferences.Keys.appLockEnabled,
            UserPreferences.Keys.nextAppointment,
            UserPreferences.Keys.newsletterSubscribed
        ] {
            d.removeObject(forKey: key)
        }
        preferredName = ""
        onboardingComplete = false
        appLockEnabled = false
        nextAppointment = nil
        newsletterSubscribed = false
    }
}
