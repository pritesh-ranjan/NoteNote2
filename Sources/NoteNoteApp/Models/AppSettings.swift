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
        ignoredUpdateVersion: String? = nil
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
    }
    
    enum CodingKeys: String, CodingKey {
        case defaultColor, defaultHideFromScreenCapture, defaultPinned
        case showInDock, playSounds, defaultDockEdge
        case autoCheckForUpdates, autoInstallUpdates, lastUpdateCheckDate, ignoredUpdateVersion
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
        ignoredUpdateVersion: nil
    )
}
