import SwiftUI
import AppKit

/// AppKit NSVisualEffectView wrapper providing native macOS vibrancy and blurred translucency
public struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let cornerRadius: CGFloat
    
    public init(
        material: NSVisualEffectView.Material = .popover,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        cornerRadius: CGFloat = 0
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.cornerRadius = cornerRadius
    }
    
    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        applyCornerRadius(to: view)
        return view
    }
    
    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        applyCornerRadius(to: nsView)
    }
    
    private func applyCornerRadius(to view: NSVisualEffectView) {
        if cornerRadius > 0 {
            view.wantsLayer = true
            view.layer?.cornerRadius = cornerRadius
            view.layer?.cornerCurve = .continuous
            view.layer?.masksToBounds = true
            
            let size = cornerRadius * 2 + 1
            let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
                let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
                NSColor.black.setFill()
                path.fill()
                return true
            }
            img.capInsets = NSEdgeInsets(top: cornerRadius, left: cornerRadius, bottom: cornerRadius, right: cornerRadius)
            img.resizingMode = .stretch
            view.maskImage = img
        } else {
            view.layer?.cornerRadius = 0
            view.maskImage = nil
        }
    }
}
