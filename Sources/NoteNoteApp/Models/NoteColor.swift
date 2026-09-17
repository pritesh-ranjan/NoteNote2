import SwiftUI
import AppKit

public enum NoteFontDesign: Sendable {
    case standard
    case monospaced
    case serif
}

public enum PaperPattern: Equatable, Sendable {
    case none
    case grid(color: Color, spacing: CGFloat = 20)
    case dots(color: Color, spacing: CGFloat = 18, radius: CGFloat = 1.1)
    case marginGuide(color: Color, x: CGFloat = 26)
    case rightStripe(color: Color, width: CGFloat = 3.5)
}

public enum NoteColor: String, CaseIterable, Codable, Identifiable, Sendable {
    // Classic Sticky Colors (Used for randomized creation)
    case yellow
    case pink
    case green
    case blue
    case purple
    case dark
    case glass
    
    // Antinote Inspired Themes
    case mononoke
    case gundam
    case tokyoDrift
    case vendetta
    case piccolo
    case a24
    case brave
    case agrabah
    
    public var id: String { rawValue }
    
    // MARK: - Classification
    public static let classicCases: [NoteColor] = [
        .yellow, .pink, .green, .blue, .purple, .dark, .glass
    ]
    
    public static let themeCases: [NoteColor] = [
        .mononoke, .gundam, .tokyoDrift, .vendetta, .piccolo, .a24, .brave, .agrabah
    ]
    
    /// Randomized choosing on note creation strictly uses the 7 classic colors
    public static var randomCases: [NoteColor] {
        classicCases
    }
    
    public var isAntinoteTheme: Bool {
        Self.themeCases.contains(self)
    }
    
    public var displayName: String {
        switch self {
        case .yellow:     return "Sun Yellow"
        case .pink:       return "Pastel Rose"
        case .green:      return "Fresh Mint"
        case .blue:       return "Sky Blue"
        case .purple:     return "Soft Lavender"
        case .dark:       return "Charcoal"
        case .glass:      return "Frosted Glass"
        case .mononoke:   return "Mononoke"
        case .gundam:     return "Gundam"
        case .tokyoDrift: return "Tokyo Drift"
        case .vendetta:   return "Vendetta"
        case .piccolo:    return "Piccolo"
        case .a24:        return "A24"
        case .brave:      return "Brave"
        case .agrabah:    return "Agrabah"
        }
    }
    
    public var backgroundColor: Color {
        switch self {
        case .yellow:     return Color(red: 1.0, green: 0.95, blue: 0.72)
        case .pink:       return Color(red: 1.0, green: 0.86, blue: 0.89)
        case .green:      return Color(red: 0.84, green: 0.96, blue: 0.88)
        case .blue:       return Color(red: 0.84, green: 0.92, blue: 1.0)
        case .purple:     return Color(red: 0.92, green: 0.86, blue: 1.0)
        case .dark:       return Color(red: 0.15, green: 0.16, blue: 0.18)
        case .glass:      return Color.clear
        case .mononoke:   return Color(red: 0.10, green: 0.11, blue: 0.12)
        case .gundam:     return Color(red: 0.97, green: 0.98, blue: 0.99)
        case .tokyoDrift: return Color(red: 0.08, green: 0.085, blue: 0.10)
        case .vendetta:   return Color(red: 0.065, green: 0.07, blue: 0.08)
        case .piccolo:    return Color(red: 0.965, green: 0.99, blue: 0.97)
        case .a24:        return Color(red: 0.05, green: 0.08, blue: 0.06)
        case .brave:      return Color(red: 0.98, green: 0.965, blue: 0.93)
        case .agrabah:    return Color(red: 0.05, green: 0.06, blue: 0.13)
        }
    }
    
