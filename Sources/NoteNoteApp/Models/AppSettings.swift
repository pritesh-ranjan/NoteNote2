import AppKit
import Carbon.HIToolbox
import Foundation

public enum TypingSpeed: String, Codable, CaseIterable, Identifiable, Sendable {
    case fast
    case normal
    case slow

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .fast: return "Fast"
        case .normal: return "Normal"
        case .slow: return "Slow (VM / Remote)"
        }
    }

    public var interKeyDelayNs: UInt64 {
        switch self {
        case .fast: return 5_000_000
        case .normal: return 15_000_000
        case .slow: return 40_000_000
        }
    }

    public var keyHoldUs: useconds_t {
        switch self {
        case .fast: return 1_500
        case .normal: return 3_000
        case .slow: return 8_000
        }
    }

    public var specialKeyDelayNs: UInt64 {
        max(interKeyDelayNs * 2, 20_000_000)
    }
}

public struct KeyShortcut: Codable, Equatable, Hashable, Sendable {
    public var keyCode: UInt32
    public var carbonModifiers: UInt32

    public init(keyCode: UInt32, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
    }

    public static let defaultTypeClipboard = KeyShortcut(
        keyCode: UInt32(kVK_ANSI_V),
        carbonModifiers: UInt32(controlKey | shiftKey)
    )

    public static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mask: UInt32 = 0
        if flags.contains(.control) { mask |= UInt32(controlKey) }
        if flags.contains(.option) { mask |= UInt32(optionKey) }
        if flags.contains(.shift) { mask |= UInt32(shiftKey) }
        if flags.contains(.command) { mask |= UInt32(cmdKey) }
        return mask
    }

    public static func hasPrimaryModifier(_ carbonModifiers: UInt32) -> Bool {
        (carbonModifiers & UInt32(cmdKey | optionKey | controlKey)) != 0
    }

    public var displayTokens: [String] {
        var tokens: [String] = []
        if (carbonModifiers & UInt32(controlKey)) != 0 { tokens.append("⌃") }
        if (carbonModifiers & UInt32(optionKey)) != 0 { tokens.append("⌥") }
        if (carbonModifiers & UInt32(shiftKey)) != 0 { tokens.append("⇧") }
        if (carbonModifiers & UInt32(cmdKey)) != 0 { tokens.append("⌘") }
        tokens.append(Self.keyDisplayName(for: keyCode))
        return tokens
    }

    public var displayString: String {
        displayTokens.joined()
    }

    private static func keyDisplayName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_Equal: return "="
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_Backslash: return "\\"
        case kVK_ANSI_Semicolon: return ";"
        case kVK_ANSI_Quote: return "'"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Slash: return "/"
        case kVK_ANSI_Grave: return "`"
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_F13: return "F13"
        case kVK_F14: return "F14"
        case kVK_F15: return "F15"
        case kVK_F16: return "F16"
        case kVK_F17: return "F17"
        case kVK_F18: return "F18"
        case kVK_F19: return "F19"
        case kVK_F20: return "F20"
        default: return "Key(\(keyCode))"
        }
    }
}

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
    public var typeClipboardEnabled: Bool
    public var typeClipboardShortcut: KeyShortcut
    public var typeClipboardSpeed: TypingSpeed
    
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
        typeClipboardEnabled: Bool = true,
        typeClipboardShortcut: KeyShortcut = .defaultTypeClipboard,
        typeClipboardSpeed: TypingSpeed = .normal
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
        self.typeClipboardEnabled = typeClipboardEnabled
        self.typeClipboardShortcut = typeClipboardShortcut
        self.typeClipboardSpeed = typeClipboardSpeed
    }
    
    enum CodingKeys: String, CodingKey {
        case defaultColor, defaultHideFromScreenCapture, defaultPinned
        case showInDock, playSounds, defaultDockEdge
        case autoCheckForUpdates, autoInstallUpdates, lastUpdateCheckDate, ignoredUpdateVersion
        case typeClipboardEnabled, typeClipboardShortcut, typeClipboardSpeed
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
        self.typeClipboardEnabled = try container.decodeIfPresent(Bool.self, forKey: .typeClipboardEnabled) ?? true
        self.typeClipboardShortcut = try container.decodeIfPresent(KeyShortcut.self, forKey: .typeClipboardShortcut) ?? .defaultTypeClipboard
        self.typeClipboardSpeed = try container.decodeIfPresent(TypingSpeed.self, forKey: .typeClipboardSpeed) ?? .normal
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
        typeClipboardEnabled: true,
        typeClipboardShortcut: .defaultTypeClipboard,
        typeClipboardSpeed: .normal
    )
}
