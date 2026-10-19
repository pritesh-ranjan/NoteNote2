import Foundation

public struct AppSettings: Codable {
    public var defaultColor: NoteColor
    public var defaultHideFromScreenCapture: Bool
    public var defaultPinned: Bool
    public var showInDock: Bool
    public var playSounds: Bool
    public var defaultDockEdge: DockEdge
    public var autoCheckForUpdates: Bool
    public var autoInstallUpdates: Bool
    public var lastUpdateCheckDate: Date?
    public var ignoredUpdateVersion: String?
    public var wifiSyncEnabled: Bool
    public var wifiSyncPort: UInt16
    
    public init(
        defaultColor: NoteColor = .yellow,
        defaultHideFromScreenCapture: Bool = false,
        defaultPinned: Bool = false,
        showInDock: Bool = false,
        playSounds: Bool = true,
        defaultDockEdge: DockEdge = .right,
        autoCheckForUpdates: Bool = true,
        autoInstallUpdates: Bool = false,
        lastUpdateCheckDate: Date? = nil,
        ignoredUpdateVersion: String? = nil,
        wifiSyncEnabled: Bool = false,
        wifiSyncPort: UInt16 = 52849
    ) {
        self.defaultColor = defaultColor
        self.defaultHideFromScreenCapture = defaultHideFromScreenCapture
        self.defaultPinned = defaultPinned
        self.showInDock = showInDock
        self.playSounds = playSounds
        self.defaultDockEdge = defaultDockEdge
        self.autoCheckForUpdates = autoCheckForUpdates
        self.autoInstallUpdates = autoInstallUpdates
        self.lastUpdateCheckDate = lastUpdateCheckDate
        self.ignoredUpdateVersion = ignoredUpdateVersion
        self.wifiSyncEnabled = wifiSyncEnabled
        self.wifiSyncPort = wifiSyncPort
    }
    
    enum CodingKeys: String, CodingKey {
        case defaultColor, defaultHideFromScreenCapture, defaultPinned
        case showInDock, playSounds, defaultDockEdge
        case autoCheckForUpdates, autoInstallUpdates, lastUpdateCheckDate, ignoredUpdateVersion
        case wifiSyncEnabled, wifiSyncPort
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.defaultColor = try container.decodeIfPresent(NoteColor.self, forKey: .defaultColor) ?? .yellow
        self.defaultHideFromScreenCapture = try container.decodeIfPresent(Bool.self, forKey: .defaultHideFromScreenCapture) ?? false
        self.defaultPinned = try container.decodeIfPresent(Bool.self, forKey: .defaultPinned) ?? false
        self.showInDock = try container.decodeIfPresent(Bool.self, forKey: .showInDock) ?? false
        self.playSounds = try container.decodeIfPresent(Bool.self, forKey: .playSounds) ?? true
        self.defaultDockEdge = try container.decodeIfPresent(DockEdge.self, forKey: .defaultDockEdge) ?? .right
        self.autoCheckForUpdates = try container.decodeIfPresent(Bool.self, forKey: .autoCheckForUpdates) ?? true
        self.autoInstallUpdates = try container.decodeIfPresent(Bool.self, forKey: .autoInstallUpdates) ?? false
        self.lastUpdateCheckDate = try container.decodeIfPresent(Date.self, forKey: .lastUpdateCheckDate)
        self.ignoredUpdateVersion = try container.decodeIfPresent(String.self, forKey: .ignoredUpdateVersion)
        self.wifiSyncEnabled = try container.decodeIfPresent(Bool.self, forKey: .wifiSyncEnabled) ?? false
        self.wifiSyncPort = try container.decodeIfPresent(UInt16.self, forKey: .wifiSyncPort) ?? 52849
    }
    
    public static let `default` = AppSettings(
        defaultColor: .yellow,
        defaultHideFromScreenCapture: false,
        defaultPinned: false,
        showInDock: false,
        playSounds: true,
        defaultDockEdge: .right,
        autoCheckForUpdates: true,
        autoInstallUpdates: false,
        lastUpdateCheckDate: nil,
        ignoredUpdateVersion: nil,
        wifiSyncEnabled: false,
        wifiSyncPort: 52849
    )
}
