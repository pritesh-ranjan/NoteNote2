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
            opacity: note.opacity
        )
        
        if NotesStore.shared.areAllNotesHidden {
            if panel.isVisible {
                panel.orderOut(nil)
            }
            return
        }
        
        // Never hide an actively focused/key note on store updates
        if panel.isKeyWindow {
            return
        }
        
        // If the note is not visible but should be visible for the current context, show it
        if !panel.isVisible && shouldShowNote(note) {
            panel.orderFrontRegardless()
        }
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
        if activeApp == Bundle.main.bundleIdentifier {
            return true
        }
        
        return linkedApp == activeApp
    }
    
    private func handleActiveAppChange(bundleId: String?) {
        guard !NotesStore.shared.areAllNotesHidden else { return }
        
        // If switching to NoteNote itself, do not hide any notes
        if bundleId == Bundle.main.bundleIdentifier {
            return
        }
        
        AppLogger.debug("Handling active app switch to: \(bundleId ?? "nil")")
        
        for note in NotesStore.shared.notes {
            guard let panel = panels[note.id] else { continue }
            
            // Never hide a note if the user is currently interacting with it
            if panel.isKeyWindow {
                continue
            }
            
            if let linkedApp = note.linkedAppBundleId, !linkedApp.isEmpty {
                if linkedApp == bundleId {
                    if !panel.isVisible {
                        AppLogger.debug("Showing linked note '\(note.displayTitle)' for app \(linkedApp)")
                        panel.animator().alphaValue = CGFloat(note.opacity)
                        panel.orderFrontRegardless()
                    }
                } else {
                    if panel.isVisible {
                        AppLogger.debug("Hiding linked note '\(note.displayTitle)' (linked to \(linkedApp), active: \(bundleId ?? "nil"))")
                        let initialOpacity = CGFloat(note.opacity)
                        NSAnimationContext.runAnimationGroup { context in
                            context.duration = 0.18
                            panel.animator().alphaValue = 0.0
                        } completionHandler: {
                            DispatchQueue.main.async {
                                if !panel.isKeyWindow {
                                    panel.orderOut(nil)
                                }
                                panel.alphaValue = initialOpacity
                            }
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