    public var nsBackgroundColor: NSColor {
        switch self {
        case .yellow:     return NSColor(red: 1.0, green: 0.95, blue: 0.72, alpha: 0.97)
        case .pink:       return NSColor(red: 1.0, green: 0.86, blue: 0.89, alpha: 0.97)
        case .green:      return NSColor(red: 0.84, green: 0.96, blue: 0.88, alpha: 0.97)
        case .blue:       return NSColor(red: 0.84, green: 0.92, blue: 1.0, alpha: 0.97)
        case .purple:     return NSColor(red: 0.92, green: 0.86, blue: 1.0, alpha: 0.97)
        case .dark:       return NSColor(red: 0.15, green: 0.16, blue: 0.18, alpha: 0.96)
        case .glass:      return NSColor.clear
        case .mononoke:   return NSColor(red: 0.10, green: 0.11, blue: 0.12, alpha: 0.98)
        case .gundam:     return NSColor(red: 0.97, green: 0.98, blue: 0.99, alpha: 0.98)
        case .tokyoDrift: return NSColor(red: 0.08, green: 0.085, blue: 0.10, alpha: 0.98)
        case .vendetta:   return NSColor(red: 0.065, green: 0.07, blue: 0.08, alpha: 0.98)
        case .piccolo:    return NSColor(red: 0.965, green: 0.99, blue: 0.97, alpha: 0.98)
        case .a24:        return NSColor(red: 0.05, green: 0.08, blue: 0.06, alpha: 0.98)
        case .brave:      return NSColor(red: 0.98, green: 0.965, blue: 0.93, alpha: 0.98)
        case .agrabah:    return NSColor(red: 0.05, green: 0.06, blue: 0.13, alpha: 0.98)
        }
    }
    
    public var isDark: Bool {
        switch self {
        case .dark, .mononoke, .tokyoDrift, .vendetta, .a24, .agrabah:
            return true
        default:
            return false
        }
    }
    
    public var textColor: Color {
        switch self {
        case .dark, .mononoke, .tokyoDrift, .vendetta, .a24, .agrabah:
            return Color(white: 0.94)
        case .glass:
            return Color.primary
        case .brave:
            return Color(red: 0.18, green: 0.14, blue: 0.12)
        case .piccolo:
            return Color(red: 0.08, green: 0.18, blue: 0.12)
        case .gundam:
            return Color(red: 0.10, green: 0.15, blue: 0.22)
        default:
            return Color(red: 0.12, green: 0.12, blue: 0.14)
        }
    }
    
    public var nsTextColor: NSColor {
        switch self {
        case .dark, .mononoke, .tokyoDrift, .vendetta, .a24, .agrabah:
            return NSColor(white: 0.94, alpha: 1.0)
        case .glass:
            return NSColor.labelColor
        case .brave:
            return NSColor(red: 0.18, green: 0.14, blue: 0.12, alpha: 1.0)
        case .piccolo:
            return NSColor(red: 0.08, green: 0.18, blue: 0.12, alpha: 1.0)
        case .gundam:
            return NSColor(red: 0.10, green: 0.15, blue: 0.22, alpha: 1.0)
        default:
            return NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
        }
    }
    
    public var secondaryTextColor: Color {
        switch self {
        case .dark, .mononoke, .tokyoDrift, .vendetta:
            return Color(white: 0.65)
        case .glass:
            return Color.secondary
        case .a24:
            return Color(red: 0.48, green: 0.60, blue: 0.52)
        case .agrabah:
            return Color(red: 0.55, green: 0.58, blue: 0.85)
        case .piccolo:
            return Color(red: 0.28, green: 0.48, blue: 0.35)
        case .brave:
            return Color(red: 0.45, green: 0.38, blue: 0.34)
        case .gundam:
            return Color(red: 0.35, green: 0.45, blue: 0.55)
        default:
            return Color(red: 0.35, green: 0.35, blue: 0.40)
        }
    }
    
    public var nsSecondaryTextColor: NSColor {
        switch self {
        case .dark, .mononoke, .tokyoDrift, .vendetta:
            return NSColor(white: 0.65, alpha: 1.0)
        case .glass:
            return NSColor.secondaryLabelColor
        case .a24:
            return NSColor(red: 0.48, green: 0.60, blue: 0.52, alpha: 1.0)
        case .agrabah:
            return NSColor(red: 0.55, green: 0.58, blue: 0.85, alpha: 1.0)
        case .piccolo:
            return NSColor(red: 0.28, green: 0.48, blue: 0.35, alpha: 1.0)
        case .brave:
            return NSColor(red: 0.45, green: 0.38, blue: 0.34, alpha: 1.0)
        case .gundam:
            return NSColor(red: 0.35, green: 0.45, blue: 0.55, alpha: 1.0)
        default:
            return NSColor(red: 0.35, green: 0.35, blue: 0.40, alpha: 1.0)
        }
    }
    
