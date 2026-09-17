import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as a lightweight menu bar accessory app (no Dock icon clutter by default)
        NSApp.setActivationPolicy(.accessory)
        
        // Check if running from DMG / Downloads and offer one-click move to /Applications
        AppRelocationService.shared.checkLocationAndPromptIfNecessary()
        
        // Setup standard application & edit menu for macOS clipboard shortcuts (⌘C, ⌘V, ⌘X, ⌘A, ⌘Z)
        setupMainMenu()
        
        // Setup menu bar item
        MenuBarController.shared.setup()
        
        // Start window manager and load initial stickies
        StickyWindowManager.shared.start()
        
        // Start global keyboard shortcuts
        HotkeyService.shared.onQuickAddTriggered = {
            QuickAddWindowController.shared.show()
        }
        HotkeyService.shared.onToggleAllTriggered = {
            NotesStore.shared.toggleAllNotesVisibility()
        }
        HotkeyService.shared.start()
        
        // Start app watcher for app-aware notes
        AppWatcherService.shared.startObserving()
        
        // Ensure stickies are front and visible on launch
        StickyWindowManager.shared.bringAllToFront()
        
        // Perform first launch setup (configure launch at startup and show welcome)
        StartupService.shared.performFirstLaunchSetupIfNeeded()
        
        if CommandLine.arguments.contains("--show-settings") {
            SettingsWindowController.shared.show()
        }
        if CommandLine.arguments.contains("--show-shortcuts") {
            SettingsWindowController.shared.show(tab: 1)
        }
        if CommandLine.arguments.contains("--show-gestures") {
            SettingsWindowController.shared.show(tab: 1, scrollToGestures: true)
        }
        if CommandLine.arguments.contains("--show-quickadd") {
            QuickAddWindowController.shared.show()
        }
        if CommandLine.arguments.contains("--show-search") {
            SearchNotesWindowController.shared.show()
        }
        if CommandLine.arguments.contains("--show-trash") {
            TrashWindowController.shared.show()
        }
        if CommandLine.arguments.contains("--show-welcome") {
            WelcomeWindowController.shared.show()
        }
    }
    
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if NotesStore.shared.notes.isEmpty {
            _ = NotesStore.shared.createNote(title: "New Note 📌", content: "")
        } else {
            NotesStore.shared.areAllNotesHidden = false
            StickyWindowManager.shared.bringAllToFront()
        }
        return true
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        HotkeyService.shared.stop()
        NotesStore.shared.requestSave()
    }
    
    private func setupMainMenu() {
        let mainMenu = NSMenu()
        
        // App Menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit NoteNote", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        // Edit Menu (Cut, Copy, Paste, Select All, Undo, Redo)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redoItem = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(redoItem)
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        
        NSApp.mainMenu = mainMenu
    }
}
