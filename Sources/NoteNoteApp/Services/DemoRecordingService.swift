import AppKit
import SwiftUI

@MainActor
public final class DemoRecordingService {
    public static let shared = DemoRecordingService()
    
    private init() {}
    
    private func resetEnvironment() {
        WelcomeWindowController.shared.close()
        SearchNotesWindowController.shared.hide()
        QuickAddWindowController.shared.hide()
        NotesStore.shared.areAllNotesHidden = false
        NotesStore.shared.notes.removeAll()
    }
    
    public func runHeaderDemo() {
        resetEnvironment()
        
        var note = NotesStore.shared.createNote(
            title: "Launch Strategy 🚀",
            content: "Distraction-free desktop stickies.\n100% local, borderless unibody design.\nHover to reveal controls or right-click header for 15 themes.",
            color: .yellow,
            at: CGPoint(x: 650, y: 400)
        )
        note.isPrivate = false
        note.isHeaderHovered = false
        note.frameX = 650
        note.frameY = 400
        note.frameWidth = 340
        note.frameHeight = 340
        NotesStore.shared.updateNote(note)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            StickyWindowManager.shared.bringAllToFront()
            
            guard let panel = NSApp.windows.first(where: { ($0 as? StickyPanel)?.noteId == note.id }) as? StickyPanel else {
                return
            }
            panel.setFrame(NSRect(x: 650, y: 400, width: 340, height: 340), display: true)
            panel.orderFrontRegardless()
            
            // t = 0.9s: Reveal header controls (buttons slide & pop into view)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) {
                    if let idx = NotesStore.shared.notes.firstIndex(where: { $0.id == note.id }) {
                        NotesStore.shared.notes[idx].isHeaderHovered = true
                    }
                }
            }
            
            // t = 1.9s: Switch to Piccolo theme
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if let idx = NotesStore.shared.notes.firstIndex(where: { $0.id == note.id }) {
                        NotesStore.shared.notes[idx].color = .piccolo
                    }
                }
            }
            
            // t = 2.8s: Switch to Mononoke theme
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if let idx = NotesStore.shared.notes.firstIndex(where: { $0.id == note.id }) {
                        NotesStore.shared.notes[idx].color = .mononoke
                    }
                }
            }
            
            // t = 3.6s: Hide header controls (slide & fade away)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.6) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) {
                    if let idx = NotesStore.shared.notes.firstIndex(where: { $0.id == note.id }) {
                        NotesStore.shared.notes[idx].isHeaderHovered = false
                    }
                }
            }
            
            // t = 4.4s: Terminate cleanly
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.4) {
                NSApp.terminate(nil)
            }
        }
    }
    
    public func runMarkdownDemo() {
        resetEnvironment()
        
        let initialContent = """
        # Sprint Release Plan 🚀
        
        ## Deliverables
        - [ ] Complete local SQLite cache
        - [ ] Write designated codesign requirement
        - [ ] Test on-device Apple Vision OCR
        
        Command: `scripts/build_app.sh`
        """
        
        var note = NotesStore.shared.createNote(
            title: "Sprint Release Plan",
            content: initialContent,
            color: .green,
            at: CGPoint(x: 650, y: 400)
        )
        note.isPrivate = false
        note.frameX = 650
        note.frameY = 400
        note.frameWidth = 340
        note.frameHeight = 340
        NotesStore.shared.updateNote(note)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            StickyWindowManager.shared.bringAllToFront()
            guard let panel = NSApp.windows.first(where: { ($0 as? StickyPanel)?.noteId == note.id }) as? StickyPanel else {
                return
            }
            panel.setFrame(NSRect(x: 650, y: 400, width: 340, height: 340), display: true)
            panel.orderFrontRegardless()
            
            // At t = 1.0s, toggle item 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let idx = NotesStore.shared.notes.firstIndex(where: { $0.id == note.id }) {
                    NotesStore.shared.notes[idx].content = """
                    # Sprint Release Plan 🚀
                    
                    ## Deliverables
                    - [x] Complete local SQLite cache
                    - [ ] Write designated codesign requirement
                    - [ ] Test on-device Apple Vision OCR
                    
                    Command: `scripts/build_app.sh`
                    """
                }
            }
            
            // At t = 2.0s, toggle item 2
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if let idx = NotesStore.shared.notes.firstIndex(where: { $0.id == note.id }) {
                    NotesStore.shared.notes[idx].content = """
                    # Sprint Release Plan 🚀
                    
                    ## Deliverables
                    - [x] Complete local SQLite cache
                    - [x] Write designated codesign requirement
                    - [ ] Test on-device Apple Vision OCR
                    
                    Command: `scripts/build_app.sh`
                    """
                }
            }
            
            // At t = 3.0s, toggle item 3
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if let idx = NotesStore.shared.notes.firstIndex(where: { $0.id == note.id }) {
                    NotesStore.shared.notes[idx].content = """
                    # Sprint Release Plan 🚀
                    
                    ## Deliverables
                    - [x] Complete local SQLite cache
                    - [x] Write designated codesign requirement
                    - [x] Test on-device Apple Vision OCR
                    
                    Command: `scripts/build_app.sh`
                    """
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.4) {
                NSApp.terminate(nil)
            }
        }
    }
    
    public func runOCRDemo() {
        resetEnvironment()
        
        var note = NotesStore.shared.createNote(
            title: "Architecture Specs",
            content: "Drag or paste screenshots (⌘V) into this note to extract text with on-device Apple Vision OCR.",
            color: .blue,
            at: CGPoint(x: 650, y: 400)
        )
        note.isPrivate = false
        note.frameX = 650
        note.frameY = 400
        note.frameWidth = 340
        note.frameHeight = 340
        NotesStore.shared.updateNote(note)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            StickyWindowManager.shared.bringAllToFront()
            guard let panel = NSApp.windows.first(where: { ($0 as? StickyPanel)?.noteId == note.id }) as? StickyPanel else {
                return
            }
            panel.setFrame(NSRect(x: 650, y: 400, width: 340, height: 340), display: true)
            panel.orderFrontRegardless()
            
            // At t = 1.0s, show native image action menu inside note
            let sampleImg = NSImage(size: NSSize(width: 120, height: 80), flipped: false, drawingHandler: { rect in
                NSColor.systemIndigo.setFill()
                rect.fill()
                return true
            })
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let cv = panel.contentView {
                    NoteBodyContextMenu.showImageActionMenu(for: sampleImg, noteId: note.id, at: NSPoint(x: 170, y: 170), in: cv)
                }
            }
            
            // At t = 2.4s, dismiss menu and display extracted text + attachment
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                NSApp.sendAction(#selector(NSMenu.cancelTracking), to: nil, from: nil)
                
                if let idx = NotesStore.shared.notes.firstIndex(where: { $0.id == note.id }) {
                    let extracted = """
                    ## Architecture Specs ⚡
                    - 100% Offline & Local-First
                    - On-Device Apple Vision OCR
                    - Zero Network Telemetry
                    """
                    NotesStore.shared.notes[idx].content = extracted
                    _ = NotesStore.shared.addImageAttachment(to: note.id, image: sampleImg)
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.4) {
                NSApp.terminate(nil)
            }
        }
    }
    
    public func runSearchDemo() {
        resetEnvironment()
        
        var note1 = NotesStore.shared.createNote(
            title: "Sprint Goals 🚀",
            content: "• Deliver macOS native binary\n• Complete release checklist",
            color: .yellow,
            at: CGPoint(x: 250, y: 400)
        )
        note1.isPrivate = false
        note1.frameX = 250
        note1.frameY = 400
        NotesStore.shared.updateNote(note1)
        
        var note2 = NotesStore.shared.createNote(
            title: "Marketing Copy",
            content: "• Product tagline\n• Landing page draft",
            color: .pink,
            at: CGPoint(x: 1050, y: 400)
        )
        note2.isPrivate = false
        note2.frameX = 1050
        note2.frameY = 400
        NotesStore.shared.updateNote(note2)
        
        var note3 = NotesStore.shared.createNote(
            title: "Architecture Specs",
            content: "• 100% offline & local SQLite\n• On-device Apple Vision OCR",
            color: .blue,
            at: CGPoint(x: 650, y: 150)
        )
        note3.isPrivate = false
        note3.frameX = 650
        note3.frameY = 150
        NotesStore.shared.updateNote(note3)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            StickyWindowManager.shared.bringAllToFront()
            
            // Show Spotlight HUD Panel
            SearchNotesWindowController.shared.show()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.4) {
                NSApp.terminate(nil)
            }
        }
    }
}
