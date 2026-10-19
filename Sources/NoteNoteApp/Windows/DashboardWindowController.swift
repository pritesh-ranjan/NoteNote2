import AppKit
import SwiftUI

@MainActor
public final class DashboardWindowController {
    public static let shared = DashboardWindowController()
    
    private var window: NSWindow?
    
    private init() {}
    
    public func show() {
        if let win = window, win.isVisible {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 580),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.minSize = NSSize(width: 640, height: 440)
        win.center()
        win.title = "Notes Dashboard"
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.isMovableByWindowBackground = true
        win.isReleasedWhenClosed = false
        win.backgroundColor = NSColor(red: 0.12, green: 0.125, blue: 0.14, alpha: 1.0)
        win.contentView = NSHostingView(rootView: DashboardView())
        
        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func close() {
        window?.close()
    }
}
