import AppKit
import SwiftUI

private final class QuickAddPanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
    override var canBecomeMain: Bool {
        return true
    }
}

@MainActor
public final class QuickAddWindowController {
    public static let shared = QuickAddWindowController()
    
    private var window: NSPanel?
    
    private init() {}
    
    public func show() {
        if let win = window, win.isVisible {
            win.orderOut(nil)
            return
        }
        
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let width: CGFloat = 460
        let height: CGFloat = 200
        let x = screen.visibleFrame.midX - (width / 2)
        let y = screen.visibleFrame.midY - (height / 2) + 120
        
        let panel = QuickAddPanel(
            contentRect: NSRect(x: x, y: y, width: width, height: height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        
        let hostingView = NSHostingView(rootView: QuickAddView(onDismiss: { [weak panel] in
            panel?.orderOut(nil)
        }))
        panel.contentView = hostingView
        
        self.window = panel
        panel.makeKeyAndOrderFront(nil)
        panel.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func hide() {
        window?.orderOut(nil)
    }
}
