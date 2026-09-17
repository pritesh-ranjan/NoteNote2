import SwiftUI

/// A circular swatch that visually represents the actual note theme/color,
/// including its true background, graph paper grid, dotted matrix, or signature accents.
public struct NoteColorSwatchView: View {
    public let color: NoteColor
    public let size: CGFloat
    public let isSelected: Bool
    
    public init(color: NoteColor, size: CGFloat = 20, isSelected: Bool = false) {
        self.color = color
        self.size = size
        self.isSelected = isSelected
    }
    
    public var body: some View {
        ZStack {
            // Circle base with actual theme background
            Circle()
                .fill(color == .glass ? Color.white.opacity(0.18) : color.backgroundColor)
                .frame(width: size, height: size)
            
            // Miniature representation of the actual theme details
            switch color {
            case .glass:
                // Frosted glass appearance with diagonal light reflection
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.8), Color.white.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: size, height: size)
                
            case .gundam:
                // Technical blue graph-paper grid on white paper
                MiniGrid(lineColor: Color(red: 0.76, green: 0.84, blue: 0.94), spacing: size / 3.5)
                    .clipShape(Circle())
                
            case .tokyoDrift:
                // Dark asphalt with subtle dark grid
                MiniGrid(lineColor: Color(white: 0.22), spacing: size / 3.5)
                    .clipShape(Circle())
                
            case .vendetta:
                // Pitch black with subtle matrix dots
                MiniDots(dotColor: Color(white: 0.35), spacing: size / 3.5, radius: 0.8)
                    .clipShape(Circle())
                
            case .piccolo:
                // Crisp off-white paper with vibrant lime green dashed margin guide on left
                MiniMarginGuide(lineColor: Color(red: 0.16, green: 0.75, blue: 0.45), xOffset: size * 0.28)
                    .clipShape(Circle())
                
            case .a24:
                // Deep obsidian jade black with sage matrix dots
                MiniDots(dotColor: Color(red: 0.22, green: 0.34, blue: 0.26), spacing: size / 3.5, radius: 0.8)
                    .clipShape(Circle())
                
            case .brave:
                // Warm parchment ivory with warm graph paper grid
                MiniGrid(lineColor: Color(red: 0.84, green: 0.79, blue: 0.71), spacing: size / 3.5)
                    .clipShape(Circle())
                
            case .agrabah:
                // Midnight navy with glowing purple grid
                MiniGrid(lineColor: Color(red: 0.26, green: 0.24, blue: 0.52), spacing: size / 3.5)
                    .clipShape(Circle())
                
            case .mononoke:
                // Charcoal slate with vertical vermillion war-paint stripe on right border
                MiniRightStripe(color: Color(red: 0.94, green: 0.32, blue: 0.32), width: size * 0.16)
                    .clipShape(Circle())
                
            default:
                // Classic sticky note colors: clean pure pastel color
                EmptyView()
            }
            
            // Outer circular border for contrast
            Circle()
                .strokeBorder(Color.black.opacity(color.isDark ? 0.35 : 0.18), lineWidth: 0.8)
                .frame(width: size, height: size)
            
            // Selection indicator ring (outer halo, keeps mini pattern completely visible)
            if isSelected {
                Circle()
                    .stroke(Color.accentColor, lineWidth: 2)
                    .frame(width: size + 5, height: size + 5)
            }
        }
        .frame(width: size + 6, height: size + 6)
    }
}

// MARK: - Mini Canvas Drawings
private struct MiniGrid: View {
    let lineColor: Color
    let spacing: CGFloat
    
    var body: some View {
        Canvas { context, size in
            var path = Path()
            var x = spacing
            while x < size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            var y = spacing
            while y < size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            context.stroke(path, with: .color(lineColor), lineWidth: 0.6)
        }
    }
}

private struct MiniDots: View {
    let dotColor: Color
    let spacing: CGFloat
    let radius: CGFloat
    
    var body: some View {
        Canvas { context, size in
            var x = spacing
            while x < size.width {
                var y = spacing
                while y < size.height {
                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                    y += spacing
                }
                x += spacing
            }
        }
    }
}

private struct MiniMarginGuide: View {
    let lineColor: Color
    let xOffset: CGFloat
    
    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: xOffset, y: 0))
            path.addLine(to: CGPoint(x: xOffset, y: size.height))
            context.stroke(
                path,
                with: .color(lineColor),
                style: StrokeStyle(lineWidth: 1.0, dash: [2.5, 2.0])
            )
        }
    }
}

private struct MiniRightStripe: View {
    let color: Color
    let width: CGFloat
    
    var body: some View {
        Canvas { context, size in
            let rect = CGRect(x: size.width - width, y: 0, width: width, height: size.height)
            context.fill(Path(rect), with: .color(color))
        }
    }
}
