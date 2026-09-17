import Foundation
import ServiceManagement
import Combine

@MainActor
public final class StartupService: ObservableObject {
    public static let shared = StartupService()
    
    private let firstLaunchKey = "NoteNote_FirstLaunchCompleted"
    
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
        let hasCompletedFirstLaunch = UserDefaults.standard.bool(forKey: firstLaunchKey)
        
        if !hasCompletedFirstLaunch {
            UserDefaults.standard.set(true, forKey: firstLaunchKey)
            
            // Automatically register to start at login
            _ = setLaunchAtLogin(enabled: true)
            
            // Show the welcome onboarding window on first launch
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                WelcomeWindowController.shared.show()
            }
        }
    }
}
