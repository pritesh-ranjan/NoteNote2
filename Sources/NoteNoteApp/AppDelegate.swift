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
        
        // Start app watcher for app-aware notes
        AppWatcherService.shared.startObserving()
        
        // Ensure stickies are front and visible on launch
        StickyWindowManager.shared.bringAllToFront()
        
        let isDemo = CommandLine.arguments.contains(where: { $0.hasPrefix("--demo-") })
        if !isDemo {
            // Perform first launch setup (configure launch at startup and show welcome)
            StartupService.shared.performFirstLaunchSetupIfNeeded()
            
            // Start background updater cadence and check daily update if needed
            UpdateService.shared.startPeriodicTimer()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                UpdateService.shared.checkDailyUpdateIfNeeded()
            }
        }
        
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
        if CommandLine.arguments.contains("--check-updates") {
            UpdateService.shared.checkForUpdates(interactive: true)
        }
        if CommandLine.arguments.contains("--demo-update") {
            let demoRelease = GitHubRelease(
                tag_name: "v2.2.0",
                name: "NoteNote 2.2.0 — Auto-Update & Polish",
                body: "### What's New in v2.2.0\n• Native GitHub Releases auto-updater\n• Daily update cadence with silent background checks\n• One-click update & relaunch with zero external dependencies\n• UI and animation polish",
                html_url: "https://github.com/pritesh-ranjan/NoteNote2/releases",
                assets: [
                    GitHubReleaseAsset(
                        name: "NoteNote.app.zip",
                        browser_download_url: "https://github.com/pritesh-ranjan/NoteNote2/releases/download/v2.1.0/NoteNote.app.zip",
                        size: 940000
                    )
                ]
            )
            UpdateWindowController.shared.show(release: demoRelease)
        }
        
        // Automated showcase demo runners
        if CommandLine.arguments.contains("--demo-header") {
            DemoRecordingService.shared.runHeaderDemo()
        }
        if CommandLine.arguments.contains("--demo-markdown") {
            DemoRecordingService.shared.runMarkdownDemo()
        }
        if CommandLine.arguments.contains("--demo-ocr") {
            DemoRecordingService.shared.runOCRDemo()
        }
        if CommandLine.arguments.contains("--demo-search") {
            DemoRecordingService.shared.runSearchDemo()
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
