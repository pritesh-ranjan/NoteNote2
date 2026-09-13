import AppKit

@MainActor
public final class AppRelocationService {
    public static let shared = AppRelocationService()
    
    private init() {}
    
    public func checkLocationAndPromptIfNecessary() {
        let bundlePath = Bundle.main.bundlePath
        
        // Skip relocation check if running in debug / development build
        if bundlePath.contains("/.build/") || bundlePath.contains("/DerivedData/") {
            return
        }
        
        // Check if already inside /Applications or ~/Applications
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let userApplicationsPath = (homeDir as NSString).appendingPathComponent("Applications")
        
        if bundlePath.hasPrefix("/Applications/") || bundlePath == "/Applications/NoteNote.app" ||
           bundlePath.hasPrefix(userApplicationsPath) {
            return
        }
        
        // Check if running from a mounted disk image or Downloads folder
        let isDiskImage = bundlePath.hasPrefix("/Volumes/")
        let isDownloads = bundlePath.contains("/Downloads/")
        
        guard isDiskImage || isDownloads else {
            return
        }
        
        // Show relocation alert
        let alert = NSAlert()
        alert.messageText = "Move to Applications folder?"
        alert.informativeText = "NoteNote works best when installed in your Applications folder so it can start automatically on login and stay accessible.\n\nWould you like to move NoteNote to Applications now?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Move to Applications")
        alert.addButton(withTitle: "Do Not Move")
        
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            relocateToApplications(from: bundlePath)
        }
    }
    
    private func relocateToApplications(from sourcePath: String) {
        let fileManager = FileManager.default
        let destinationDir = "/Applications"
        let appName = (sourcePath as NSString).lastPathComponent
        let destinationPath = (destinationDir as NSString).appendingPathComponent(appName)
        let destinationURL = URL(fileURLWithPath: destinationPath)
        let sourceURL = URL(fileURLWithPath: sourcePath)
        
        do {
            // Remove existing app at destination if it exists
            if fileManager.fileExists(atPath: destinationPath) {
                try fileManager.removeItem(at: destinationURL)
            }
            
            // Copy to /Applications
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            
            // Launch the newly installed application
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: destinationURL, configuration: config) { _, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Failed to launch relocated app: \(error)")
                    }
                    // Exit the temporary DMG / Downloads copy
                    NSApp.terminate(nil)
                }
            }
        } catch {
            print("Failed to relocate app: \(error)")
            let failAlert = NSAlert()
            failAlert.messageText = "Could Not Move Automatically"
            failAlert.informativeText = "Permission was denied or an error occurred while copying to Applications. Please drag NoteNote to the Applications shortcut manually in the installer window."
            failAlert.runModal()
        }
    }
}
