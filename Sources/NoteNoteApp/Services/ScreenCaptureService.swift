import AppKit

@MainActor
public final class ScreenCaptureService {
    public static let shared = ScreenCaptureService()
    
    private init() {}
    
    public func captureAreaToNote() {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "screenshot_\(UUID().uuidString).png"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", fileURL.path]
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if FileManager.default.fileExists(atPath: fileURL.path) {
                // Permanently copy to app support images
                let imagesDir = NotesStore.shared.imagesDirectory
                let targetURL = imagesDir.appendingPathComponent(fileName)
                try? FileManager.default.copyItem(at: fileURL, to: targetURL)
                
                let note = NotesStore.shared.createNote(
                    title: "Screenshot Reference",
                    content: "",
                    isImageNote: true,
                    imageAttachmentPath: targetURL.path
                )
                StickyWindowManager.shared.focusNote(id: note.id)
            }
        } catch {
            print("Failed to run screencapture: \(error)")
        }
    }
    
    public func createNoteFromClipboardImage() -> Bool {
        let pasteboard = NSPasteboard.general
        if let image = NSImage(pasteboard: pasteboard) {
            let imagesDir = NotesStore.shared.imagesDirectory
            let fileName = "clipboard_\(UUID().uuidString).png"
            let targetURL = imagesDir.appendingPathComponent(fileName)
            
            if let tiff = image.tiffRepresentation,
                let bitmap = NSBitmapImageRep(data: tiff),
                let png = bitmap.representation(using: .png, properties: [:]) {
                try? png.write(to: targetURL)
                
                let note = NotesStore.shared.createNote(
                    title: "Image Note",
                    content: "",
                    isImageNote: true,
                    imageAttachmentPath: targetURL.path
                )
                StickyWindowManager.shared.focusNote(id: note.id)
                return true
            }
        }
        return false
    }
}
