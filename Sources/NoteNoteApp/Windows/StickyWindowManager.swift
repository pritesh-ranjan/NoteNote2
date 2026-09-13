import AppKit
import SwiftUI
import Combine

@MainActor
public final class StickyWindowManager: NSObject, NSWindowDelegate {
    public static let shared = StickyWindowManager()
    
    private var panels: [UUID: StickyPanel] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var isUpdatingFrames = false
    
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
        
        let panel = StickyPanel(noteId: note.id, contentRect: frame)
        panel.delegate = self
        
        let hostingView = NSHostingView(rootView: StickyNoteView(noteId: note.id))
        panel.contentView = hostingView
        
        panels[note.id] = panel
        updatePanel(panel, for: note)
        
        // Check app awareness before ordering front
        if shouldShowNote(note) {
            panel.orderFrontRegardless()
        }
    }
    
    private func updatePanel(_ panel: StickyPanel, for note: NoteModel) {
        panel.updateAttributes(
            isPrivate: note.isPrivate,
            opacity: note.opacity,
            isClickThrough: note.isClickThrough
        )
        
        if shouldShowNote(note) && !NotesStore.shared.areAllNotesHidden {
            if !panel.isVisible {
                panel.orderFrontRegardless()
            }
        } else {
            if panel.isVisible {
                panel.orderOut(nil)
            }
        }
    }
    
    private func shouldShowNote(_ note: NoteModel) -> Bool {
        if NotesStore.shared.areAllNotesHidden {
            return false
        }
        if let linkedApp = note.linkedAppBundleId, !linkedApp.isEmpty {
            return linkedApp == AppWatcherService.shared.activeAppBundleId
        }
        return true
    }
    
    private func handleActiveAppChange(bundleId: String?) {
        guard !NotesStore.shared.areAllNotesHidden else { return }
        
        for note in NotesStore.shared.notes {
            guard let panel = panels[note.id] else { continue }
            
            if let linkedApp = note.linkedAppBundleId, !linkedApp.isEmpty {
                if linkedApp == bundleId {
                    if !panel.isVisible {
                        panel.animator().alphaValue = CGFloat(note.opacity)
                        panel.orderFrontRegardless()
                    }
                } else {
                    if panel.isVisible {
                        let initialOpacity = CGFloat(note.opacity)
                        NSAnimationContext.runAnimationGroup { context in
                            context.duration = 0.18
                            panel.animator().alphaValue = 0.0
                        } completionHandler: {
                            panel.orderOut(nil)
                            panel.alphaValue = initialOpacity
                        }
                    }
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
        guard !isUpdatingFrames,
              let window = notification.object as? StickyPanel else { return }
        NotesStore.shared.updateFrame(id: window.noteId, rect: window.frame)
    }
    
    public func windowDidResize(_ notification: Notification) {
        guard !isUpdatingFrames,
              let window = notification.object as? StickyPanel else { return }
        NotesStore.shared.updateFrame(id: window.noteId, rect: window.frame)
    }
}
