import SwiftUI

public struct PaperPatternView: View {
    let pattern: PaperPattern
    
    public init(pattern: PaperPattern) {
        self.pattern = pattern
    }
    
    public var body: some View {
        Group {
            switch pattern {
            case .none:
                EmptyView()
                
            case .grid(let color, let spacing):
                Canvas { context, size in
                    var path = Path()
                    
                    // Vertical lines
                    var x = spacing
                    while x < size.width {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        x += spacing
                    }
                    
                    // Horizontal lines
                    var y = spacing
                    while y < size.height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        y += spacing
                    }
                    
                    context.stroke(path, with: .color(color), lineWidth: 0.8)
                }
                .allowsHitTesting(false)
                
            case .dots(let color, let spacing, let radius):
                Canvas { context, size in
                    var x = spacing
                    while x < size.width {
                        var y = spacing
                        while y < size.height {
                            let dotRect = CGRect(
                                x: x - radius,
                                y: y - radius,
                                width: radius * 2,
                                height: radius * 2
                            )
                            context.fill(Path(ellipseIn: dotRect), with: .color(color))
                            y += spacing
                        }
                        x += spacing
                    }
                }
                .allowsHitTesting(false)
                
            case .marginGuide(let color, let x):
                Canvas { context, size in
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(
                        path,
                        with: .color(color),
                        style: StrokeStyle(lineWidth: 1.2, dash: [4, 3])
                    )
                }
                .allowsHitTesting(false)
                
            case .rightStripe(let color, let width):
                Canvas { context, size in
                    let stripeRect = CGRect(x: size.width - width, y: 0, width: width, height: size.height)
                    context.fill(Path(stripeRect), with: .color(color))
                }
                .allowsHitTesting(false)
            }
        }
    }
}
