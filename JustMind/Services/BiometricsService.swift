import Foundation
import LocalAuthentication

enum BiometricsResult {
    case success
    case cancelled
    case unavailable(String)
    case failure(String)
}

enum BiometricsService {
    static func canEvaluate() -> Bool {
        let ctx = LAContext()
        var error: NSError?
        return ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    static func authenticate(reason: String = "Unlock Just Mind") async -> BiometricsResult {
        let ctx = LAContext()
        ctx.localizedFallbackTitle = "Use Passcode"
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return .unavailable(error?.localizedDescription ?? "Biometrics not available")
        }
        do {
            let ok = try await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            return ok ? .success : .cancelled
        } catch let laError as LAError where laError.code == .userCancel || laError.code == .systemCancel || laError.code == .appCancel {
            return .cancelled
        } catch {
            return .failure(error.localizedDescription)
        }
    }
}
