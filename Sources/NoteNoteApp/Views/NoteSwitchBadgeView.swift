import SwiftUI

/// Transient floating badge that appears when cycling notes via gesture or keyboard shortcuts
public struct NoteSwitchBadgeView: View {
    let feedback: NoteSwitchFeedback
    let noteColor: NoteColor
    
    public init(feedback: NoteSwitchFeedback, noteColor: NoteColor) {
        self.feedback = feedback
        self.noteColor = noteColor
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "hand.draw.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(noteColor.accentColor)
            
            Text("\(feedback.index) of \(feedback.total)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(noteColor.textColor)
            
            if !feedback.title.isEmpty && feedback.title != "Untitled Note" {
                Text("•")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(noteColor.secondaryTextColor.opacity(0.6))
                
                Text(feedback.title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(noteColor.textColor)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                noteColor.backgroundColor.opacity(0.9)
            }
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(noteColor.accentColor.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 3)
    }
}
