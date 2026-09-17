import AppKit
import SwiftUI

@MainActor
public final class SearchNotesWindowController {
    public static let shared = SearchNotesWindowController()
    
    private var window: SpotlightHUDPanel?
    
    private init() {}
    
    public func presentSearch() {
        if let win = window, win.isVisible {
            win.makeKeyAndOrderFront(nil)
            win.makeKey()
            return
        }
        show()
    }
    
    public func show() {
        if let win = window, win.isVisible {
            win.dismiss()
            return
        }
        
        let height: CGFloat = 380
        let frame = SpotlightHUDPanel.standardFrame(height: height)
        
        let panel = SpotlightHUDPanel(contentRect: frame)
        
        let hostingView = NSHostingView(rootView: SearchNotesView(onDismiss: { [weak panel] in
            panel?.dismiss()
        }))
        panel.contentView = hostingView
        panel.onDismiss = { [weak self] in
            self?.window = nil
        }
        
        self.window = panel
        panel.present()
    }
    
    public func hide() {
        window?.dismiss()
    }
}
