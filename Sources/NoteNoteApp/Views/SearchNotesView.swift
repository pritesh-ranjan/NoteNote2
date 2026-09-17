import SwiftUI
import AppKit

@MainActor
public struct SearchNotesView: View {
    let onDismiss: () -> Void
    
    @ObservedObject private var store = NotesStore.shared
    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    
    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }
    
    private var filteredNotes: [NoteModel] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.isEmpty {
            return store.notes
        }
        return store.notes.filter { note in
            if note.title.lowercased().contains(trimmed) { return true }
            if note.content.lowercased().contains(trimmed) { return true }
            if note.color.displayName.lowercased().contains(trimmed) { return true }
            if let appName = note.linkedAppName, appName.lowercased().contains(trimmed) { return true }
            return false
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // 1. Search Bar Header
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.35, green: 0.75, blue: 1.0))
                
                SearchInputField(
                    text: $query,
                    onMoveSelection: { delta in
                        moveSelection(delta: delta)
                    },
                    onCommit: {
                        openSelectedNote()
                    },
                    onCancel: {
                        onDismiss()
                    }
                )
                
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                
                Text("Esc")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.4))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            // 2. Search Results List
            let notes = filteredNotes
            if notes.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(Color.white.opacity(0.3))
                    Text("No stickies match \"\(query)\"")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.5))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
                                SearchResultRow(
                                    note: note,
                                    query: query,
                                    isSelected: index == selectedIndex,
                                    onSelect: {
                                        selectedIndex = index
                                        openNote(note)
                                    }
                                )
                                .id(index)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onChange(of: selectedIndex) { _, newIndex in
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            // 3. Footer Bar
            HStack(spacing: 12) {
                Text(query.isEmpty ? "\(notes.count) stickies" : "\(notes.count) \(notes.count == 1 ? "result" : "results")")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.45))
                
                Spacer()
                
                ShortcutBadgeView(key: "↑↓", label: "Navigate")
                ShortcutBadgeView(key: "↵", label: "Open Sticky")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .spotlightHUDStyle()
        .onChange(of: query) { _, _ in
            selectedIndex = 0
        }
    }
    
    private func moveSelection(delta: Int) {
        let count = filteredNotes.count
        guard count > 0 else { return }
        selectedIndex = max(0, min(count - 1, selectedIndex + delta))
    }
    
    private func openSelectedNote() {
        let notes = filteredNotes
        guard selectedIndex >= 0 && selectedIndex < notes.count else { return }
        openNote(notes[selectedIndex])
    }
    
    private func openNote(_ note: NoteModel) {
        onDismiss()
        StickyWindowManager.shared.focusNote(id: note.id)
    }
}

// MARK: - Search Result Row
@MainActor
private struct SearchResultRow: View {
    let note: NoteModel
    let query: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                // Note Color Dot
                Circle()
                    .fill(note.color.dotColor)
                    .frame(width: 10, height: 10)
                    .shadow(color: note.color.dotColor.opacity(0.4), radius: 3)
                
                // Title and Match Snippet
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(note.displayTitle)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        if note.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 9))
                                .foregroundColor(Color(red: 0.98, green: 0.82, blue: 0.2))
                        }
                        
                        if note.isPrivate {
                            Image(systemName: "shield.fill")
                                .font(.system(size: 9))
                                .foregroundColor(Color(red: 0.35, green: 0.75, blue: 1.0))
                        }
                        
                        if note.isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        if let appName = note.linkedAppName, !appName.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "link")
                                    .font(.system(size: 8))
                                Text(appName)
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(4)
                            .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    // Snippet Text
                    let snippet = findSnippet(in: note.content, query: query)
                    if !snippet.isEmpty {
                        Text(snippet)
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundColor(Color.white.opacity(0.55))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Relative Update Time
                Text(note.updatedAt.relativeTimeString)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.35))
                
                // Return Icon indicator on selection
                if isSelected {
                    Image(systemName: "return")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isSelected
                            ? Color(red: 0.20, green: 0.45, blue: 0.95).opacity(0.55)
                            : (isHovered ? Color.white.opacity(0.06) : Color.clear)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color(red: 0.35, green: 0.65, blue: 1.0).opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func findSnippet(in content: String, query: String) -> String {
        let trimmedQ = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let lines = content.components(separatedBy: .newlines)
        
        if !trimmedQ.isEmpty {
            for line in lines {
                if line.lowercased().contains(trimmedQ) {
                    let clean = line.cleanMarkdownStripped
                    if !clean.isEmpty {
                        return clean
                    }
                }
            }
        }
        
        // Default snippet: first non-empty line
        for line in lines {
            let clean = line.cleanMarkdownStripped
            if !clean.isEmpty {
                return clean
            }
        }
        return ""
    }
}

// MARK: - Native AppKit Search Input Field with Arrow & Enter Handling
private struct SearchInputField: NSViewRepresentable {
    @Binding var text: String
    let onMoveSelection: (Int) -> Void
    let onCommit: () -> Void
    let onCancel: () -> Void
    
    func makeNSView(context: Context) -> SearchTextField {
        let field = SearchTextField()
        field.placeholderString = "Search notes, checklists, text, linked apps..."
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 15, weight: .regular)
        field.textColor = .white
        field.delegate = context.coordinator
        
        DispatchQueue.main.async {
            field.window?.makeFirstResponder(field)
        }
        return field
    }
    
    func updateNSView(_ nsView: SearchTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: SearchInputField
        
        init(_ parent: SearchInputField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let field = obj.object as? NSTextField {
                parent.text = field.stringValue
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.moveDown(_:)) {
                parent.onMoveSelection(1)
                return true
            }
            if commandSelector == #selector(NSResponder.moveUp(_:)) {
                parent.onMoveSelection(-1)
                return true
            }
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onCommit()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onCancel()
                return true
            }
            return false
        }
    }
}

private final class SearchTextField: NSTextField {
    // Custom field if needed
}
