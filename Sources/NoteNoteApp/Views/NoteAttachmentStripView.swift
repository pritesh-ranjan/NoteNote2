import SwiftUI
import AppKit

public struct NoteAttachmentStripView: View {
    let noteId: UUID
    let attachments: [String]
    let onRemove: (String) -> Void
    
    public init(noteId: UUID, attachments: [String], onRemove: @escaping (String) -> Void) {
        self.noteId = noteId
        self.attachments = attachments
        self.onRemove = onRemove
    }
    
    public var body: some View {
        if attachments.isEmpty {
            EmptyView()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(attachments, id: \.self) { filename in
                        AttachmentThumbnailView(
                            noteId: noteId,
                            filename: filename,
                            onRemove: { onRemove(filename) }
                        )
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
            }
            .frame(height: 52)
        }
    }
}

private struct AttachmentThumbnailView: View {
    let noteId: UUID
    let filename: String
    let onRemove: () -> Void
    
    @State private var isHovered: Bool = false
    
    private var fileURL: URL {
        NotesStore.shared.attachmentURL(for: noteId, filename: filename)
    }
    
    private var loadedImage: NSImage? {
        NSImage(contentsOf: fileURL)
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                openInPreview()
            } label: {
                if let nsImage = loadedImage {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        )
                }
            }
            .buttonStyle(.plain)
            .help("Click to open in macOS Preview")
            
            // Delete attachment button on hover
            if isHovered {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.black.opacity(0.65)))
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
                .help("Delete image")
            }
        }
        .frame(width: 44, height: 44)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func openInPreview() {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        
        if let previewAppURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Preview") {
            NSWorkspace.shared.open(
                [url],
                withApplicationAt: previewAppURL,
                configuration: NSWorkspace.OpenConfiguration(),
                completionHandler: nil
            )
        } else {
            NSWorkspace.shared.open(url)
        }
    }
}
