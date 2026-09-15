import Foundation
import Combine
import SwiftUI
import AppKit

public enum ExportFormat {
    case markdown
    case plainText
}

@MainActor
public final class NotesStore: ObservableObject {
    public static let shared = NotesStore()
    
    @Published public var notes: [NoteModel] = []
    @Published public var settings: AppSettings = .default
    @Published public var activeAppBundleId: String? = nil
    @Published public var areAllNotesHidden: Bool = false
    
    private let fileManager = FileManager.default
    private var saveCancellable: AnyCancellable?
    private let saveSubject = PassthroughSubject<Void, Never>()
    
    public var storageDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let newDir = appSupport.appendingPathComponent("NoteNote", isDirectory: true)
        let oldDir = appSupport.appendingPathComponent("NotickyMac", isDirectory: true)
        
        if !fileManager.fileExists(atPath: newDir.path) {
            if fileManager.fileExists(atPath: oldDir.path) {
                try? fileManager.copyItem(at: oldDir, to: newDir)
            } else {
                try? fileManager.createDirectory(at: newDir, withIntermediateDirectories: true)
            }
        }
        return newDir
    }
    
    private var notesFileURL: URL {
        storageDirectory.appendingPathComponent("notes.json")
    }
    
    private var settingsFileURL: URL {
        storageDirectory.appendingPathComponent("settings.json")
    }
    
    private init() {
        loadSettings()
        loadNotes()
        
        saveCancellable = saveSubject
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] in
                self?.persistData()
            }
    }
    
    public func requestSave() {
        saveSubject.send(())
    }
    
    public func createNote(
        title: String = "",
        content: String = "",
        color: NoteColor? = nil,
        linkedAppBundleId: String? = nil,
        linkedAppName: String? = nil,
        at position: CGPoint? = nil
    ) -> NoteModel {
        let chosenColor: NoteColor = {
            if let explicit = color {
                return explicit
            }
            let allColors = NoteColor.allCases
            if let lastColor = notes.last?.color {
                let alternatives = allColors.filter { $0 != lastColor }
                return alternatives.randomElement() ?? allColors.randomElement() ?? .yellow
            }
            return allColors.randomElement() ?? .yellow
        }()
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 100, y: 100, width: 1400, height: 900)
        
        // Stagger placement if position not provided
        let countOffset = Double((notes.count % 8) * 32)
        let posX = position?.x ?? (screenFrame.midX - 140 + countOffset)
        let posY = position?.y ?? (screenFrame.midY - 140 - countOffset)
        
        let newNote = NoteModel(
            title: title,
            content: content,
            color: chosenColor,
            isPrivate: settings.defaultHideFromScreenCapture,
            linkedAppBundleId: linkedAppBundleId,
            linkedAppName: linkedAppName,
            dockEdge: settings.defaultDockEdge,
            frameX: posX,
            frameY: posY,
            frameWidth: 280,
            frameHeight: 280
        )
        
        notes.append(newNote)
        requestSave()
        return newNote
    }
    
    public func updateNote(_ updated: NoteModel) {
        if let idx = notes.firstIndex(where: { $0.id == updated.id }) {
            var note = updated
            note.updatedAt = Date()
            notes[idx] = note
            requestSave()
        }
    }
    
    public func deleteNote(id: UUID) {
        notes.removeAll(where: { $0.id == id })
        requestSave()
    }
    
    public func duplicateNote(id: UUID) -> NoteModel? {
        guard let note = notes.first(where: { $0.id == id }) else { return nil }
        var copy = note
        copy.id = UUID()
        copy.title = note.title.isEmpty ? "" : "\(note.title) (Copy)"
        copy.frameX += 28
        copy.frameY -= 28
        copy.createdAt = Date()
        copy.updatedAt = Date()
        notes.append(copy)
        requestSave()
        return copy
    }
    
    public func togglePrivate(id: UUID) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[idx].isPrivate.toggle()
        requestSave()
    }
    
    public func toggleLock(id: UUID) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[idx].isLocked.toggle()
        requestSave()
    }
    
    public func setLocked(id: UUID, locked: Bool) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[idx].isLocked = locked
        requestSave()
    }
    
    public func toggleDock(id: UUID) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[idx].isDocked.toggle()
        requestSave()
    }
    
    public func updateFrame(id: UUID, rect: NSRect) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[idx].frameX = rect.origin.x
        notes[idx].frameY = rect.origin.y
        notes[idx].frameWidth = rect.size.width
        notes[idx].frameHeight = rect.size.height
        requestSave()
    }
    
    public func setLinkedApp(id: UUID, bundleId: String?, appName: String?) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[idx].linkedAppBundleId = bundleId
        notes[idx].linkedAppName = appName
        AppLogger.info("Set linked app for note '\(notes[idx].displayTitle)': bundleId=\(bundleId ?? "nil"), appName=\(appName ?? "nil")")
        requestSave()
    }
    
    public func toggleAllNotesVisibility() {
        areAllNotesHidden.toggle()
        AppLogger.info("Toggled all notes visibility: areAllNotesHidden=\(areAllNotesHidden)")
    }
    
    public func exportNote(id: UUID, format: ExportFormat) -> URL? {
        guard let note = notes.first(where: { $0.id == id }) else { return nil }
        let fileName = (note.displayTitle.replacingOccurrences(of: "/", with: "-"))
        let ext = format == .markdown ? "md" : "txt"
        let tempURL = storageDirectory.appendingPathComponent("\(fileName).\(ext)")
        
        let content: String
        switch format {
        case .markdown:
            content = "# \(note.displayTitle)\n\n\(note.content)\n\n---\n*Created with NoteNote for Mac on \(note.createdAt.formatted())*"
        case .plainText:
            content = "\(note.displayTitle)\n\n\(note.content)"
        }
        
        do {
            try content.write(to: tempURL, atomically: true, encoding: .utf8)
            AppLogger.info("Exported note '\(note.displayTitle)' to \(tempURL.path)")
            return tempURL
        } catch {
            AppLogger.error("Failed to export note '\(note.displayTitle)'", error: error)
            return nil
        }
    }
    
    // MARK: - Layout Modes
    public func applyCascadeStack() {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        var startX = visibleFrame.maxX - 360
        var startY = visibleFrame.maxY - 360
        
        for idx in notes.indices {
            notes[idx].frameX = startX
            notes[idx].frameY = startY
            notes[idx].frameWidth = 320
            notes[idx].frameHeight = 300
            notes[idx].isDocked = false
            
            startX -= 36
            startY -= 36
            if startX < visibleFrame.minX + 40 || startY < visibleFrame.minY + 40 {
                startX = visibleFrame.maxX - 360
                startY = visibleFrame.maxY - 360
            }
        }
        requestSave()
    }
    
    public func applyTileGrid() {
        guard let screen = NSScreen.main, !notes.isEmpty else { return }
        let visibleFrame = screen.visibleFrame
        let padding: CGFloat = 24
        let count = notes.count
        
        let cols = max(1, Int(ceil(sqrt(Double(count)))))
        let rows = max(1, Int(ceil(Double(count) / Double(cols))))
        
        let cellW = (visibleFrame.width - CGFloat(cols + 1) * padding) / CGFloat(cols)
        let cellH = (visibleFrame.height - CGFloat(rows + 1) * padding) / CGFloat(rows)
        
        for (i, idx) in notes.indices.enumerated() {
            let col = i % cols
            let row = i / cols
            let x = visibleFrame.minX + padding + CGFloat(col) * (cellW + padding)
            let y = visibleFrame.maxY - padding - CGFloat(row + 1) * (cellH + padding) + padding
            
            notes[idx].frameX = x
            notes[idx].frameY = y
            notes[idx].frameWidth = cellW
            notes[idx].frameHeight = cellH
            notes[idx].isDocked = false
        }
        requestSave()
    }
    
    // MARK: - Persistence
    private func persistData() {
        do {
            let data = try JSONEncoder().encode(notes)
            try data.write(to: notesFileURL, options: .atomic)
            
            let settingsData = try JSONEncoder().encode(settings)
            try settingsData.write(to: settingsFileURL, options: .atomic)
        } catch {
            AppLogger.error("Failed to persist NoteNote data", error: error)
        }
    }
    
    private func loadSettings() {
        guard let data = try? Data(contentsOf: settingsFileURL),
              let loaded = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return
        }
        self.settings = loaded
    }
    
    private func loadNotes() {
        if fileManager.fileExists(atPath: notesFileURL.path) {
            guard let data = try? Data(contentsOf: notesFileURL),
                  let loaded = try? JSONDecoder().decode([NoteModel].self, from: data) else {
                // If the file exists but cannot be decoded, preserve a valid empty state
                self.notes = []
                return
            }
            var updated = loaded
            var modified = false
            for i in updated.indices {
                if updated[i].title.contains("Noticky") {
                    updated[i].title = updated[i].title.replacingOccurrences(of: "Noticky", with: "NoteNote")
                    modified = true
                }
                if updated[i].content.contains("Noticky") {
                    updated[i].content = updated[i].content.replacingOccurrences(of: "Noticky", with: "NoteNote")
                    modified = true
                }
                if updated[i].content.contains("noticky") {
                    updated[i].content = updated[i].content.replacingOccurrences(of: "noticky", with: "notenote")
                    modified = true
                }
            }
            self.notes = updated
            if modified {
                persistData()
            }
        } else {
            // First launch ever: populate welcome notes
            loadWelcomeNotes()
        }
    }
    
    private func loadWelcomeNotes() {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 100, y: 100, width: 1400, height: 900)
        
        let note1 = NoteModel(
            title: "Welcome to NoteNote! 📌",
            content: """
            ### Fast, Native Mac Sticky Notes
            
            – [x] Try Always-on-Top (floats above fullscreen apps)
            – [ ] Click the Shield icon 🛡️ to toggle screen sharing privacy
            – [ ] Click 🔗 to link this note to an app (Xcode, Safari, Figma)
            – [ ] Click ⭲ to dock this note to the screen edge
            – [ ] Press ⌘⇧N anywhere for Quick Add capture!
            """,
            color: .yellow,
            isPrivate: false,
            frameX: screen.maxX - 380,
            frameY: screen.maxY - 380,
            frameWidth: 320,
            frameHeight: 310
        )
        
        let note2 = NoteModel(
            title: "Meeting Prep & Secrets 🔒",
            content: """
            ## Screen Sharing Privacy Demo
            
            This note has **Privacy Shield** enabled (🛡️)!
            
            Uses macOS AppKit window-sharing protection (`window.sharingType = .none`) to help keep confidential notes hidden during screen sharing or screenshots.
            
            ```
            API_KEY=notenote_demo_token_key_abc123
            ```
            """,
            color: .pink,
            isPrivate: true,
            frameX: screen.maxX - 720,
            frameY: screen.maxY - 360,
            frameWidth: 310,
            frameHeight: 290
        )
        
        let note3 = NoteModel(
            title: "Quick Ideas & Code 💡",
            content: """
            ### Native Markdown WYSIWYG
            
            Live rendered formatting right as you type:
            - **Bold text** and *italic accents*
            - Interactive `- [ ]` checklists
            - Code blocks & inline `monospace`
            - Live word counter and color themes!
            """,
            color: .green,
            isPrivate: false,
            frameX: screen.maxX - 1050,
            frameY: screen.maxY - 340,
            frameWidth: 300,
            frameHeight: 270
        )
        
        self.notes = [note1, note2, note3]
        persistData()
    }
}

extension Notification.Name {
    public static let toggleNoteLock = Notification.Name("NoteNote_toggleNoteLock")
    public static let didLockNote = Notification.Name("NoteNote_didLockNote")
}
