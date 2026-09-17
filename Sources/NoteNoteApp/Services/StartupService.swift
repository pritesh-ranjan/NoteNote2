import Foundation
import ServiceManagement
import Combine

@MainActor
public final class StartupService: ObservableObject {
    public static let shared = StartupService()
    
    private let firstLaunchKey = "NoteNote_FirstLaunchCompleted"
    private let bundleSignatureKey = "NoteNote_LastBundleSignature"
    
    @Published public private(set) var isLaunchAtLoginEnabled: Bool = false
    
    private init() {
        refreshStatus()
    }
    
    public func refreshStatus() {
        isLaunchAtLoginEnabled = (SMAppService.mainApp.status == .enabled)
    }
    
    @discardableResult
    public func setLaunchAtLogin(enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            refreshStatus()
            return true
        } catch {
            AppLogger.error("Failed to update Launch at Login", error: error)
            refreshStatus()
            return false
        }
    }
    
    public func performFirstLaunchSetupIfNeeded() {
        let bundleURL = Bundle.main.bundleURL
        let attrs = try? FileManager.default.attributesOfItem(atPath: bundleURL.path)
        let creation = (attrs?[.creationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let mod = (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let currentSignature = "\(bundleURL.path)_\(creation)_\(mod)"
        
        let storedSignature = UserDefaults.standard.string(forKey: bundleSignatureKey)
        let hasCompletedFirstLaunch = UserDefaults.standard.bool(forKey: firstLaunchKey)
        
        // Trigger if brand-new install OR if the app bundle was reinstalled / replaced
        let isReinstallOrNew = !hasCompletedFirstLaunch || storedSignature != currentSignature
        
        if isReinstallOrNew {
            UserDefaults.standard.set(true, forKey: firstLaunchKey)
            UserDefaults.standard.set(currentSignature, forKey: bundleSignatureKey)
            
            // Automatically register to start at login
            _ = setLaunchAtLogin(enabled: true)
            
            // Show the welcome onboarding window on first launch or reinstall
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                WelcomeWindowController.shared.show()
            }
        }
    }
}
