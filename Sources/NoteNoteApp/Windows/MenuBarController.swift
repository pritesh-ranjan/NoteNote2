import AppKit
import SwiftUI

@MainActor
public final class MenuBarController: NSObject, NSMenuDelegate {
    public static let shared = MenuBarController()
    
    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    
    private override init() {
        super.init()
    }
    
    public func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
            if let image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "NoteNote")?.withSymbolConfiguration(config) {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "📝"
            }
            button.toolTip = "NoteNote — Sticky Notes"
        }
        
        menu.delegate = self
        statusItem?.menu = menu
        rebuildMenu()
    }
    
    public func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }
    
    private func rebuildMenu() {
        menu.removeAllItems()
        
        // 1. New Sticky Note
        let newNoteItem = NSMenuItem(
            title: "New Sticky Note",
            action: #selector(newNoteAction),
            keyEquivalent: "n"
        )
        newNoteItem.keyEquivalentModifierMask = [.command]
        newNoteItem.target = self
        menu.addItem(newNoteItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 4. Layout Submenu
        let layoutMenu = NSMenu()
        
        let stackItem = NSMenuItem(title: "Cascade Stack", action: #selector(stackAction), keyEquivalent: "2")
        stackItem.keyEquivalentModifierMask = [.command, .shift]
        stackItem.target = self
        layoutMenu.addItem(stackItem)
        
        let tileItem = NSMenuItem(title: "Tile Grid", action: #selector(tileAction), keyEquivalent: "3")
        tileItem.keyEquivalentModifierMask = [.command, .shift]
        tileItem.target = self
        layoutMenu.addItem(tileItem)
        
        let layoutParent = NSMenuItem(title: "Layout Modes", action: nil, keyEquivalent: "")
        layoutParent.submenu = layoutMenu
        menu.addItem(layoutParent)
        
        // 5. Toggle Show/Hide All
        let toggleAllTitle = NotesStore.shared.areAllNotesHidden ? "Show All Stickies" : "Hide All Stickies"
        let toggleAllItem = NSMenuItem(
            title: toggleAllTitle,
            action: #selector(toggleAllAction),
            keyEquivalent: "H"
        )
        toggleAllItem.keyEquivalentModifierMask = [.command, .shift]
        toggleAllItem.target = self
        menu.addItem(toggleAllItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 6. Recent Active Notes
        let notes = NotesStore.shared.notes
        if !notes.isEmpty {
            let headerItem = NSMenuItem(title: "Sticky Notes (\(notes.count))", action: nil, keyEquivalent: "")
            headerItem.isEnabled = false
            menu.addItem(headerItem)
            
            for note in notes.prefix(8) {
                let noteItem = NSMenuItem(
                    title: "  \(note.color.displayName.prefix(1)) \(note.displayTitle)",
                    action: #selector(focusNoteAction(_:)),
                    keyEquivalent: ""
                )
                noteItem.representedObject = note.id
                noteItem.target = self
                menu.addItem(noteItem)
            }
            
            if notes.count > 8 {
                let moreItem = NSMenuItem(title: "  + \(notes.count - 8) more notes...", action: nil, keyEquivalent: "")
                moreItem.isEnabled = false
                menu.addItem(moreItem)
            }
            
            menu.addItem(NSMenuItem.separator())
        }
        
        // 7. System & Startup Options
        StartupService.shared.refreshStatus()
        let launchAtLoginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLoginAction),
            keyEquivalent: ""
        )
        launchAtLoginItem.state = StartupService.shared.isLaunchAtLoginEnabled ? .on : .off
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)
        
        let welcomeItem = NSMenuItem(
            title: "Welcome Guide...",
            action: #selector(openWelcomeAction),
            keyEquivalent: ""
        )
        welcomeItem.target = self
        menu.addItem(welcomeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 8. Settings / Quit
        let settingsItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(openSettingsAction),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        let quitItem = NSMenuItem(
            title: "Quit NoteNote",
            action: #selector(quitAction),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    // MARK: - Actions
    @objc private func quickAddAction() {
        QuickAddWindowController.shared.show()
    }
    
    @objc private func newNoteAction() {
        if NotesStore.shared.areAllNotesHidden {
            NotesStore.shared.areAllNotesHidden = false
        }
        let note = NotesStore.shared.createNote()
        StickyWindowManager.shared.focusNote(id: note.id)
    }
    
    @objc private func screenshotAction() {
        ScreenCaptureService.shared.captureAreaToNote()
    }
    
    @objc private func pasteImageAction() {
        if !ScreenCaptureService.shared.createNoteFromClipboardImage() {
            let alert = NSAlert()
            alert.messageText = "No Image in Clipboard"
            alert.informativeText = "Copy an image or screenshot first, then choose Paste Image as Sticky Note."
            alert.runModal()
        }
    }
    
    @objc private func stackAction() {
        if NotesStore.shared.areAllNotesHidden {
            NotesStore.shared.areAllNotesHidden = false
        }
        NotesStore.shared.applyCascadeStack()
        StickyWindowManager.shared.bringAllToFront()
    }
    
    @objc private func tileAction() {
        if NotesStore.shared.areAllNotesHidden {
            NotesStore.shared.areAllNotesHidden = false
        }
        NotesStore.shared.applyTileGrid()
        StickyWindowManager.shared.bringAllToFront()
    }
    
    @objc private func toggleAllAction() {
        NotesStore.shared.toggleAllNotesVisibility()
        if !NotesStore.shared.areAllNotesHidden {
            StickyWindowManager.shared.bringAllToFront()
        }
    }
    
    @objc private func focusNoteAction(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? UUID {
            StickyWindowManager.shared.focusNote(id: id)
        }
    }
    
    @objc private func openSettingsAction() {
        SettingsWindowController.shared.show()
    }
    
    @objc private func toggleLaunchAtLoginAction() {
        let currentlyEnabled = StartupService.shared.isLaunchAtLoginEnabled
        _ = StartupService.shared.setLaunchAtLogin(enabled: !currentlyEnabled)
        rebuildMenu()
    }
    
    @objc private func openWelcomeAction() {
        WelcomeWindowController.shared.show()
    }
    
    @objc private func quitAction() {
        NSApplication.shared.terminate(nil)
    }
}
