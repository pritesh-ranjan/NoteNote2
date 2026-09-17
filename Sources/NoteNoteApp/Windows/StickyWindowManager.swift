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
        AppWatcherService.shared.$activeAppBundleId
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
        panel.updateAttributes(
            isPrivate: note.isPrivate,
            opacity: note.opacity,
            isPinned: note.isPinned
        )
        
        if NotesStore.shared.areAllNotesHidden {
            pendingHideTasks[note.id]?.cancel()
            pendingHideTasks.removeValue(forKey: note.id)
            if panel.isVisible {
                panel.orderOut(nil)
            }
            return
        }
        
        // Never hide an actively focused/key note on store updates
        if panel.isKeyWindow {
            return
        }
        
        if shouldShowNote(note) {
            showLinkedNote(note, panel: panel)
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
        
        // If the note panel is currently the key window, keep it visible
        if let panel = panels[note.id], panel.isKeyWindow {
            return true
        }
        
        // If NoteNote itself is the active app, keep all notes visible
        let activeApp = AppWatcherService.shared.activeAppBundleId
        if isCurrentApp(bundleId: activeApp) {
            return true
        }
        
        return linkedApp == activeApp
    }
    
    private func showLinkedNote(_ note: NoteModel, panel: StickyPanel) {
        pendingHideTasks[note.id]?.cancel()
        pendingHideTasks.removeValue(forKey: note.id)
        
        let targetOpacity = CGFloat(max(0.2, min(1.0, note.opacity)))
        panel.level = note.isPinned ? .floating : .normal
        panel.isFloatingPanel = note.isPinned
        
        if !panel.isVisible {
            AppLogger.debug("Showing linked note '\(note.displayTitle)' for app \(note.linkedAppBundleId ?? "")")
            panel.alphaValue = 0.0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                panel.animator().alphaValue = targetOpacity
            }
        } else {
            // Panel already visible: ensure opacity is restored if it was fading out, and bring front
            if panel.alphaValue < targetOpacity {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.18
                    panel.animator().alphaValue = targetOpacity
                }
            }
            panel.orderFrontRegardless()
        }
    }
    
    private func hideLinkedNote(_ note: NoteModel, panel: StickyPanel) {
        pendingHideTasks[note.id]?.cancel()
        
        // Never hide an actively focused note if the user is typing in it
        if panel.isKeyWindow {
            return
        }
        
        guard panel.isVisible else { return }
        
        AppLogger.debug("Hiding linked note '\(note.displayTitle)' (linked to \(note.linkedAppBundleId ?? ""), active: \(AppWatcherService.shared.activeAppBundleId ?? "nil"))")
        
        let targetOpacity = CGFloat(max(0.2, min(1.0, note.opacity)))
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel.animator().alphaValue = 0.0
        }
        
        let workItem = DispatchWorkItem { [weak self, weak panel] in
            guard let self = self, let panel = panel else { return }
            self.pendingHideTasks.removeValue(forKey: note.id)
            
            // Re-verify that the note should still be hidden before ordering out
            if !self.shouldShowNote(note) && !panel.isKeyWindow {
                panel.orderOut(nil)
            }
            panel.alphaValue = targetOpacity
        }
        
        pendingHideTasks[note.id] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: workItem)
    }
    
    private func handleActiveAppChange(bundleId: String?) {
        guard !NotesStore.shared.areAllNotesHidden else { return }
        
        // If switching to NoteNote itself, do not hide any notes
        if isCurrentApp(bundleId: bundleId) {
            return
        }
        
        AppLogger.debug("Handling active app switch to: \(bundleId ?? "nil")")
        
        for note in NotesStore.shared.notes {
            guard let panel = panels[note.id] else { continue }
            
            if let linkedApp = note.linkedAppBundleId, !linkedApp.isEmpty {
                if linkedApp == bundleId {
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
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        panel.makeKey()
        NSApp.activate(ignoringOtherApps: true)
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
            first.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // MARK: - NSWindowDelegate
    public func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? StickyPanel else { return }
        NotesStore.shared.updateFrame(id: window.noteId, rect: window.frame)
    }
    
    public func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? StickyPanel else { return }
        NotesStore.shared.updateFrame(id: window.noteId, rect: window.frame)
    }
}
