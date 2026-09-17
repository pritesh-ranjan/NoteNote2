import AppKit
import SwiftUI

@MainActor
public final class SettingsWindowController {
    public static let shared = SettingsWindowController()
    
    private var window: NSWindow?
    
    private init() {}
    
    public func show(tab: Int = 0, scrollToGestures: Bool = false) {
        if let win = window, win.isVisible {
            win.contentView = NSHostingView(rootView: SettingsView(selectedTab: tab, scrollToGestures: scrollToGestures))
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 580),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.minSize = NSSize(width: 480, height: 480)
        win.center()
        win.title = "NoteNote Preferences"
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.isMovableByWindowBackground = true
        win.backgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)
        win.isReleasedWhenClosed = false
        win.contentView = NSHostingView(rootView: SettingsView(selectedTab: tab, scrollToGestures: scrollToGestures))
        
        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
