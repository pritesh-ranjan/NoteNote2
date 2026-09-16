import Foundation

public struct AppSettings: Codable {
    public var defaultColor: NoteColor
    public var defaultHideFromScreenCapture: Bool
    public var defaultPinned: Bool
    public var showInDock: Bool
    public var playSounds: Bool
    public var defaultDockEdge: DockEdge
    public var quickAddGlobalShortcut: String
    public var toggleStickiesGlobalShortcut: String
    
    public init(
        defaultColor: NoteColor = .yellow,
        defaultHideFromScreenCapture: Bool = false,
        defaultPinned: Bool = false,
        showInDock: Bool = false,
        playSounds: Bool = true,
        defaultDockEdge: DockEdge = .right,
        quickAddGlobalShortcut: String = "⌘⇧N",
        toggleStickiesGlobalShortcut: String = "⌘⇧H"
    ) {
        self.defaultColor = defaultColor
        self.defaultHideFromScreenCapture = defaultHideFromScreenCapture
        self.defaultPinned = defaultPinned
        self.showInDock = showInDock
        self.playSounds = playSounds
        self.defaultDockEdge = defaultDockEdge
        self.quickAddGlobalShortcut = quickAddGlobalShortcut
        self.toggleStickiesGlobalShortcut = toggleStickiesGlobalShortcut
    }
    
    enum CodingKeys: String, CodingKey {
        case defaultColor, defaultHideFromScreenCapture, defaultPinned
        case showInDock, playSounds, defaultDockEdge
        case quickAddGlobalShortcut, toggleStickiesGlobalShortcut
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.defaultColor = try container.decodeIfPresent(NoteColor.self, forKey: .defaultColor) ?? .yellow
        self.defaultHideFromScreenCapture = try container.decodeIfPresent(Bool.self, forKey: .defaultHideFromScreenCapture) ?? false
        self.defaultPinned = try container.decodeIfPresent(Bool.self, forKey: .defaultPinned) ?? false
        self.showInDock = try container.decodeIfPresent(Bool.self, forKey: .showInDock) ?? false
        self.playSounds = try container.decodeIfPresent(Bool.self, forKey: .playSounds) ?? true
        self.defaultDockEdge = try container.decodeIfPresent(DockEdge.self, forKey: .defaultDockEdge) ?? .right
        self.quickAddGlobalShortcut = try container.decodeIfPresent(String.self, forKey: .quickAddGlobalShortcut) ?? "⌘⇧N"
        self.toggleStickiesGlobalShortcut = try container.decodeIfPresent(String.self, forKey: .toggleStickiesGlobalShortcut) ?? "⌘⇧H"
    }
    
    public static let `default` = AppSettings(
        defaultColor: .yellow,
        defaultHideFromScreenCapture: false,
        defaultPinned: false,
        showInDock: false,
        playSounds: true,
        defaultDockEdge: .right,
        quickAddGlobalShortcut: "⌘⇧N",
        toggleStickiesGlobalShortcut: "⌘⇧H"
    )
}
