import SwiftUI
import AppKit

@MainActor
public struct TrashView: View {
    @ObservedObject private var store = NotesStore.shared
    @State private var showingEmptyConfirmation = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(Color(red: 0.95, green: 0.40, blue: 0.35))
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Trash & Note Recovery")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("Recover deleted stickies back to your desktop, or remove them permanently.")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !store.deletedNotes.isEmpty {
                    HStack(spacing: 8) {
                        Button {
                            store.restoreAllNotes()
                        } label: {
                            Label("Restore All", systemImage: "arrow.uturn.backward")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button(role: .destructive) {
                            showingEmptyConfirmation = true
                        } label: {
                            Label("Empty Trash", systemImage: "trash")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0.85, green: 0.30, blue: 0.30))
                        .controlSize(.small)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Content
            if store.deletedNotes.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "trash")
                        .font(.system(size: 44, weight: .light))
                        .foregroundColor(Color.secondary.opacity(0.4))
                    Text("Trash is Empty")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                    Text("Sticky notes you delete will be safely kept here for recovery.")
                        .font(.system(size: 12))
                        .foregroundColor(Color.secondary.opacity(0.7))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(store.deletedNotes) { note in
                            TrashNoteCard(note: note)
                        }
                    }
                    .padding(16)
                }
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            }
            
            Divider()
            
            // Footer
            HStack {
                Text("\(store.deletedNotes.count) \(store.deletedNotes.count == 1 ? "deleted note" : "deleted notes")")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Notes in trash can be restored anytime")
                    .font(.system(size: 11))
                    .foregroundColor(Color.secondary.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 540, minHeight: 400)
        .confirmationDialog(
            "Empty Trash?",
            isPresented: $showingEmptyConfirmation,
            titleVisibility: .visible
        ) {
            Button("Empty Trash Permanently", role: .destructive) {
                store.emptyTrash()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to permanently delete all \(store.deletedNotes.count) notes from the trash? This action cannot be undone.")
        }
    }
}

// MARK: - Trash Note Card Row
@MainActor
private struct TrashNoteCard: View {
    let note: NoteModel
    @ObservedObject private var store = NotesStore.shared
    @State private var isHovered = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Note Color Strip
            RoundedRectangle(cornerRadius: 3)
                .fill(note.color.dotColor)
                .frame(width: 5)
                .padding(.vertical, 2)
            
            // Note Details
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(note.displayTitle)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let appName = note.linkedAppName, !appName.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "link")
                                .font(.system(size: 8))
                            Text(appName)
                                .font(.system(size: 9, weight: .medium))
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(4)
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if let delDate = note.deletedAt {
                        Text("Deleted \(delDate.relativeTimeString)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Content Snippet
                let preview = notePreview(note.content)
                if !preview.isEmpty {
                    Text(preview)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            // Action Buttons
            HStack(spacing: 6) {
                Button {
                    store.restoreNote(id: note.id)
                } label: {
                    Label("Restore", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .tint(.accentColor)
                .controlSize(.small)
                .help("Restore this note to desktop")
                
                Button(role: .destructive) {
                    store.permanentlyDeleteNote(id: note.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(Color.red.opacity(0.85))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Delete permanently")
            }
            .padding(.leading, 4)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovered ? Color.secondary.opacity(0.3) : Color.secondary.opacity(0.12), lineWidth: 1)
        )
        .onHover { isHovered = $0 }
    }
    
    private func notePreview(_ content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
            .map { $0.cleanMarkdownStripped }
            .filter { !$0.isEmpty }
        return lines.prefix(2).joined(separator: " • ")
    }
}
