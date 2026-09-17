import AppKit
import SwiftUI

public final class StickyPanel: NSPanel {
    public let noteId: UUID
    private var trackingArea: NSTrackingArea?
    
    public init(noteId: UUID, contentRect: NSRect, isPinned: Bool = false) {
        self.noteId = noteId
        
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.isFloatingPanel = isPinned
        self.hidesOnDeactivate = false
        self.level = isPinned ? .floating : .normal
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
    
    // MARK: - Gesture Tracking State
    private var accumulatedSwipeX: CGFloat = 0
    private var accumulatedSwipeY: CGFloat = 0
    private var gestureTriggeredInCurrentStroke: Bool = false
    private var lastHandledTimestamp: TimeInterval = 0
    private var lastHandledResult: Bool = false
    
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
            if key == "p" {
                NotesStore.shared.togglePin(id: noteId)
                return true
            }
            if key == "]" {
                GestureController.shared.switchToNextNote(from: noteId)
                return true
            }
            if key == "[" {
                GestureController.shared.switchToPreviousNote(from: noteId)
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }
    
    // MARK: - Native Gesture Routing (3-finger & 2-finger swipes anywhere in active note)
    public override func sendEvent(_ event: NSEvent) {
        if event.type == .swipe {
            self.swipe(with: event)
            return
        }
        
        if event.type == .scrollWheel {
            if handleScrollWheelGesture(event) {
                return
            }
        }
        
        super.sendEvent(event)
    }
    
    public override func swipe(with event: NSEvent) {
        if event.deltaY < -0.5 || event.deltaY > 0.5 {
            // 3-finger vertical swipe -> search UI
            GestureController.shared.handleSwipeFromUp()
            return
        } else if event.deltaX > 0.5 {
            // 3-finger swipe left (deltaX > 0 in AppKit) -> next note
            GestureController.shared.switchToNextNote(from: self.noteId)
            return
        } else if event.deltaX < -0.5 {
            // 3-finger swipe right (deltaX < 0 in AppKit) -> previous note
            GestureController.shared.switchToPreviousNote(from: self.noteId)
            return
        }
        super.swipe(with: event)
    }
    
    public func handleScrollWheelGesture(_ event: NSEvent) -> Bool {
        guard event.hasPreciseScrollingDeltas else { return false }
        
        // Deduplicate identical event if dispatched to both StickyPanel and StickyTextView
        if event.timestamp == lastHandledTimestamp {
            return lastHandledResult
        }
        lastHandledTimestamp = event.timestamp
        
        let phase = event.phase
        let momentum = event.momentumPhase
        
        // If a gesture already triggered during this stroke, swallow all remaining events
        // (including momentumPhase and release) until the whole gesture sequence settles.
        if gestureTriggeredInCurrentStroke {
            if (phase == .ended || phase == .cancelled || phase == []) &&
               (momentum == .ended || momentum == .cancelled || momentum == []) {
                accumulatedSwipeX = 0
                accumulatedSwipeY = 0
                gestureTriggeredInCurrentStroke = false
            }
            lastHandledResult = true
            return true
        }
        
        // Reset deltas when user lifts fingers from trackpad
        if phase == .ended || phase == .cancelled {
            accumulatedSwipeX = 0
            accumulatedSwipeY = 0
            lastHandledResult = false
            return false
        }
        
        if phase == .began {
            accumulatedSwipeX = 0
            accumulatedSwipeY = 0
            gestureTriggeredInCurrentStroke = false
        }
        
        // ONLY evaluate gestures while fingers are actively touching and moving (phase == .changed)
        // Never trigger from momentumPhase alone!
        if phase == .changed {
            let rawDeltaX = event.scrollingDeltaX
            let rawDeltaY = event.scrollingDeltaY
            let isNatural = event.isDirectionInvertedFromDevice
            
            // Normalized deltas:
            // deltaX > 0: finger moving left (right-to-left swipe)
            // deltaY > 0: finger moving downward (swipe down / from up)
            let deltaX = isNatural ? -rawDeltaX : rawDeltaX
            let deltaY = isNatural ? rawDeltaY : -rawDeltaY
            
            accumulatedSwipeX += deltaX
            accumulatedSwipeY += deltaY
            
            let absX = abs(accumulatedSwipeX)
            let absY = abs(accumulatedSwipeY)
            
            // 1. Horizontal Swipe: cycle notes (Threshold: 25 pt, works anywhere in window)
            if absX >= 25.0 && absX > (absY * 1.1) {
                gestureTriggeredInCurrentStroke = true
                if accumulatedSwipeX > 0 {
                    // Moving left -> Next Note
                    GestureController.shared.switchToNextNote(from: self.noteId)
                } else {
                    // Moving right -> Previous Note
                    GestureController.shared.switchToPreviousNote(from: self.noteId)
                }
                lastHandledResult = true
                return true
            }
            
            // 2. Vertical Swipe ("Swipe from up - search ui") (Threshold: 25 pt, works anywhere in window)
            // Triggers if note does not need scrolling or is at top of text
            if accumulatedSwipeY >= 25.0 && accumulatedSwipeY > (absX * 1.1) {
                if isTextViewAtTop() {
                    gestureTriggeredInCurrentStroke = true
                    GestureController.shared.handleSwipeFromUp()
                    lastHandledResult = true
                    return true
                }
            }
        }
        
        lastHandledResult = false
        return false
    }
    
    public func isTextViewAtTop() -> Bool {
        guard let contentView = self.contentView else { return true }
        if let scrollView = findScrollView(in: contentView) {
            let clipView = scrollView.contentView
            // If the note content fits completely in the view without scrolling, it is always at top
            if let docView = scrollView.documentView {
                if docView.frame.height <= clipView.frame.height + 4 {
                    return true
                }
            }
            let visibleOriginY = clipView.bounds.origin.y
            return visibleOriginY <= 4.0
        }
        return true
    }
    
    private func findScrollView(in view: NSView) -> NSScrollView? {
        if let sv = view as? NSScrollView {
            return sv
        }
        for sub in view.subviews {
            if let found = findScrollView(in: sub) {
                return found
            }
        }
        return nil
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
        isPinned: Bool
    ) {
        self.isFloatingPanel = isPinned
        self.hidesOnDeactivate = false
        self.level = isPinned ? .floating : .normal
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Hide From Screen Sharing / Recording (Zoom, Teams, Screenshots)
        self.sharingType = isPrivate ? .none : .readOnly
        
        // Opacity / Ghost mode
        self.alphaValue = CGFloat(max(0.2, min(1.0, opacity)))
        
        // Ensure panel is always interactable (cannot be made unclickable)
        self.ignoresMouseEvents = false
    }
}
