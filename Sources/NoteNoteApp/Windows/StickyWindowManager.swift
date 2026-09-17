import AppKit
import SwiftUI
import Combine

@MainActor
public final class StickyWindowManager: NSObject, NSWindowDelegate {
    public static let shared = StickyWindowManager()
    
    private var panels: [UUID: StickyPanel] = [:]
    private var pendingHideTasks: [UUID: DispatchWorkItem] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    private override init() {
        super.init()
        setupBindings()
    }
    
    public func start() {
        syncPanels(with: NotesStore.shared.notes)
    }
    
    private func setupBindings() {
        // Observe notes collection changes
        NotesStore.shared.$notes
            .receive(on: RunLoop.main)
            .sink { [weak self] notes in
                self?.syncPanels(with: notes)
            }
            .store(in: &cancellables)
        
        // Observe active application switches
        AppWatcherService.shared.$effectiveActiveAppBundleId
            .receive(on: RunLoop.main)
            .sink { [weak self] bundleId in
                self?.handleActiveAppChange(bundleId: bundleId)
            }
            .store(in: &cancellables)
        
        // Observe Show/Hide all
        NotesStore.shared.$areAllNotesHidden
            .receive(on: RunLoop.main)
            .sink { [weak self] isHidden in
                self?.handleHideAll(isHidden: isHidden)
            }
            .store(in: &cancellables)
    }
    
    private func syncPanels(with notes: [NoteModel]) {
        let currentIds = Set(notes.map { $0.id })
        let existingIds = Set(panels.keys)
        
        // Remove closed notes
        for removedId in existingIds.subtracting(currentIds) {
            pendingHideTasks.removeValue(forKey: removedId)?.cancel()
            if let panel = panels.removeValue(forKey: removedId) {
                panel.orderOut(nil)
            }
        }
        
        // Add or update notes
        for note in notes {
            if let panel = panels[note.id] {
                updatePanel(panel, for: note)
            } else {
                createPanel(for: note)
            }
        }
    }
    
    private func createPanel(for note: NoteModel) {
        let frame = NSRect(
            x: note.frameX,
            y: note.frameY,
            width: note.frameWidth,
            height: note.frameHeight
        )
        
        let panel = StickyPanel(noteId: note.id, contentRect: frame, isPinned: note.isPinned)
        panel.delegate = self
        
        let hostingView = NSHostingView(rootView: StickyNoteView(noteId: note.id))
        panel.contentView = hostingView
        
        panels[note.id] = panel
        updatePanel(panel, for: note)
        
        // Check app awareness before ordering front
        if shouldShowNote(note) {
            showLinkedNote(note, panel: panel)
        }
    }
    
    private func updatePanel(_ panel: StickyPanel, for note: NoteModel) {
        let isLinkedActive = (note.linkedAppBundleId != nil && !note.linkedAppBundleId!.isEmpty && shouldShowNote(note))
        panel.updateAttributes(
            isPrivate: note.isPrivate,
            opacity: note.opacity,
            isPinned: note.isPinned,
            isLinkedAppActive: isLinkedActive
        )
        
        if NotesStore.shared.areAllNotesHidden {
            pendingHideTasks[note.id]?.cancel()
            pendingHideTasks.removeValue(forKey: note.id)
            if panel.isVisible {
                panel.orderOut(nil)
            }
            return
        }
        
        if shouldShowNote(note) {
            if let linked = note.linkedAppBundleId, !linked.isEmpty {
                showLinkedNote(note, panel: panel)
            } else if !panel.isVisible {
                panel.orderFrontRegardless()
            }
        } else {
            hideLinkedNote(note, panel: panel)
        }
    }
    
    private func isCurrentApp(bundleId: String?) -> Bool {
        guard let bundleId = bundleId, !bundleId.isEmpty else { return false }
        if let currentId = Bundle.main.bundleIdentifier, currentId == bundleId {
            return true
        }
        if let currentId = NSRunningApplication.current.bundleIdentifier, currentId == bundleId {
            return true
        }
        return bundleId == "com.priteshranjan.NoteNote"
    }
    
    private func shouldShowNote(_ note: NoteModel) -> Bool {
        if NotesStore.shared.areAllNotesHidden {
            return false
        }
        guard let linkedApp = note.linkedAppBundleId, !linkedApp.isEmpty else {
            return true
        }
        
        let effectiveApp = AppWatcherService.shared.effectiveActiveAppBundleId
        return linkedApp == effectiveApp
    }
    
