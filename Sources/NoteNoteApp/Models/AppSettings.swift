import Foundation

public struct AppSettings: Codable {
    public var defaultColor: NoteColor
    public var defaultHideFromScreenCapture: Bool
    public var showInDock: Bool
    public var playSounds: Bool
    public var defaultDockEdge: DockEdge
    public var quickAddGlobalShortcut: String
    public var toggleStickiesGlobalShortcut: String
    
    public static let `default` = AppSettings(
        defaultColor: .yellow,
        defaultHideFromScreenCapture: false,
        showInDock: false,
        playSounds: true,
        defaultDockEdge: .right,
        quickAddGlobalShortcut: "⌘⇧N",
        toggleStickiesGlobalShortcut: "⌘⇧H"
    )
}
