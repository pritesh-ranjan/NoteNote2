import SwiftUI
import AppKit

public struct WindowDragArea<Content: View>: View {
    let content: Content
    
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    public var body: some View {
        ZStack {
            WindowDragViewRepresentable()
                .frame(height: 32)
            content
        }
        .frame(height: 32)
    }
}

private struct WindowDragViewRepresentable: NSViewRepresentable {
    func makeNSView(context: Context) -> DragNSView {
        let view = DragNSView()
        return view
    }
    
    func updateNSView(_ nsView: DragNSView, context: Context) {}
}

private class DragNSView: NSView {
    override var mouseDownCanMoveWindow: Bool {
        return true
    }
    
    override func mouseDown(with event: NSEvent) {
        guard let window = self.window else { return }
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        
        let originalLevel = window.level
        if window.level < .floating {
            window.level = .floating
        }
        window.orderFrontRegardless()
        
        window.performDrag(with: event)
        
        window.level = originalLevel
        window.orderFrontRegardless()
    }
}
