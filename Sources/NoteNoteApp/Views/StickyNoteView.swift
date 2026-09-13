import SwiftUI
import AppKit

public struct StickyNoteView: View {
    let noteId: UUID
    @StateObject private var store = NotesStore.shared
    @State private var isUnlocked: Bool = false
    @State private var showingImagePicker: Bool = false
    
    public init(noteId: UUID) {
        self.noteId = noteId
    }
    
    private var noteIndex: Int? {
        store.notes.firstIndex(where: { $0.id == noteId })
    }
    
    public var body: some View {
        Group {
            if let idx = noteIndex {
                let noteBinding = $store.notes[idx]
                let note = store.notes[idx]
                
                Group {
                    if note.isDocked {
                        // Collapsed Edge Tab
                        DockTabHandleView(note: note) {
                            store.toggleDock(id: note.id)
                        }
                    } else if note.isLocked && !isUnlocked {
                        // Biometric Lock Screen (Touch ID protected)
                        lockedView(for: noteBinding)
                    } else if note.isImageNote {
                        // Floating Image Overlay
                        ImageOverlayView(
                            note: noteBinding,
                            onDelete: { store.deleteNote(id: note.id) },
                            onTogglePrivate: { store.togglePrivate(id: note.id) }
                        )
                    } else {
                        // Standard Sticky Note View
                        standardNoteView(for: noteBinding)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: note.isDocked ? 10 : 14))
            } else {
                EmptyView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleNoteLock)) { notification in
            guard let targetId = notification.object as? UUID, targetId == noteId else { return }
            handleLockShortcutAction()
        }
    }
    
    @ViewBuilder
    private func standardNoteView(for note: Binding<NoteModel>) -> some View {
        VStack(spacing: 0) {
            NoteHeaderView(
                note: note,
                onNewNote: {
                    let posX = note.wrappedValue.frameX + 32
                    let posY = note.wrappedValue.frameY - 32
                    _ = store.createNote(at: CGPoint(x: posX, y: posY))
                },
                onColorChange: { newColor in
                    note.wrappedValue.color = newColor
                    store.requestSave()
                },
                onDelete: {
                    store.deleteNote(id: note.wrappedValue.id)
                },
                onLockNow: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.isUnlocked = false
                    }
                    store.setLocked(id: note.wrappedValue.id, locked: true)
                },
                onRemoveLock: {
                    store.setLocked(id: note.wrappedValue.id, locked: false)
                }
            )
            
            NoteEditorView(
                content: note.content,
                fontSize: note.fontSize,
                noteColor: note.wrappedValue.color,
                onContentChanged: {
                    store.requestSave()
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                if note.wrappedValue.color == .glass {
                    VisualEffectView(material: .popover, blendingMode: .behindWindow)
                } else {
                    note.wrappedValue.color.backgroundColor
                }
            }
        )
    }
    
    @ViewBuilder
    private func lockedView(for note: Binding<NoteModel>) -> some View {
        VStack(spacing: 16) {
            WindowDragArea {
                HStack(spacing: 7) {
                    // No delete button on locked notes — prevents accidental deletion
                    // while the note content is protected.
                    
                    Text("Locked Note")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(note.wrappedValue.color.textColor.opacity(0.6))
                    
                    Spacer()
                }
                .padding(.horizontal, 10)
                .frame(height: 32)
            }
            
            Spacer()
            
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 42))
                .foregroundColor(note.wrappedValue.color.accentColor)
            
            VStack(spacing: 6) {
                Text(note.wrappedValue.displayTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(note.wrappedValue.color.textColor)
                    .lineLimit(1)
                
                Text("This note is protected with Touch ID")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(note.wrappedValue.color.textColor.opacity(0.65))
            }
            
            Button {
                unlockNote()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "touchid")
                        .font(.system(size: 13, weight: .medium))
                    Text("Unlock Note")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
            }
            .buttonStyle(.borderedProminent)
            .tint(note.wrappedValue.color.accentColor)
            
            Spacer()
        }
        .padding(12)
        .background(
            ZStack {
                if note.wrappedValue.color == .glass {
                    VisualEffectView(material: .popover, blendingMode: .behindWindow)
                } else {
                    note.wrappedValue.color.backgroundColor
                }
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow).opacity(0.35)
            }
        )
    }
    
    private func handleLockShortcutAction() {
        guard let idx = noteIndex else { return }
        let currentNote = store.notes[idx]
        
        if !currentNote.isLocked {
            // Note is not locked -> Lock it immediately
            store.setLocked(id: noteId, locked: true)
            withAnimation(.easeInOut(duration: 0.2)) {
                self.isUnlocked = false
            }
        } else if isUnlocked {
            // Note is locked and currently revealed -> Lock it immediately
            withAnimation(.easeInOut(duration: 0.2)) {
                self.isUnlocked = false
            }
        } else {
            // Note is locked and showing lock screen -> Trigger Touch ID prompt
            unlockNote()
        }
    }
    
    private func unlockNote() {
        Task {
            let success = await TouchIDService.shared.authenticate()
            if success {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.isUnlocked = true
                    }
                }
            }
        }
    }
    
    private func pickImageAttachment(for id: UUID) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .png, .jpeg]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK, let url = panel.url {
            if let idx = store.notes.firstIndex(where: { $0.id == id }) {
                store.notes[idx].imageAttachmentPath = url.path
                store.notes[idx].isImageNote = true
                store.requestSave()
            }
        }
    }
}

// MARK: - AppKit VisualEffectView wrapper for macOS vibrancy
public struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    public init(
        material: NSVisualEffectView.Material = .popover,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    ) {
        self.material = material
        self.blendingMode = blendingMode
    }
    
    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
