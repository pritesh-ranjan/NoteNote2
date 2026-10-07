import AppKit
import CoreGraphics
import Foundation

@MainActor
public final class ScreenCaptureService {
    public static let shared = ScreenCaptureService()
    
    private init() {}
    
    /// Checks whether NoteNote has permission to record/capture the screen.
    public var hasScreenCapturePermission: Bool {
        CGPreflightScreenCaptureAccess()
    }
    
    /// Requests screen capture permission and guides the user.
    public func promptForScreenCapturePermission() {
        CGRequestScreenCaptureAccess()
        
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = """
        macOS requires Screen Recording permission for NoteNote to capture screen areas into sticky notes.
        
        1. Click 'Open System Settings' and enable NoteNote under Screen Recording.
        2. Important: In macOS, NoteNote must be restarted after enabling the permission for it to take effect.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Restart NoteNote")
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            restartApp()
        } else if response == .alertSecondButtonReturn {
            openScreenCaptureSettings()
        }
    }
    
    public func openScreenCaptureSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
    
    public func restartApp() {
        let bundleURL = Bundle.main.bundleURL
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: config) { _, _ in
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        }
    }
    
    /// Launches interactive macOS screen capture (`screencapture -i`).
    /// On successful capture, creates a new sticky note with the screenshot attached and brings it to focus.
    public func captureScreenInteractive() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("screencapture_\(UUID().uuidString).png")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", tempURL.path]
        
        process.terminationHandler = { proc in
            DispatchQueue.main.async {
                defer {
                    try? FileManager.default.removeItem(at: tempURL)
                }
                
                guard FileManager.default.fileExists(atPath: tempURL.path),
                      let fileAttributes = try? FileManager.default.attributesOfItem(atPath: tempURL.path),
                      let fileSize = fileAttributes[.size] as? Int64, fileSize > 0,
                      let fileData = try? Data(contentsOf: tempURL),
                      let capturedImage = NSImage(data: fileData), capturedImage.isValid else {
                    AppLogger.info("Interactive screen capture cancelled or empty (termination status: \(proc.terminationStatus))")
                    return
                }
                
                // If stickies were hidden, show them
                if NotesStore.shared.areAllNotesHidden {
                    NotesStore.shared.areAllNotesHidden = false
                }
                
                let timeString = Date().formatted(date: .omitted, time: .shortened)
                let newNote = NotesStore.shared.createNote(
                    title: "Screen Capture • \(timeString)",
                    content: ""
                )
                
                StickyWindowManager.shared.focusNote(id: newNote.id)
                AppLogger.info("Created new sticky note \(newNote.id) from screen capture, presenting image action menu")
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    let panel = StickyWindowManager.shared.panel(for: newNote.id)
                        ?? NSApp.windows.first(where: { ($0 as? StickyPanel)?.noteId == newNote.id }) as? StickyPanel
                    guard let activePanel = panel, let contentView = activePanel.contentView else {
                        NotesStore.shared.addImageAttachment(to: newNote.id, image: capturedImage)
                        return
                    }
                    
                    let location = NSPoint(x: contentView.bounds.midX, y: contentView.bounds.midY)
                    NoteBodyContextMenu.showImageActionMenu(
                        for: capturedImage,
                        noteId: newNote.id,
                        at: location,
                        in: contentView,
                        headerTitle: "Screen Capture"
                    ) {
                        // User cancelled menu: clean up empty placeholder note
                        if let note = NotesStore.shared.notes.first(where: { $0.id == newNote.id }),
                           note.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                           note.imageAttachments.isEmpty {
                            NotesStore.shared.deleteNote(id: newNote.id)
                            AppLogger.info("Cancelled screen capture sticky note \(newNote.id)")
                        }
                    }
                }
            }
        }
        
        do {
            try process.run()
            AppLogger.info("Launched /usr/sbin/screencapture -i")
        } catch {
            AppLogger.error("Failed to launch screencapture", error: error)
        }
    }
}
