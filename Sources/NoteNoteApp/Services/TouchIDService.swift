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
    
    /// Prompts the user with Touch ID or their Mac user passcode to unlock a note.
    /// - Note: Touch ID locking provides a UI-level privacy shield on-screen.
    ///   If authentication is cancelled or credentials fail, this strictly returns `false` (fail-closed).
    ///   If the Mac does not have biometrics or passcode configured (`canEvaluatePolicy` is false),
    ///   it allows immediate click-to-unlock so users on uncredentialed machines are not locked out.
    public func authenticate(reason: String = "Unlock this private sticky note") async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            do {
                return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            } catch {
                // Fail-closed on wrong credentials, user cancellation, or evaluation error
                print("TouchID / Passcode authentication failed or cancelled: \(error.localizedDescription)")
                return false
            }
        } else {
            // Intentional fallback: if the host Mac has neither Touch ID nor passcode configured,
            // allow unlock via button click so the user is not permanently locked out.
            return true
        }
    }
}