    public var accentColor: Color {
        switch self {
        case .yellow:     return Color(red: 0.85, green: 0.70, blue: 0.0)
        case .pink:       return Color(red: 0.90, green: 0.35, blue: 0.50)
        case .green:      return Color(red: 0.20, green: 0.70, blue: 0.40)
        case .blue:       return Color(red: 0.20, green: 0.55, blue: 0.90)
        case .purple:     return Color(red: 0.60, green: 0.35, blue: 0.85)
        case .dark:       return Color(red: 0.45, green: 0.65, blue: 1.0)
        case .glass:      return Color.accentColor
        case .mononoke:   return Color(red: 0.94, green: 0.32, blue: 0.32)
        case .gundam:     return Color(red: 0.15, green: 0.45, blue: 0.92)
        case .tokyoDrift: return Color(red: 1.0, green: 0.18, blue: 0.55)
        case .vendetta:   return Color(red: 0.88, green: 0.12, blue: 0.18)
        case .piccolo:    return Color(red: 0.48, green: 0.22, blue: 0.88)
        case .a24:        return Color(red: 0.98, green: 0.50, blue: 0.15)
        case .brave:      return Color(red: 0.90, green: 0.36, blue: 0.10)
        case .agrabah:    return Color(red: 0.98, green: 0.76, blue: 0.18)
        }
    }
    
    public var nsAccentColor: NSColor {
        switch self {
        case .yellow:     return NSColor(red: 0.85, green: 0.70, blue: 0.0, alpha: 1.0)
        case .pink:       return NSColor(red: 0.90, green: 0.35, blue: 0.50, alpha: 1.0)
        case .green:      return NSColor(red: 0.20, green: 0.70, blue: 0.40, alpha: 1.0)
        case .blue:       return NSColor(red: 0.20, green: 0.55, blue: 0.90, alpha: 1.0)
        case .purple:     return NSColor(red: 0.60, green: 0.35, blue: 0.85, alpha: 1.0)
        case .dark:       return NSColor(red: 0.45, green: 0.65, blue: 1.0, alpha: 1.0)
        case .glass:      return NSColor.controlAccentColor
        case .mononoke:   return NSColor(red: 0.94, green: 0.32, blue: 0.32, alpha: 1.0)
        case .gundam:     return NSColor(red: 0.15, green: 0.45, blue: 0.92, alpha: 1.0)
        case .tokyoDrift: return NSColor(red: 1.0, green: 0.18, blue: 0.55, alpha: 1.0)
        case .vendetta:   return NSColor(red: 0.88, green: 0.12, blue: 0.18, alpha: 1.0)
        case .piccolo:    return NSColor(red: 0.48, green: 0.22, blue: 0.88, alpha: 1.0)
        case .a24:        return NSColor(red: 0.98, green: 0.50, blue: 0.15, alpha: 1.0)
        case .brave:      return NSColor(red: 0.90, green: 0.36, blue: 0.10, alpha: 1.0)
        case .agrabah:    return NSColor(red: 0.98, green: 0.76, blue: 0.18, alpha: 1.0)
        }
    }
    
    public var dotColor: Color {
        switch self {
        case .yellow:     return Color(red: 0.98, green: 0.82, blue: 0.20)
        case .pink:       return Color(red: 0.98, green: 0.55, blue: 0.65)
        case .green:      return Color(red: 0.35, green: 0.80, blue: 0.50)
        case .blue:       return Color(red: 0.35, green: 0.68, blue: 0.98)
        case .purple:     return Color(red: 0.75, green: 0.50, blue: 0.95)
        case .dark:       return Color(red: 0.35, green: 0.38, blue: 0.45)
        case .glass:      return Color.gray.opacity(0.6)
        case .mononoke:   return Color(red: 0.94, green: 0.32, blue: 0.32)
        case .gundam:     return Color(red: 0.15, green: 0.45, blue: 0.92)
        case .tokyoDrift: return Color(red: 0.0, green: 0.90, blue: 1.0)
        case .vendetta:   return Color(red: 0.88, green: 0.12, blue: 0.18)
        case .piccolo:    return Color(red: 0.10, green: 0.72, blue: 0.45)
        case .a24:        return Color(red: 0.98, green: 0.50, blue: 0.15)
        case .brave:      return Color(red: 0.90, green: 0.36, blue: 0.10)
        case .agrabah:    return Color(red: 0.55, green: 0.58, blue: 0.88)
        }
    }
    
