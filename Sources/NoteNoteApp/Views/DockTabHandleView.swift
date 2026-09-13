import SwiftUI
import AppKit

public struct DockTabHandleView: View {
    let note: NoteModel
    let onUndock: () -> Void
    
    @State private var isHovering = false
    
    public init(note: NoteModel, onUndock: @escaping () -> Void) {
        self.note = note
        self.onUndock = onUndock
    }
    
    public var body: some View {
        WindowDragArea {
            HStack(spacing: 8) {
                // Color strip
                Rectangle()
                    .fill(note.color.dotColor)
                    .frame(width: 4)
                    .cornerRadius(2)
                
                Image(systemName: "note.text")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(note.color.accentColor)
                
                Text(note.displayTitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(note.color.textColor)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: onUndock) {
                    Image(systemName: note.dockEdge == .right ? "chevron.left.2" : "chevron.right.2")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(note.color.secondaryTextColor)
                        .padding(4)
                        .background(
                            Circle()
                                .fill(isHovering ? note.color.accentColor.opacity(0.15) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .help("Undock Note")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(note.color.backgroundColor)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(note.color.borderColor, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
            }
            .onTapGesture(count: 2) {
                onUndock()
            }
        }
    }
}
