import SwiftUI
import AppKit

@MainActor
public struct QuickAddView: View {
    let onDismiss: () -> Void
    
    @State private var text: String = ""
    @State private var selectedColor: NoteColor = NoteColor.allCases.randomElement() ?? .yellow
    
    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "note.text")
                        .foregroundColor(selectedColor.dotColor)
                        .font(.subheadline.bold())
                    Text("Quick Add Sticky")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Color selector pills
                HStack(spacing: 6) {
                    ForEach(NoteColor.allCases) { color in
                        Button {
                            selectedColor = color
                        } label: {
                            Circle()
                                .fill(color.dotColor)
                                .frame(width: 14, height: 14)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: selectedColor == color ? 2 : 0)
                                )
                        }
                        .buttonStyle(.plain)
                    }
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
            .padding(.top, 14)
            .padding(.bottom, 10)
            
            // Text Input Area with Native Focus Handling
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Type a quick thought, todo, meeting note, or paste Markdown...")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.4))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                
                QuickAddTextEditor(
                    text: $text,
                    onCommit: { openFloating in
                        saveNote(openFloating: openFloating)
                    },
                    onCancel: {
                        onDismiss()
                    }
                )
                .padding(.horizontal, 12)
                .frame(minHeight: 80, maxHeight: 110)
            }
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            // Bottom bar with shortcut guide
            HStack {
                HStack(spacing: 12) {
                    ShortcutBadgeView(key: "Esc", label: "Cancel")
                    ShortcutBadgeView(key: "⌘↵", label: "Save & Open")
                    ShortcutBadgeView(key: "↵", label: "Save Note")
                }
                
                Spacer()
                
                Button("Save") {
                    saveNote(openFloating: false)
                }
                .buttonStyle(.borderedProminent)
                .tint(selectedColor.accentColor)
                .controlSize(.small)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .spotlightHUDStyle()
        .onAppear {
            selectedColor = NoteColor.allCases.randomElement() ?? .yellow
        }
    }
    
    @MainActor
    private func saveNote(openFloating: Bool) {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            onDismiss()
            return
        }
        
        let newNote = NotesStore.shared.createNote(
            content: content,
            color: selectedColor
        )
        
        if openFloating {
            StickyWindowManager.shared.focusNote(id: newNote.id)
        }
        
        onDismiss()
    }
}

// MARK: - Native AppKit NSTextView Representable for QuickAdd
private struct QuickAddTextEditor: NSViewRepresentable {
    @Binding var text: String
    var onCommit: (Bool) -> Void
    var onCancel: () -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        
        let contentSize = scrollView.contentSize
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        
        let textContainer = NSTextContainer(containerSize: NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)
        
        let textView = QuickAddCommandTextView(frame: NSRect(origin: .zero, size: contentSize), textContainer: textContainer)
        textView.minSize = NSSize(width: 0.0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        textView.textColor = .white
        textView.insertionPointColor = .white
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 4, height: 4)
        
        textView.onCommit = onCommit
        textView.onCancel = onCancel
        
        scrollView.documentView = textView
        context.coordinator.textView = textView
        
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? QuickAddCommandTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: QuickAddTextEditor
        weak var textView: QuickAddCommandTextView?
        
        init(_ parent: QuickAddTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

private class QuickAddCommandTextView: NSTextView {
    var onCommit: ((Bool) -> Void)?
    var onCancel: (() -> Void)?
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.window?.makeFirstResponder(self)
            }
        }
    }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isControl = flags.contains(.control) && !flags.contains(.option)
        let isCommand = flags.contains(.command) && !flags.contains(.option)
        let isShift = flags.contains(.shift)
        let key = event.charactersIgnoringModifiers?.lowercased()
        
        if isControl || isCommand {
            if key == "c" && !isShift {
                let sel = self.selectedRange()
                if sel.length > 0 {
                    let str = (self.string as NSString).substring(with: sel)
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(str, forType: .string)
                    return true
                }
            }
            if key == "v" && !isShift {
                let pasteboard = NSPasteboard.general
                if let text = pasteboard.string(forType: .string) {
                    let sel = self.selectedRange()
                    if self.shouldChangeText(in: sel, replacementString: text) {
                        self.replaceCharacters(in: sel, with: text)
                        self.didChangeText()
                        self.setSelectedRange(NSRange(location: sel.location + (text as NSString).length, length: 0))
                        self.delegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: self))
                        return true
                    }
                }
            }
            if key == "x" && !isShift {
                let sel = self.selectedRange()
                if sel.length > 0 {
                    let str = (self.string as NSString).substring(with: sel)
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(str, forType: .string)
                    if self.shouldChangeText(in: sel, replacementString: "") {
                        self.replaceCharacters(in: sel, with: "")
                        self.didChangeText()
                        self.delegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: self))
                        return true
                    }
                }
            }
            if key == "a" && !isShift {
                let len = (self.string as NSString).length
                self.setSelectedRange(NSRange(location: 0, length: len))
                return true
            }
            if key == "z" {
                if isShift {
                    self.undoManager?.redo()
                } else {
                    self.undoManager?.undo()
                }
                self.delegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: self))
                return true
            }
            if key == "b" && !isShift {
                MarkdownRenderer.toggleFormatting(in: self, type: .bold)
                self.delegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: self))
                return true
            }
            if key == "i" && !isShift {
                MarkdownRenderer.toggleFormatting(in: self, type: .italic)
                self.delegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: self))
                return true
            }
            if key == "u" && !isShift {
                MarkdownRenderer.toggleFormatting(in: self, type: .underline)
                self.delegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: self))
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onCancel?()
            return
        }
        if event.keyCode == 36 { // Return
            if event.modifierFlags.contains(.command) {
                onCommit?(true)
                return
            } else if !event.modifierFlags.contains(.shift) {
                onCommit?(false)
                return
            }
        }
        super.keyDown(with: event)
    }
}
