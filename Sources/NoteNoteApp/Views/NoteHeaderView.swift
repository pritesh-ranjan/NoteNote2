import SwiftUI
import AppKit

@MainActor
public struct NoteHeaderView: View {
    @Binding var note: NoteModel
    let onNewNote: () -> Void
    let onDelete: () -> Void
    let onLockNow: () -> Void
    let onTogglePrivate: () -> Void
    let onTogglePin: () -> Void
    let onShowAppPicker: () -> Void
    
    @State private var isHovering = false
    @State private var isCloseHovered = false
    @State private var isNewNoteHovered = false
    
    private var showButtons: Bool {
        isHovering || note.isHeaderHovered
    }
    
    public init(
        note: Binding<NoteModel>,
        onNewNote: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onLockNow: @escaping () -> Void,
        onTogglePrivate: @escaping () -> Void,
        onTogglePin: @escaping () -> Void,
        onShowAppPicker: @escaping () -> Void
    ) {
        self._note = note
        self.onNewNote = onNewNote
        self.onDelete = onDelete
        self.onLockNow = onLockNow
        self.onTogglePrivate = onTogglePrivate
        self.onTogglePin = onTogglePin
        self.onShowAppPicker = onShowAppPicker
    }
    
    public var body: some View {
        WindowDragArea {
            HStack(spacing: 6) {
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
                
                // 3. Linked App Indicator Badge (if note is bound to a specific app)
                if let appName = note.linkedAppName, !appName.isEmpty {
                    Button(action: onShowAppPicker) {
                        HStack(spacing: 3) {
                            Image(systemName: "link")
                                .font(.system(size: 8, weight: .bold))
                            Text(appName)
                                .font(.system(size: 9, weight: .medium))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(note.color.textColor.opacity(0.09))
                        .cornerRadius(5)
                        .foregroundColor(note.color.textColor.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                    .help("Linked to \(appName) (Click to change or unlink)")
                }
                
                Spacer()
                
                // Right action buttons (Link App, Privacy Shield, Pin, Lock)
                HStack(spacing: 4) {
                    // Link App Button (shown on hover if note not already linked)
                    if note.linkedAppBundleId == nil || note.linkedAppBundleId?.isEmpty == true {
                        HeaderIconButton(
                            icon: "link",
                            isActive: false,
                            accentColor: note.color.accentColor,
                            baseColor: note.color.textColor,
                            help: "Link Note to an Application...",
                            isVisible: showButtons,
                            action: onShowAppPicker
                        )
                    }
                    
                    // Screen Privacy Shield Toggle
                    HeaderIconButton(
                        icon: note.isPrivate ? "shield.fill" : "shield",
                        isActive: note.isPrivate,
                        accentColor: note.color.accentColor,
                        baseColor: note.color.textColor,
                        help: note.isPrivate ? "Screen Privacy Shield Active (Click to disable)" : "Enable Screen Privacy Shield",
                        isVisible: note.isPrivate || showButtons,
                        action: onTogglePrivate
                    )
                    
                    // Pin / Always on Top Toggle Button
                    HeaderIconButton(
                        icon: note.isPinned ? "pin.fill" : "pin",
                        isActive: note.isPinned,
                        accentColor: note.color.accentColor,
                        baseColor: note.color.textColor,
                        help: note.isPinned ? "Pinned on Top (Click to unpin, or press ⌘P)" : "Pin Note (Stay Always on Top, or press ⌘P)",
                        isVisible: note.isPinned || showButtons,
                        action: onTogglePin
                    )
                    
                    // Touch ID Lock indicator/button (only when protected)
                    if note.isLocked {
                        HeaderIconButton(
                            icon: "lock.fill",
                            isActive: true,
                            accentColor: note.color.accentColor,
                            baseColor: note.color.textColor,
                            help: "Protected Note (Click to lock now, or press ⌘L)",
                            isVisible: showButtons,
                            action: onLockNow
                        )
                    }
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: showButtons)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .noteHeaderContextMenu(noteId: note.id)
        }
        .frame(height: 32)
        .contentShape(Rectangle())
        .onHover { hovering in
            self.isHovering = hovering
        }
    }
}

// MARK: - Header Icon Button Subview
private struct HeaderIconButton: View {
    let icon: String
    let isActive: Bool
    let accentColor: Color
    let baseColor: Color
    let help: String
    let isVisible: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: isActive ? .semibold : .medium))
                .foregroundColor(isActive ? accentColor : baseColor.opacity(isHovered ? 0.9 : 0.5))
                .scaleEffect(isHovered ? 1.15 : 1.0)
                .animation(.easeInOut(duration: 0.12), value: isHovered)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { isHovered = $0 }
        .opacity(isVisible ? 1.0 : 0.0)
        .allowsHitTesting(isVisible)
    }
}
