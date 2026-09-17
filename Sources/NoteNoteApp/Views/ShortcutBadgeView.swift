import SwiftUI

/// Reusable keyboard shortcut badge pill for Spotlight HUD views
public struct ShortcutBadgeView: View {
    let key: String
    let label: String
    
    public init(key: String, label: String) {
        self.key = key
        self.label = label
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.white.opacity(0.12))
                .cornerRadius(3)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.45))
        }
    }
}
