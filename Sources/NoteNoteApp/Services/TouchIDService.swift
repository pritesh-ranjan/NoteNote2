import Foundation
import LocalAuthentication

public final class TouchIDService {
    public static let shared = TouchIDService()
    
    private init() {}
    
    public var isBiometricAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    public func authenticate(reason: String = "Unlock this private sticky note") async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            do {
                return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            } catch {
                print("TouchID / Passcode authentication failed: \(error.localizedDescription)")
                return false
            }
        } else {
            // Fallback if no biometrics/passcode configured
            return true
        }
    }
}
