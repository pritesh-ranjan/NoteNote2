import SwiftUI
import AppKit

public struct ImageOverlayView: View {
    @Binding var note: NoteModel
    let onDelete: () -> Void
    let onTogglePrivate: () -> Void
    
    @State private var isHovering = false
    
    public init(
        note: Binding<NoteModel>,
        onDelete: @escaping () -> Void,
        onTogglePrivate: @escaping () -> Void
    ) {
        self._note = note
        self.onDelete = onDelete
        self.onTogglePrivate = onTogglePrivate
    }
    
    private var nsImage: NSImage? {
        guard let path = note.imageAttachmentPath, FileManager.default.fileExists(atPath: path) else {
            return nil
        }
        return NSImage(contentsOfFile: path)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            WindowDragArea {
                HStack(spacing: 8) {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(isHovering ? .red : .secondary)
                    }
                    .buttonStyle(.plain)
                    
                    Text(note.displayTitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Opacity slider
                    HStack(spacing: 4) {
                        Image(systemName: "circle.lefthalf.filled")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Slider(value: $note.opacity, in: 0.2...1.0)
                            .frame(width: 60)
                            .controlSize(.mini)
                            .onChange(of: note.opacity) { _, _ in
                                NotesStore.shared.updateNote(note)
                            }
                    }
                    
                    // Click-through toggle
                    Button {
                        note.isClickThrough.toggle()
                        NotesStore.shared.updateNote(note)
                    } label: {
                        Image(systemName: note.isClickThrough ? "cursorarrow.slash" : "cursorarrow")
                            .font(.system(size: 11))
                            .foregroundColor(note.isClickThrough ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(note.isClickThrough ? "Click-through Active" : "Enable Click-through")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.85))
            }
            
            // Image Content
            GeometryReader { geo in
                if let image = nsImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .cornerRadius(6)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("Image not found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(6)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onHover { isHovering = $0 }
    }
}