    private func showLinkedNote(_ note: NoteModel, panel: StickyPanel) {
        pendingHideTasks[note.id]?.cancel()
        pendingHideTasks.removeValue(forKey: note.id)
        
        let targetOpacity = CGFloat(max(0.2, min(1.0, note.opacity)))
        
        // App-linked notes must float over the active application windows
        panel.level = .floating
        panel.isFloatingPanel = true
        
        if !panel.isVisible {
            AppLogger.debug("Showing linked note '\(note.displayTitle)' for app \(note.linkedAppBundleId ?? "")")
            panel.alphaValue = 0.0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                panel.animator().alphaValue = targetOpacity
            }
        } else {
            // Already visible: ensure it is brought in front of the newly activated application
            panel.orderFrontRegardless()
            if panel.alphaValue < targetOpacity {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.15
                    panel.animator().alphaValue = targetOpacity
                }
            }
        }
    }
    
    private func hideLinkedNote(_ note: NoteModel, panel: StickyPanel) {
        pendingHideTasks[note.id]?.cancel()
        
        // If the note should be shown according to effective active app, don't hide
        if shouldShowNote(note) {
            return
        }
        
        guard panel.isVisible else { return }
        
        AppLogger.debug("Hiding linked note '\(note.displayTitle)' (linked to \(note.linkedAppBundleId ?? ""), effective: \(AppWatcherService.shared.effectiveActiveAppBundleId ?? "nil"))")
        
        let targetOpacity = CGFloat(max(0.2, min(1.0, note.opacity)))
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 0.0
        }
        
        let workItem = DispatchWorkItem { [weak self, weak panel] in
            guard let self = self, let panel = panel else { return }
            self.pendingHideTasks.removeValue(forKey: note.id)
            
            // Re-verify that the note should still be hidden before ordering out
            if !self.shouldShowNote(note) {
                panel.orderOut(nil)
            }
            panel.alphaValue = targetOpacity
        }
        
        pendingHideTasks[note.id] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)
    }
    
    private func handleActiveAppChange(bundleId: String?) {
        guard !NotesStore.shared.areAllNotesHidden else { return }
        evaluateAllNotesVisibility()
    }
    
    public func evaluateAllNotesVisibility() {
        guard !NotesStore.shared.areAllNotesHidden else { return }
        for note in NotesStore.shared.notes {
            guard let panel = panels[note.id] else { continue }
            
            if let linkedApp = note.linkedAppBundleId, !linkedApp.isEmpty {
                if shouldShowNote(note) {
                    showLinkedNote(note, panel: panel)
                } else {
                    hideLinkedNote(note, panel: panel)
                }
            }
        }
    }
    
    private func handleHideAll(isHidden: Bool) {
        for (id, panel) in panels {
            guard let note = NotesStore.shared.notes.first(where: { $0.id == id }) else { continue }
            if isHidden {
                panel.orderOut(nil)
            } else if shouldShowNote(note) {
                panel.orderFrontRegardless()
            }
        }
    }
    
    public func updatePanelOpacityLive(id: UUID, opacity: Double) {
        if let panel = panels[id] {
            panel.alphaValue = CGFloat(max(0.2, min(1.0, opacity)))
        }
    }
    
    public func focusNote(id: UUID) {
        if NotesStore.shared.areAllNotesHidden {
            NotesStore.shared.areAllNotesHidden = false
        }
        if panels[id] == nil {
            syncPanels(with: NotesStore.shared.notes)
        }
        guard let panel = panels[id] else { return }
        
        panel.activateAndFocus()
        
        // WindowServer can restore previous app focus when an interactive tool (such as screencapture) exits.
        // Delayed reaffirmations ensure NoteNote and this sticky note maintain front & key focus,
        // and allow SwiftUI hosting views to finish laying out the NSTextView editor for first responder.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak panel] in
            guard let panel = panel, panel.isVisible else { return }
            panel.activateAndFocus()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { [weak panel] in
            guard let panel = panel, panel.isVisible else { return }
            panel.focusEditor()
        }
    }
    
    public func bringAllToFront() {
        if NotesStore.shared.areAllNotesHidden {
            NotesStore.shared.areAllNotesHidden = false
        }
        syncPanels(with: NotesStore.shared.notes)
        for (id, panel) in panels {
            guard let note = NotesStore.shared.notes.first(where: { $0.id == id }) else { continue }
            if shouldShowNote(note) {
                panel.orderFrontRegardless()
            }
        }
        if let first = panels.values.first {
            first.activateAndFocus()
        } else {
            if #available(macOS 14.0, *) {
                NSRunningApplication.current.activate(options: [.activateAllWindows])
                NSApp.activate()
            } else {
                NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    // MARK: - NSWindowDelegate
    public func windowWillMove(_ notification: Notification) {
        guard let window = notification.object as? StickyPanel else { return }
        window.orderFrontRegardless()
    }
    
    public func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? StickyPanel else { return }
        window.orderFrontRegardless()
    }
    
    public func windowDidResignKey(_ notification: Notification) {
        evaluateAllNotesVisibility()
    }
    
    public func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? StickyPanel else { return }
        NotesStore.shared.updateFrame(id: window.noteId, rect: window.frame)
    }
    
    public func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? StickyPanel else { return }
        NotesStore.shared.updateFrame(id: window.noteId, rect: window.frame)
    }
}
