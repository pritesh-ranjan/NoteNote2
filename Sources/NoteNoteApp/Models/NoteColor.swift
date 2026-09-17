import SwiftUI
import AppKit

public enum NoteColor: String, CaseIterable, Codable, Identifiable, Sendable {
    case yellow
    case pink
    case green
    case blue
    case purple
    case dark
    case glass
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .yellow: return "Sun Yellow"
        case .pink:   return "Pastel Rose"
        case .green:  return "Fresh Mint"
        case .blue:   return "Sky Blue"
        case .purple: return "Soft Lavender"
        case .dark:   return "Charcoal"
        case .glass:  return "Frosted Glass"
        }
    }
    
    public var backgroundColor: Color {
        switch self {
        case .yellow: return Color(red: 1.0, green: 0.95, blue: 0.72)
        case .pink:   return Color(red: 1.0, green: 0.86, blue: 0.89)
        case .green:  return Color(red: 0.84, green: 0.96, blue: 0.88)
        case .blue:   return Color(red: 0.84, green: 0.92, blue: 1.0)
        case .purple: return Color(red: 0.92, green: 0.86, blue: 1.0)
        case .dark:   return Color(red: 0.15, green: 0.16, blue: 0.18)
        case .glass:  return Color.clear
        }
    }
    
    public var nsBackgroundColor: NSColor {
        switch self {
        case .yellow: return NSColor(red: 1.0, green: 0.95, blue: 0.72, alpha: 0.97)
        case .pink:   return NSColor(red: 1.0, green: 0.86, blue: 0.89, alpha: 0.97)
        case .green:  return NSColor(red: 0.84, green: 0.96, blue: 0.88, alpha: 0.97)
        case .blue:   return NSColor(red: 0.84, green: 0.92, blue: 1.0, alpha: 0.97)
        case .purple: return NSColor(red: 0.92, green: 0.86, blue: 1.0, alpha: 0.97)
        case .dark:   return NSColor(red: 0.15, green: 0.16, blue: 0.18, alpha: 0.96)
        case .glass:  return NSColor.clear
        }
    }
    
    public var isDark: Bool {
        return self == .dark
    }
    
    public var textColor: Color {
        switch self {
        case .dark: return Color(white: 0.94)
        case .glass: return Color.primary
        default:    return Color(red: 0.12, green: 0.12, blue: 0.14)
        }
    }
    
    public var nsTextColor: NSColor {
        switch self {
        case .dark: return NSColor(white: 0.94, alpha: 1.0)
        case .glass: return NSColor.labelColor
        default:    return NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
        }
    }
    
    public var secondaryTextColor: Color {
        switch self {
        case .dark: return Color(white: 0.65)
        case .glass: return Color.secondary
        default:    return Color(red: 0.35, green: 0.35, blue: 0.40)
        }
    }
    
    public var nsSecondaryTextColor: NSColor {
        switch self {
        case .dark: return NSColor(white: 0.65, alpha: 1.0)
        case .glass: return NSColor.secondaryLabelColor
        default:    return NSColor(red: 0.35, green: 0.35, blue: 0.40, alpha: 1.0)
        }
    }
    
    public var accentColor: Color {
        switch self {
        case .yellow: return Color(red: 0.85, green: 0.70, blue: 0.0)
        case .pink:   return Color(red: 0.90, green: 0.35, blue: 0.50)
        case .green:  return Color(red: 0.20, green: 0.70, blue: 0.40)
        case .blue:   return Color(red: 0.20, green: 0.55, blue: 0.90)
        case .purple: return Color(red: 0.60, green: 0.35, blue: 0.85)
        case .dark:   return Color(red: 0.45, green: 0.65, blue: 1.0)
        case .glass:  return Color.accentColor
        }
    }
    
    public var nsAccentColor: NSColor {
        switch self {
        case .yellow: return NSColor(red: 0.85, green: 0.70, blue: 0.0, alpha: 1.0)
        case .pink:   return NSColor(red: 0.90, green: 0.35, blue: 0.50, alpha: 1.0)
        case .green:  return NSColor(red: 0.20, green: 0.70, blue: 0.40, alpha: 1.0)
        case .blue:   return NSColor(red: 0.20, green: 0.55, blue: 0.90, alpha: 1.0)
        case .purple: return NSColor(red: 0.60, green: 0.35, blue: 0.85, alpha: 1.0)
        case .dark:   return NSColor(red: 0.45, green: 0.65, blue: 1.0, alpha: 1.0)
        case .glass:  return NSColor.controlAccentColor
        }
    }
    
    public var dotColor: Color {
        switch self {
        case .yellow: return Color(red: 0.98, green: 0.82, blue: 0.20)
        case .pink:   return Color(red: 0.98, green: 0.55, blue: 0.65)
        case .green:  return Color(red: 0.35, green: 0.80, blue: 0.50)
        case .blue:   return Color(red: 0.35, green: 0.68, blue: 0.98)
        case .purple: return Color(red: 0.75, green: 0.50, blue: 0.95)
        case .dark:   return Color(red: 0.35, green: 0.38, blue: 0.45)
        case .glass:  return Color.gray.opacity(0.6)
        }
    }
    
    public var nsDotColor: NSColor {
        switch self {
        case .yellow: return NSColor(red: 0.98, green: 0.82, blue: 0.20, alpha: 1.0)
        case .pink:   return NSColor(red: 0.98, green: 0.55, blue: 0.65, alpha: 1.0)
        case .green:  return NSColor(red: 0.35, green: 0.80, blue: 0.50, alpha: 1.0)
        case .blue:   return NSColor(red: 0.35, green: 0.68, blue: 0.98, alpha: 1.0)
        case .purple: return NSColor(red: 0.75, green: 0.50, blue: 0.95, alpha: 1.0)
        case .dark:   return NSColor(red: 0.35, green: 0.38, blue: 0.45, alpha: 1.0)
        case .glass:  return NSColor(white: 0.6, alpha: 0.85)
        }
    }
}
