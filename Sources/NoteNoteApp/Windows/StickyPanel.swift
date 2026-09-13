import AppKit
import SwiftUI

public final class StickyPanel: NSPanel {
    public let noteId: UUID
    private var trackingArea: NSTrackingArea?
    
    public init(noteId: UUID, contentRect: NSRect) {
        self.noteId = noteId
        
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.isMovable = true
        self.isMovableByWindowBackground = true
        self.minSize = NSSize(width: 180, height: 120)
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true
    }
    
    public override var canBecomeKey: Bool {
        return true
    }
    
    public override var canBecomeMain: Bool {
        return true
    }
    
    public func handleLockShortcut() {
        // Only post the notification; StickyNoteView handles all state transitions
        // atomically (lock, re-lock, or unlock-via-TouchID). Calling setLocked here
        // first caused a race: by the time the notification handler ran, isLocked was
        // already true, so it triggered the TouchID unlock prompt instead of locking.
        NotificationCenter.default.post(name: .toggleNoteLock, object: noteId)
    }
    
    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) && !flags.contains(.control) && !flags.contains(.option) {
            let key = event.charactersIgnoringModifiers?.lowercased()
            if key == "l" {
                handleLockShortcut()
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }
    
    public override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) && !flags.contains(.control) && !flags.contains(.option) {
            let key = event.charactersIgnoringModifiers?.lowercased()
            if key == "l" {
                handleLockShortcut()
                return
            }
        }
        super.keyDown(with: event)
    }
    
    public override func magnify(with event: NSEvent) {
        if let contentView = self.contentView, let textView = findStickyTextView(in: contentView) {
            textView.magnify(with: event)
        } else {
            super.magnify(with: event)
        }
    }
    
    private func findStickyTextView(in view: NSView) -> StickyTextView? {
        if let stv = view as? StickyTextView {
            return stv
        }
        for sub in view.subviews {
            if let found = findStickyTextView(in: sub) {
                return found
            }
        }
        return nil
    }
    
    public func updateAttributes(
        isPrivate: Bool,
        opacity: Double,
        isClickThrough: Bool
    ) {
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Hide From Screen Sharing / Recording (Zoom, Teams, Screenshots)
        self.sharingType = isPrivate ? .none : .readOnly
        
        // Opacity / Ghost mode
        self.alphaValue = CGFloat(max(0.2, min(1.0, opacity)))
        
        // Click-through reference mode
        self.ignoresMouseEvents = isClickThrough
    }
    
    public func animateToFrame(_ newFrame: NSRect, duration: TimeInterval = 0.25) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().setFrame(newFrame, display: true)
        }
    }
}
