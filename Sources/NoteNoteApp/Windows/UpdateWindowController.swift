import AppKit
import SwiftUI

@MainActor
public final class UpdateWindowController {
    public static let shared = UpdateWindowController()
    
    private var window: NSWindow?
    
    private init() {}
    
    public func show(release: GitHubRelease) {
        if let win = window, win.isVisible {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.center()
        win.title = "Software Update — NoteNote"
        win.isReleasedWhenClosed = false
        win.level = .floating
        
        let updateView = UpdateView(release: release, onClose: { [weak self] in
            self?.close()
        })
        win.contentView = NSHostingView(rootView: updateView)
        
        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func close() {
        window?.orderOut(nil)
        window = nil
    }
}
