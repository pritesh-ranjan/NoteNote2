import SwiftUI
import AppKit

public struct NoteHeaderView: View {
    @Binding var note: NoteModel
    let onNewNote: () -> Void
    let onColorChange: (NoteColor) -> Void
    let onDelete: () -> Void
    let onLockNow: () -> Void
    let onRemoveLock: () -> Void
    
    @State private var isHovering = false
    @State private var isCloseHovered = false
    @State private var isNewNoteHovered = false
    @State private var isLockHovered = false
    
    private var showButtons: Bool {
        isHovering
    }
    
    public init(
        note: Binding<NoteModel>,
        onNewNote: @escaping () -> Void,
        onColorChange: @escaping (NoteColor) -> Void,
        onDelete: @escaping () -> Void,
        onLockNow: @escaping () -> Void,
        onRemoveLock: @escaping () -> Void
    ) {
        self._note = note
        self.onNewNote = onNewNote
        self.onColorChange = onColorChange
        self.onDelete = onDelete
        self.onLockNow = onLockNow
        self.onRemoveLock = onRemoveLock
    }
    
    public var body: some View {
        WindowDragArea {
            HStack(spacing: 7) {
                // Left action buttons (Close, New Note)
                HStack(spacing: 7) {
                    // 1. Delete / Close Button
                    Button(action: onDelete) {
                        Circle()
                            .fill(isCloseHovered ? Color.red : Color.red.opacity(0.85))
                            .frame(width: 12, height: 12)
                            .overlay(
                                Image(systemName: "xmark")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundColor(.white)
                                    .opacity(isCloseHovered ? 1.0 : 0.8)
                            )
                            .scaleEffect(isCloseHovered ? 1.15 : 1.0)
                            .animation(.easeInOut(duration: 0.12), value: isCloseHovered)
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Delete Sticky Note")
                    .onHover { isCloseHovered = $0 }
                    
                    // 2. New Note (+) Button
                    Button(action: onNewNote) {
                        Circle()
                            .fill(isNewNoteHovered ? Color.black.opacity(0.18) : Color.black.opacity(0.08))
                            .frame(width: 12, height: 12)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundColor(note.color.textColor.opacity(0.85))
                            )
                            .scaleEffect(isNewNoteHovered ? 1.15 : 1.0)
                            .animation(.easeInOut(duration: 0.12), value: isNewNoteHovered)
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("New Sticky Note")
                    .onHover { isNewNoteHovered = $0 }
                }
                .opacity(showButtons ? 1.0 : 0.0)
                .scaleEffect(showButtons ? 1.0 : 0.6, anchor: .leading)
                .allowsHitTesting(showButtons)
                
                Spacer()
                
                // 3. Lock indicator/button (only when protected with Touch ID)
                if note.isLocked {
                    Button(action: onLockNow) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(note.color.accentColor)
                            .scaleEffect(isLockHovered ? 1.15 : 1.0)
                            .animation(.easeInOut(duration: 0.12), value: isLockHovered)
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Protected Note (Click to lock now, or press ⌘L)")
                    .onHover { isLockHovered = $0 }
                    .opacity(showButtons ? 1.0 : 0.0)
                    .scaleEffect(showButtons ? 1.0 : 0.6, anchor: .trailing)
                    .allowsHitTesting(showButtons)
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: showButtons)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .contextMenu {
                ForEach(NoteColor.allCases) { color in
                    Button {
                        onColorChange(color)
                    } label: {
                        if note.color == color {
                            Label(color.displayName, systemImage: "checkmark")
                        } else {
                            Text(color.displayName)
                        }
                    }
                }
            }
        }
        .frame(height: 32)
        .contentShape(Rectangle())
        .onHover { hovering in
            self.isHovering = hovering
        }
    }
}
