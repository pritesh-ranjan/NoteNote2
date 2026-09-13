import AppKit
import Combine

public struct RunningAppInfo: Identifiable, Hashable {
    public var id: String { bundleIdentifier }
    public let bundleIdentifier: String
    public let localizedName: String
    public let icon: NSImage?
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
    }
    
    public static func == (lhs: RunningAppInfo, rhs: RunningAppInfo) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }
}

@MainActor
public final class AppWatcherService: ObservableObject {
    public static let shared = AppWatcherService()
    
    @Published public private(set) var activeAppBundleId: String?
    @Published public private(set) var activeAppName: String?
    @Published public private(set) var runningApps: [RunningAppInfo] = []
    
    private var observer: NSObjectProtocol?
    
    private init() {
        startObserving()
        refreshRunningApps()
    }
    
    deinit {
        if let observer = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
    
    public func startObserving() {
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            self.activeAppBundleId = frontApp.bundleIdentifier
            self.activeAppName = frontApp.localizedName
        }
        
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                guard let self = self,
                      let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                    return
                }
                self.activeAppBundleId = app.bundleIdentifier
                self.activeAppName = app.localizedName
                self.refreshRunningApps()
            }
        }
    }
    
    public func refreshRunningApps() {
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .compactMap { app -> RunningAppInfo? in
                guard let bundleId = app.bundleIdentifier,
                      let name = app.localizedName else { return nil }
                return RunningAppInfo(
                    bundleIdentifier: bundleId,
                    localizedName: name,
                    icon: app.icon
                )
            }
            .sorted { $0.localizedName.localizedCaseInsensitiveCompare($1.localizedName) == .orderedAscending }
        
        self.runningApps = apps
    }
}