    public var nsDotColor: NSColor {
        switch self {
        case .yellow:     return NSColor(red: 0.98, green: 0.82, blue: 0.20, alpha: 1.0)
        case .pink:       return NSColor(red: 0.98, green: 0.55, blue: 0.65, alpha: 1.0)
        case .green:      return NSColor(red: 0.35, green: 0.80, blue: 0.50, alpha: 1.0)
        case .blue:       return NSColor(red: 0.35, green: 0.68, blue: 0.98, alpha: 1.0)
        case .purple:     return NSColor(red: 0.75, green: 0.50, blue: 0.95, alpha: 1.0)
        case .dark:       return NSColor(red: 0.35, green: 0.38, blue: 0.45, alpha: 1.0)
        case .glass:      return NSColor(white: 0.6, alpha: 0.85)
        case .mononoke:   return NSColor(red: 0.94, green: 0.32, blue: 0.32, alpha: 1.0)
        case .gundam:     return NSColor(red: 0.15, green: 0.45, blue: 0.92, alpha: 1.0)
        case .tokyoDrift: return NSColor(red: 0.0, green: 0.90, blue: 1.0, alpha: 1.0)
        case .vendetta:   return NSColor(red: 0.88, green: 0.12, blue: 0.18, alpha: 1.0)
        case .piccolo:    return NSColor(red: 0.10, green: 0.72, blue: 0.45, alpha: 1.0)
        case .a24:        return NSColor(red: 0.98, green: 0.50, blue: 0.15, alpha: 1.0)
        case .brave:      return NSColor(red: 0.90, green: 0.36, blue: 0.10, alpha: 1.0)
        case .agrabah:    return NSColor(red: 0.55, green: 0.58, blue: 0.88, alpha: 1.0)
        }
    }
    
    // MARK: - Paper Texture & Pattern
    public var paperPattern: PaperPattern {
        switch self {
        case .gundam:
            return .grid(color: Color(red: 0.80, green: 0.86, blue: 0.94).opacity(0.85), spacing: 20)
        case .tokyoDrift:
            return .grid(color: Color(white: 0.22).opacity(0.7), spacing: 20)
        case .vendetta:
            return .dots(color: Color(white: 0.30).opacity(0.7), spacing: 18, radius: 1.1)
        case .a24:
            return .dots(color: Color(red: 0.20, green: 0.32, blue: 0.24).opacity(0.75), spacing: 18, radius: 1.1)
        case .brave:
            return .grid(color: Color(red: 0.86, green: 0.82, blue: 0.74).opacity(0.85), spacing: 20)
        case .agrabah:
            return .grid(color: Color(red: 0.20, green: 0.20, blue: 0.40).opacity(0.85), spacing: 20)
        case .piccolo:
            return .marginGuide(color: Color(red: 0.16, green: 0.75, blue: 0.45).opacity(0.85), x: 26)
        case .mononoke:
            return .rightStripe(color: Color(red: 0.94, green: 0.32, blue: 0.32), width: 3.5)
        default:
            return .none
        }
    }
    
    // MARK: - Typography Design
    public var fontDesign: NoteFontDesign {
        switch self {
        case .brave:
            return .serif
        case .gundam, .tokyoDrift, .vendetta, .agrabah:
            return .monospaced
        default:
            return .standard
        }
    }
    
    // MARK: - AppKit Font Helper
    public func font(ofSize size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        switch fontDesign {
        case .monospaced:
            return NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        case .serif:
            if let descriptor = NSFont.systemFont(ofSize: size, weight: weight).fontDescriptor.withDesign(.serif),
               let font = NSFont(descriptor: descriptor, size: size) {
                return font
            }
            return NSFont(name: "Georgia", size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
        case .standard:
            return NSFont.systemFont(ofSize: size, weight: weight)
        }
    }
}
