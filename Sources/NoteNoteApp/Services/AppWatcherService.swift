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
    @Published public private(set) var effectiveActiveAppBundleId: String?
    @Published public private(set) var runningApps: [RunningAppInfo] = []
    
    private var lastExternalAppBundleId: String?
    private var observers: [NSObjectProtocol] = []
    private var pollTimer: Timer?
    
    /// Transient switchers, launchers, and system overlays that should not trigger app-linking transitions
    private let transientAppBundleIds: Set<String> = [
        "com.lwouis.alt-tab-macos",
        "com.contextsformac.Contexts",
        "com.raycast.macos",
        "com.runningwithcrayons.Alfred",
        "com.apple.Spotlight",
        "com.apple.dock",
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
        "com.apple.ScreenSaver.Engine",
        "com.apple.loginwindow"
    ]
    
    private init() {
        startObserving()
        refreshRunningApps()
    }
    
    deinit {
        for obs in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            NotificationCenter.default.removeObserver(obs)
        }
        pollTimer?.invalidate()
    }
    
    public func stopObserving() {
        for obs in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            NotificationCenter.default.removeObserver(obs)
        }
        observers.removeAll()
        pollTimer?.invalidate()
        pollTimer = nil
    }
    
    public func startObserving() {
        stopObserving()
        
        // Initial state from frontmost application
        updateActiveApp(from: NSWorkspace.shared.frontmostApplication)
        
        let wsCenter = NSWorkspace.shared.notificationCenter
        
        // 1. Did Activate Application
        observers.append(wsCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                self.updateActiveApp(from: app)
            }
        })
        
        // 2. Did Deactivate Application
        observers.append(wsCenter.addObserver(
            forName: NSWorkspace.didDeactivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                self.updateActiveApp(from: NSWorkspace.shared.frontmostApplication)
            }
        })
        
        // 3. Did Hide Application
        observers.append(wsCenter.addObserver(
            forName: NSWorkspace.didHideApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                self.updateActiveApp(from: NSWorkspace.shared.frontmostApplication)
            }
        })
        
        // 4. Did Unhide Application
        observers.append(wsCenter.addObserver(
            forName: NSWorkspace.didUnhideApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                self.updateActiveApp(from: NSWorkspace.shared.frontmostApplication)
            }
        })
        
        // 5. Active Space (Virtual Desktop / Fullscreen) Changed
        observers.append(wsCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                // On space change, allow a brief delay for WindowServer to establish new front app
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                    self?.updateActiveApp(from: NSWorkspace.shared.frontmostApplication)
                }
            }
        })
        
        // 6. NoteNote App Activation / Resignation
        let appCenter = NotificationCenter.default
        observers.append(appCenter.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                self.updateActiveApp(from: NSWorkspace.shared.frontmostApplication)
            }
        })
        
        // 7. Polling Fallback (every 0.25s) to guarantee instantaneous recovery even if a notification was missed
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                let front = NSWorkspace.shared.frontmostApplication
                if let frontId = front?.bundleIdentifier, frontId != self.activeAppBundleId {
                    self.updateActiveApp(from: front)
                }
            }
        }
    }
    
    public func updateActiveApp(from app: NSRunningApplication? = nil) {
        let frontApp = app ?? NSWorkspace.shared.frontmostApplication
        guard let frontApp = frontApp,
              let bundleId = frontApp.bundleIdentifier,
              !bundleId.isEmpty else {
            return
        }
        
        // Ignore transient overlay/switcher tools (AltTab, Spotlight, Raycast)
        if transientAppBundleIds.contains(bundleId) {
            return
        }
        
        let myBundleId = Bundle.main.bundleIdentifier ?? NSRunningApplication.current.bundleIdentifier
        let isMe = (bundleId == myBundleId || bundleId == "com.priteshranjan.NoteNote")
        
        if isMe {
            self.activeAppBundleId = bundleId
            self.activeAppName = "NoteNote"
            // NoteNote itself is active: keep lastExternalAppBundleId as effective
            // so notes linked to the active workflow app remain visible!
            return
        }
        
        let name = frontApp.localizedName ?? bundleId
        let changed = (self.effectiveActiveAppBundleId != bundleId)
        
        self.activeAppBundleId = bundleId
        self.activeAppName = name
        self.lastExternalAppBundleId = bundleId
        self.effectiveActiveAppBundleId = bundleId
        
        if changed {
            refreshRunningApps()
        }
    }
    
    public func refreshRunningApps() {
        var seenBundleIds = Set<String>()
        let myBundleId = Bundle.main.bundleIdentifier ?? NSRunningApplication.current.bundleIdentifier
        let myPid = ProcessInfo.processInfo.processIdentifier
        
        let apps = NSWorkspace.shared.runningApplications
            .filter { app in
                guard app.activationPolicy == .regular,
                      let bundleId = app.bundleIdentifier,
                      !bundleId.isEmpty,
                      bundleId != myBundleId,
                      app.processIdentifier != myPid else {
                    return false
                }
                return seenBundleIds.insert(bundleId).inserted
            }
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
