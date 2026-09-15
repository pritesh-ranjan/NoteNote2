import SwiftUI
import AppKit

public struct NoteHeaderView: View {
    @Binding var note: NoteModel
    let onNewNote: () -> Void
    let onColorChange: (NoteColor) -> Void
    let onDelete: () -> Void
    let onLockNow: () -> Void
    let onRemoveLock: () -> Void
    let onTogglePrivate: () -> Void
    let onShowAppPicker: () -> Void
    
    @State private var isHovering = false
    @State private var isCloseHovered = false
    @State private var isNewNoteHovered = false
    @State private var isLockHovered = false
    @State private var isShieldHovered = false
    @State private var isLinkHovered = false
    
    private var showButtons: Bool {
        isHovering
    }
    
    public init(
        note: Binding<NoteModel>,
        onNewNote: @escaping () -> Void,
        onColorChange: @escaping (NoteColor) -> Void,
        onDelete: @escaping () -> Void,
        onLockNow: @escaping () -> Void,
        onRemoveLock: @escaping () -> Void,
        onTogglePrivate: @escaping () -> Void,
        onShowAppPicker: @escaping () -> Void
    ) {
        self._note = note
        self.onNewNote = onNewNote
        self.onColorChange = onColorChange
        self.onDelete = onDelete
        self.onLockNow = onLockNow
        self.onRemoveLock = onRemoveLock
        self.onTogglePrivate = onTogglePrivate
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
                
                // Right action buttons (Link App, Privacy Shield, Lock)
                HStack(spacing: 4) {
                    // 4. Link App Button (shown on hover if note not already linked)
                    if note.linkedAppBundleId == nil || note.linkedAppBundleId?.isEmpty == true {
                        Button(action: onShowAppPicker) {
                            Image(systemName: "link")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(note.color.textColor.opacity(isLinkHovered ? 0.9 : 0.5))
                                .scaleEffect(isLinkHovered ? 1.15 : 1.0)
                                .animation(.easeInOut(duration: 0.12), value: isLinkHovered)
                                .frame(width: 20, height: 20)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Link Note to an Application...")
                        .onHover { isLinkHovered = $0 }
                        .opacity(showButtons ? 1.0 : 0.0)
                        .allowsHitTesting(showButtons)
                    }
                    
                    // 5. Screen Privacy Shield Toggle
                    if note.isPrivate {
                        Button(action: onTogglePrivate) {
                            Image(systemName: "shield.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(note.color.accentColor)
                                .scaleEffect(isShieldHovered ? 1.15 : 1.0)
                                .animation(.easeInOut(duration: 0.12), value: isShieldHovered)
                                .frame(width: 20, height: 20)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Screen Privacy Shield Active (Click to disable)")
                        .onHover { isShieldHovered = $0 }
                    } else {
                        Button(action: onTogglePrivate) {
                            Image(systemName: "shield")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(note.color.textColor.opacity(isShieldHovered ? 0.9 : 0.5))
                                .scaleEffect(isShieldHovered ? 1.15 : 1.0)
                                .animation(.easeInOut(duration: 0.12), value: isShieldHovered)
                                .frame(width: 20, height: 20)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Enable Screen Privacy Shield")
                        .onHover { isShieldHovered = $0 }
                        .opacity(showButtons ? 1.0 : 0.0)
                        .allowsHitTesting(showButtons)
                    }
                    
                    // 6. Touch ID Lock indicator/button (only when protected)
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
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: showButtons)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .contextMenu {
                // Color Themes
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
                
                Divider()
                
                // Screen Privacy Shield
                Button(action: onTogglePrivate) {
                    if note.isPrivate {
                        Label("Privacy Shield: Enabled", systemImage: "shield.fill")
                    } else {
                        Label("Privacy Shield: Disabled", systemImage: "shield")
                    }
                }
                
                // App-Aware Linking
                if let appName = note.linkedAppName, !appName.isEmpty {
                    Button(action: onShowAppPicker) {
                        Label("Change Linked App (\(appName))...", systemImage: "link")
                    }
                    Button {
                        NotesStore.shared.setLinkedApp(id: note.id, bundleId: nil, appName: nil)
                    } label: {
                        Label("Unlink from \(appName)", systemImage: "link.badge.plus")
                    }
                } else {
                    Button(action: onShowAppPicker) {
                        Label("Link to Application...", systemImage: "link")
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
