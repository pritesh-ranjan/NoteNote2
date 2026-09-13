import AppKit
import SwiftUI

@MainActor
public final class WelcomeWindowController {
    public static let shared = WelcomeWindowController()
    
    private var window: NSWindow?
    
    private init() {}
    
    public func show() {
        if let win = window, win.isVisible {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.center()
        win.title = "Welcome to NoteNote"
        win.isReleasedWhenClosed = false
        
        let welcomeView = WelcomeView(onClose: { [weak self] in
            self?.close()
        })
        win.contentView = NSHostingView(rootView: welcomeView)
        
        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func close() {
        window?.orderOut(nil)
        StickyWindowManager.shared.bringAllToFront()
    }
}
