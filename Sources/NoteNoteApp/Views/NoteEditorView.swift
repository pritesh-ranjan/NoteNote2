import SwiftUI
import AppKit

public struct NoteEditorView: View {
    @Binding var content: String
    @Binding var fontSize: Double
    let noteColor: NoteColor
    let onContentChanged: () -> Void
    
    public init(
        content: Binding<String>,
        fontSize: Binding<Double> = .constant(13.0),
        noteColor: NoteColor,
        onContentChanged: @escaping () -> Void
    ) {
        self._content = content
        self._fontSize = fontSize
        self.noteColor = noteColor
        self.onContentChanged = onContentChanged
    }
    
    public var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                // Interactive Checklists Quick Bar if note has tasks
                if hasChecklistItems {
                    checklistSummaryView
                        .padding(.horizontal, 10)
                        .padding(.top, 4)
                        .padding(.bottom, 2)
                }
                
                ZStack(alignment: .topLeading) {
                    if content.isEmpty {
                        Text("Take a note...")
                            .font(.system(size: CGFloat(fontSize), weight: .regular, design: .rounded))
                            .foregroundColor(noteColor.secondaryTextColor.opacity(0.55))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                    
                    MacTextEditor(
                        text: $content,
                        fontSize: $fontSize,
                        noteColor: noteColor,
                        onChange: onContentChanged
                    )
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var hasChecklistItems: Bool {
        content.contains("- [ ]") || content.contains("- [x]") || content.contains("- [X]") ||
        content.contains("* [ ]") || content.contains("* [x]")
    }
    
    private var checklistSummaryView: some View {
        let lines = content.components(separatedBy: .newlines)
        let tasks = lines.enumerated().compactMap { (index, line) -> (index: Int, isChecked: Bool, title: String)? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- [ ]") || trimmed.hasPrefix("* [ ]") {
                let text = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                return (index, false, text)
            } else if trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("- [X]") || trimmed.hasPrefix("* [x]") || trimmed.hasPrefix("* [X]") {
                let text = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                return (index, true, text)
            }
            return nil
        }
        
        let completed = tasks.filter { $0.isChecked }.count
        let total = tasks.count
        
        return HStack(spacing: 8) {
            ProgressView(value: Double(completed), total: Double(max(1, total)))
                .progressViewStyle(.linear)
                .frame(maxWidth: 80)
                .tint(noteColor.accentColor)
            
            Text("\(completed)/\(total) done")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(noteColor.secondaryTextColor)
            
            Spacer()
            
            // Quick toggle first uncompleted task
            if let firstPending = tasks.first(where: { !$0.isChecked }) {
                Button {
                    toggleTask(at: firstPending.index)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                        Text("Check: \(firstPending.title.prefix(14))...")
                            .lineLimit(1)
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(noteColor.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(noteColor.accentColor.opacity(0.12))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(noteColor.isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
        )
    }
    
    private func toggleTask(at lineIndex: Int) {
        var lines = content.components(separatedBy: .newlines)
        guard lineIndex < lines.count else { return }
        let line = lines[lineIndex]
        
        if line.contains("- [ ]") {
            lines[lineIndex] = line.replacingOccurrences(of: "- [ ]", with: "- [x]")
        } else if line.contains("- [x]") || line.contains("- [X]") {
            lines[lineIndex] = line.replacingOccurrences(of: "- [x]", with: "- [ ]")
                .replacingOccurrences(of: "- [X]", with: "- [ ]")
        } else if line.contains("* [ ]") {
            lines[lineIndex] = line.replacingOccurrences(of: "* [ ]", with: "* [x]")
        } else if line.contains("* [x]") || line.contains("* [X]") {
            lines[lineIndex] = line.replacingOccurrences(of: "* [x]", with: "* [ ]")
                .replacingOccurrences(of: "* [X]", with: "* [ ]")
        }
        
        content = lines.joined(separator: "\n")
        onContentChanged()
    }
}

// MARK: - Native AppKit NSTextView Representable for responsive editing
public struct MacTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var fontSize: Double
    var noteColor: NoteColor
    var onChange: () -> Void
    
    public init(text: Binding<String>, fontSize: Binding<Double>, noteColor: NoteColor, onChange: @escaping () -> Void) {
        self._text = text
        self._fontSize = fontSize
        self.noteColor = noteColor
        self.onChange = onChange
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        
        let contentSize = scrollView.contentSize
        let textStorage = NSTextStorage()
        let layoutManager = StickyLayoutManager()
        layoutManager.noteColor = noteColor
        textStorage.addLayoutManager(layoutManager)
        
        let textContainer = NSTextContainer(containerSize: NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)
        
        let textView = StickyTextView(frame: NSRect(origin: .zero, size: contentSize), textContainer: textContainer)
        textView.minSize = NSSize(width: 0.0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.currentFontSize = CGFloat(fontSize)
        textView.font = NSFont.systemFont(ofSize: CGFloat(fontSize), weight: .regular)
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.importsGraphics = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.noteColor = noteColor
        
        textView.onFontSizeChanged = { [weak coordinator = context.coordinator] newSize in
            coordinator?.parent.fontSize = Double(newSize)
            coordinator?.parent.onChange()
        }
        
        scrollView.documentView = textView
        context.coordinator.textView = textView
        
        textView.string = text
        textView.renderMarkdown()
        return scrollView
    }
    
    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? StickyTextView else { return }
        
        let colorChanged = textView.noteColor != noteColor
        textView.noteColor = noteColor
        if let lm = textView.layoutManager as? StickyLayoutManager {
            lm.noteColor = noteColor
        }
        
        let fontChanged = abs(textView.currentFontSize - CGFloat(fontSize)) >= 0.5
        if fontChanged {
            textView.currentFontSize = CGFloat(fontSize)
            textView.font = NSFont.systemFont(ofSize: CGFloat(fontSize), weight: .regular)
        }
        
        if textView.string != text {
            textView.string = text
            textView.renderMarkdown()
        } else if colorChanged || fontChanged {
            textView.renderMarkdown()
        }
    }
    
    public class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacTextEditor
        weak var textView: StickyTextView?
        
        init(_ parent: MacTextEditor) {
            self.parent = parent
        }
        
        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? StickyTextView else { return }
            parent.text = textView.string
            parent.onChange()
        }
    }
}

// MARK: - Custom Layout Manager for Multiline Code Blocks & Visual Elements
public final class StickyLayoutManager: NSLayoutManager {
    public var noteColor: NoteColor = .yellow
    
    public override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
        
        guard let textStorage = self.textStorage else { return }
        guard let textContainer = self.textContainers.first else { return }
        
        let charLength = (textStorage.string as NSString).length
        guard charLength > 0 else { return }
        
        let isDark = noteColor.isDark
        let codeCardBg = isDark
            ? NSColor(white: 0.12, alpha: 0.78)
            : NSColor(white: 0.0, alpha: 0.06)
        let codeCardBorder = isDark
            ? NSColor(white: 1.0, alpha: 0.12)
            : NSColor(white: 0.0, alpha: 0.09)
        
        textStorage.enumerateAttribute(
            MarkdownRenderer.codeBlockAttribute,
            in: NSRange(location: 0, length: charLength),
            options: []
        ) { value, range, _ in
            guard value != nil else { return }
            
            let glyphRange = self.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            guard glyphRange.length > 0 else { return }
            
            let inter = NSIntersectionRange(glyphRange, glyphsToShow)
            guard inter.length > 0 else { return }
            
            let blockRect = self.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            
            let containerWidth = textContainer.size.width
            let cardX: CGFloat = 2.0
            let cardWidth = max(60, containerWidth - 4.0)
            let cardY = origin.y + blockRect.origin.y - 2.0
            let cardHeight = blockRect.size.height + 4.0
            
            let cardRect = NSRect(x: cardX, y: cardY, width: cardWidth, height: cardHeight)
            let path = NSBezierPath(roundedRect: cardRect, xRadius: 6, yRadius: 6)
            
            codeCardBg.setFill()
            path.fill()
            
            codeCardBorder.setStroke()
            path.lineWidth = 1.0
            path.stroke()
        }
    }
}

public final class StickyTextView: NSTextView {
    public var noteColor: NoteColor = .yellow {
        didSet {
            if let lm = self.layoutManager as? StickyLayoutManager {
                lm.noteColor = noteColor
            }
        }
    }
    public var currentFontSize: CGFloat = 13.0
    public var onFontSizeChanged: ((CGFloat) -> Void)?
    
    private var isRenderingMarkdown = false
    private var lastActiveLineRange: NSRange?
    
    public override var typingAttributes: [NSAttributedString.Key : Any] {
        get {
            let style = NSMutableParagraphStyle()
            style.lineSpacing = max(2.0, currentFontSize * 0.25)
            style.paragraphSpacing = max(2.0, currentFontSize * 0.22)
            return [
                .font: NSFont.systemFont(ofSize: currentFontSize, weight: .regular),
                .foregroundColor: noteColor.nsTextColor,
                .paragraphStyle: style
            ]
        }
        set {
            super.typingAttributes = newValue
        }
    }
    
    public func activeLineRange() -> NSRange? {
        guard let window = self.window, window.isKeyWindow, window.firstResponder == self else { return nil }
        let sel = self.selectedRange()
        let str = self.string as NSString
        guard str.length > 0 else { return nil }
        
        let queryLocation: Int
        if sel.location >= str.length {
            let lastChar = str.substring(with: NSRange(location: str.length - 1, length: 1))
            if lastChar == "\n" || lastChar == "\r" {
                return NSRange(location: str.length, length: 0)
            } else {
                queryLocation = str.length - 1
            }
        } else {
            queryLocation = sel.location
        }
        
        let queryRange = NSRange(location: queryLocation, length: max(0, min(sel.length, str.length - queryLocation)))
        return str.lineRange(for: queryRange)
    }
    
    public func renderMarkdown() {
        guard let storage = self.textStorage else { return }
        guard !isRenderingMarkdown else { return }
        isRenderingMarkdown = true
        defer { isRenderingMarkdown = false }
        
        let activeRange = activeLineRange()
        lastActiveLineRange = activeRange
        
        self.undoManager?.disableUndoRegistration()
        MarkdownRenderer.highlight(
            textStorage: storage,
            noteColor: self.noteColor,
            fontSize: self.currentFontSize,
            activeLineRange: activeRange
        )
        self.undoManager?.enableUndoRegistration()
    }
    
    public override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting stillSelectingFlag: Bool) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelectingFlag)
        if !stillSelectingFlag && !isRenderingMarkdown {
            let currentLineRange = activeLineRange()
            if currentLineRange != lastActiveLineRange {
                renderMarkdown()
            }
        }
    }
    
    public func notifyTextDidChange() {
        self.delegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: self))
    }
    
    // MARK: - Pinch to Zoom (Enlarge / Decrease Font Size)
    public override func magnify(with event: NSEvent) {
        let delta = event.magnification * 12.0
        let newSize = max(9.0, min(42.0, currentFontSize + delta))
        if abs(newSize - currentFontSize) >= 0.15 {
            currentFontSize = newSize
            self.font = NSFont.systemFont(ofSize: currentFontSize, weight: .regular)
            renderMarkdown()
            onFontSizeChanged?(newSize)
        }
    }
    
    // MARK: - Key Equivalents (Copy, Paste, Cut, Select All, Undo/Redo, Zoom, Ctrl+B/I/U, Cmd+B/I/U, Cmd+L)
    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isControl = flags.contains(.control) && !flags.contains(.option)
        let isCommand = flags.contains(.command) && !flags.contains(.option)
        let isShift = flags.contains(.shift)
        let key = event.charactersIgnoringModifiers?.lowercased()
        
        if isControl || isCommand {
            // 1. Copy (⌘C, Ctrl+C)
            if key == "c" && !isShift {
                self.copy(nil)
                return true
            }
            // 2. Paste (⌘V, Ctrl+V)
            if key == "v" && !isShift {
                self.paste(nil)
                return true
            }
            // 3. Cut (⌘X, Ctrl+X)
            if key == "x" && !isShift {
                self.cut(nil)
                return true
            }
            // 4. Select All (⌘A, Ctrl+A)
            if key == "a" && !isShift {
                self.selectAll(nil)
                return true
            }
            // 5. Undo / Redo (⌘Z, ⌘⇧Z, Ctrl+Z, Ctrl+⇧Z)
            if key == "z" {
                if isShift {
                    if self.undoManager?.canRedo == true {
                        self.undoManager?.redo()
                        renderMarkdown()
                        notifyTextDidChange()
                    }
                } else {
                    if self.undoManager?.canUndo == true {
                        self.undoManager?.undo()
                        renderMarkdown()
                        notifyTextDidChange()
                    }
                }
                return true
            }
            // 6. Formatting: Bold (⌘B, Ctrl+B)
            if key == "b" && !isShift {
                MarkdownRenderer.toggleFormatting(in: self, type: .bold)
                renderMarkdown()
                notifyTextDidChange()
                return true
            }
            // 7. Formatting: Italic (⌘I, Ctrl+I)
            if key == "i" && !isShift {
                MarkdownRenderer.toggleFormatting(in: self, type: .italic)
                renderMarkdown()
                notifyTextDidChange()
                return true
            }
            // 8. Formatting: Underline (⌘U, Ctrl+U)
            if key == "u" && !isShift {
                MarkdownRenderer.toggleFormatting(in: self, type: .underline)
                renderMarkdown()
                notifyTextDidChange()
                return true
            }
            // 9. Formatting: Strikethrough (⌘⇧X, Ctrl+⇧X)
            if key == "x" && isShift {
                MarkdownRenderer.toggleFormatting(in: self, type: .strikethrough)
                renderMarkdown()
                notifyTextDidChange()
                return true
            }
            // 10. Zoom In (⌘+ or ⌘=)
            if (key == "=" || key == "+") && !isShift {
                let newSize = min(42.0, currentFontSize + 1.5)
                currentFontSize = newSize
                self.font = NSFont.systemFont(ofSize: currentFontSize, weight: .regular)
                renderMarkdown()
                onFontSizeChanged?(newSize)
                return true
            }
            // 11. Zoom Out (⌘-)
            if key == "-" && !isShift {
                let newSize = max(9.0, currentFontSize - 1.5)
                currentFontSize = newSize
                self.font = NSFont.systemFont(ofSize: currentFontSize, weight: .regular)
                renderMarkdown()
                onFontSizeChanged?(newSize)
                return true
            }
            // 12. Zoom Reset (⌘0)
            if key == "0" && !isShift {
                let newSize: CGFloat = 13.0
                currentFontSize = newSize
                self.font = NSFont.systemFont(ofSize: currentFontSize, weight: .regular)
                renderMarkdown()
                onFontSizeChanged?(newSize)
                return true
            }
            // 13. Lock Note (⌘L)
            if key == "l" && isCommand && !isShift && !isControl {
                if let panel = self.window as? StickyPanel {
                    panel.handleLockShortcut()
                    return true
                }
            }
            // 14. Pin Note Always on Top (⌘P)
            if key == "p" && isCommand && !isShift && !isControl {
                if let panel = self.window as? StickyPanel {
                    NotesStore.shared.togglePin(id: panel.noteId)
                    return true
                }
            }
        }
        return super.performKeyEquivalent(with: event)
    }
    
    // MARK: - Explicit Clipboard & Selection Handling
    public override func copy(_ sender: Any?) {
        let selectedRange = self.selectedRange()
        if selectedRange.length > 0 {
            let fullString = self.string as NSString
            let selectedText = fullString.substring(with: selectedRange)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(selectedText, forType: .string)
        } else {
            super.copy(sender)
        }
    }
    
    public override func cut(_ sender: Any?) {
        let selectedRange = self.selectedRange()
        if selectedRange.length > 0 {
            let fullString = self.string as NSString
            let selectedText = fullString.substring(with: selectedRange)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(selectedText, forType: .string)
            
            if self.shouldChangeText(in: selectedRange, replacementString: "") {
                self.replaceCharacters(in: selectedRange, with: "")
                self.didChangeText()
                renderMarkdown()
                notifyTextDidChange()
            }
        }
    }
    
    public override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        if let text = pasteboard.string(forType: .string) {
            let selectedRange = self.selectedRange()
            if self.shouldChangeText(in: selectedRange, replacementString: text) {
                self.replaceCharacters(in: selectedRange, with: text)
                self.didChangeText()
                self.setSelectedRange(NSRange(location: selectedRange.location + (text as NSString).length, length: 0))
                renderMarkdown()
                notifyTextDidChange()
            }
        } else {
            super.paste(sender)
            renderMarkdown()
            notifyTextDidChange()
        }
    }
    
    public override func selectAll(_ sender: Any?) {
        let fullLength = (self.string as NSString).length
        self.setSelectedRange(NSRange(location: 0, length: fullLength))
    }
    
    // MARK: - Focus & Window Observers (Live Markdown Preview)
    public override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            renderMarkdown()
        }
        return result
    }
    
    public override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        renderMarkdown()
        return result
    }
    
    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: nil)
        if let window = self.window {
            NotificationCenter.default.addObserver(self, selector: #selector(handleWindowKeyNotification), name: NSWindow.didResignKeyNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(handleWindowKeyNotification), name: NSWindow.didBecomeKeyNotification, object: window)
        }
    }
    
    @objc private func handleWindowKeyNotification(_ notification: Notification) {
        renderMarkdown()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - KeyDown (Render Markdown on Enter + Smart List Continuation + Bullet Conversion)
    public override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 76 { // Return or Keypad Enter
            handleReturnKey(event: event)
            return
        }
        
        // Auto-convert "* " or "- " to "• " when Space is pressed at start of line
        if event.characters == " " {
            let sel = self.selectedRange()
            let str = self.string as NSString
            if sel.location > 0 && sel.location <= str.length {
                let lineRange = str.lineRange(for: NSRange(location: sel.location, length: 0))
                let beforeCursor = str.substring(with: NSRange(location: lineRange.location, length: sel.location - lineRange.location))
                let trimmedBefore = beforeCursor.trimmingCharacters(in: .whitespaces)
                if trimmedBefore == "*" || trimmedBefore == "-" || trimmedBefore == "+" {
                    let indent = String(beforeCursor.prefix(beforeCursor.count - trimmedBefore.count))
                    let replacement = "\(indent)• "
                    let targetRange = NSRange(location: lineRange.location, length: beforeCursor.count)
                    if self.shouldChangeText(in: targetRange, replacementString: replacement) {
                        self.replaceCharacters(in: targetRange, with: replacement)
                        self.didChangeText()
                        self.setSelectedRange(NSRange(location: lineRange.location + (replacement as NSString).length, length: 0))
                        renderMarkdown()
                        notifyTextDidChange()
                        return
                    }
                }
            }
        }
        
        super.keyDown(with: event)
    }
    
    private func handleReturnKey(event: NSEvent) {
        let selected = self.selectedRange()
        let currentString = (self.string as NSString)
        
        guard selected.location <= currentString.length else {
            super.keyDown(with: event)
            convertAllAsteriskBullets()
            renderMarkdown()
            notifyTextDidChange()
            return
        }
        
        let lineRange = currentString.lineRange(for: NSRange(location: selected.location, length: 0))
        let lineText = currentString.substring(with: lineRange)
        let trimmedLine = lineText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Checklist continuation or exit
        if trimmedLine == "- [ ]" || trimmedLine == "* [ ]" || trimmedLine == "- [x]" || trimmedLine == "- [X]" || trimmedLine == "* [x]" {
            // User pressed Enter on empty task item -> exit list
            if self.shouldChangeText(in: lineRange, replacementString: "\n") {
                self.replaceCharacters(in: lineRange, with: "\n")
                self.didChangeText()
                self.setSelectedRange(NSRange(location: lineRange.location, length: 0))
                convertAllAsteriskBullets()
                renderMarkdown()
                notifyTextDidChange()
                return
            }
        } else if lineText.contains("- [ ]") || lineText.contains("* [ ]") || lineText.contains("- [x]") || lineText.contains("- [X]") || lineText.contains("* [x]") {
            // Continuation of checklist item
            let continuation = "\n- [ ] "
            if self.shouldChangeText(in: selected, replacementString: continuation) {
                self.replaceCharacters(in: selected, with: continuation)
                self.didChangeText()
                self.setSelectedRange(NSRange(location: selected.location + continuation.count, length: 0))
                convertAllAsteriskBullets()
                renderMarkdown()
                notifyTextDidChange()
                return
            }
        }
        
        // 2. Bullet list continuation or exit (converts "* ", "- ", "+ " to "• ")
        if trimmedLine == "•" || trimmedLine == "-" || trimmedLine == "*" || trimmedLine == "+" {
            // Exit bullet list
            if self.shouldChangeText(in: lineRange, replacementString: "\n") {
                self.replaceCharacters(in: lineRange, with: "\n")
                self.didChangeText()
                self.setSelectedRange(NSRange(location: lineRange.location, length: 0))
                convertAllAsteriskBullets()
                renderMarkdown()
                notifyTextDidChange()
                return
            }
        } else if let bulletMatch = try? NSRegularExpression(pattern: "^(\\s*)([•\\-*+])\\s+(.*)$", options: []).firstMatch(in: lineText, options: [], range: NSRange(location: 0, length: (lineText as NSString).length)) {
            let indent = (lineText as NSString).substring(with: bulletMatch.range(at: 1))
            let marker = (lineText as NSString).substring(with: bulletMatch.range(at: 2))
            
            // If the marker on this line was "*", "-", or "+", convert it to "•"
            if marker != "•" {
                let markerLocalRange = bulletMatch.range(at: 2)
                let absMarkerRange = NSRange(location: lineRange.location + markerLocalRange.location, length: markerLocalRange.length)
                self.replaceCharacters(in: absMarkerRange, with: "•")
            }
            
            let continuation = "\n\(indent)• "
            let newInsertPoint = self.selectedRange()
            if self.shouldChangeText(in: newInsertPoint, replacementString: continuation) {
                self.replaceCharacters(in: newInsertPoint, with: continuation)
                self.didChangeText()
                self.setSelectedRange(NSRange(location: newInsertPoint.location + continuation.count, length: 0))
                convertAllAsteriskBullets()
                renderMarkdown()
                notifyTextDidChange()
                return
            }
        }
        
        // 3. Numbered list continuation or exit
        if let numMatch = try? NSRegularExpression(pattern: "^(\\s*)(\\d+)\\.\\s*(.*)$", options: []).firstMatch(in: lineText, options: [], range: NSRange(location: 0, length: (lineText as NSString).length)) {
            let indent = (lineText as NSString).substring(with: numMatch.range(at: 1))
            let numStr = (lineText as NSString).substring(with: numMatch.range(at: 2))
            let itemTextRange = numMatch.range(at: 3)
            let itemText = (lineText as NSString).substring(with: itemTextRange).trimmingCharacters(in: .whitespacesAndNewlines)
            
            if itemText.isEmpty {
                // Exit numbered list
                if self.shouldChangeText(in: lineRange, replacementString: "\n") {
                    self.replaceCharacters(in: lineRange, with: "\n")
                    self.didChangeText()
                    self.setSelectedRange(NSRange(location: lineRange.location, length: 0))
                    convertAllAsteriskBullets()
                    renderMarkdown()
                    notifyTextDidChange()
                    return
                }
            } else if let num = Int(numStr) {
                // If line had no space after dot (e.g. "1.cfv"), fix it to "1. cfv"
                if !lineText.contains("\(numStr). ") {
                    if let dotRange = lineText.range(of: "\(numStr).") {
                        let dotNSRange = NSRange(dotRange, in: lineText)
                        let absoluteDotEnd = lineRange.location + dotNSRange.location + dotNSRange.length
                        self.replaceCharacters(in: NSRange(location: absoluteDotEnd, length: 0), with: " ")
                    }
                }
                
                let nextNum = num + 1
                let continuation = "\n\(indent)\(nextNum). "
                let insertPoint = self.selectedRange()
                if self.shouldChangeText(in: insertPoint, replacementString: continuation) {
                    self.replaceCharacters(in: insertPoint, with: continuation)
                    self.didChangeText()
                    self.setSelectedRange(NSRange(location: insertPoint.location + continuation.count, length: 0))
                    convertAllAsteriskBullets()
                    renderMarkdown()
                    notifyTextDidChange()
                    return
                }
            }
        }
        
        // 4. Default: Standard Enter
        super.keyDown(with: event)
        convertAllAsteriskBullets()
        renderMarkdown()
        notifyTextDidChange()
    }
    
    private func convertAllAsteriskBullets() {
        let currentString = self.string
        let converted = MarkdownRenderer.convertBulletsToSymbols(in: currentString)
        if converted != currentString {
            let sel = self.selectedRange()
            let fullRange = NSRange(location: 0, length: (currentString as NSString).length)
            if self.shouldChangeText(in: fullRange, replacementString: converted) {
                self.replaceCharacters(in: fullRange, with: converted)
                self.didChangeText()
                self.setSelectedRange(sel)
            }
        }
    }
    
    // MARK: - Interactive Checkbox Click
    public override func mouseDown(with event: NSEvent) {
        let point = self.convert(event.locationInWindow, from: nil)
        let charIndex = self.characterIndexForInsertion(at: point)
        let fullText = self.string as NSString
        
        if charIndex < fullText.length {
            let start = max(0, charIndex - 4)
            let end = min(fullText.length, charIndex + 4)
            let searchRange = NSRange(location: start, length: end - start)
            let slice = fullText.substring(with: searchRange)
            
            if let range = slice.range(of: "\\[([ xX])\\]", options: .regularExpression) {
                let localNSRange = NSRange(range, in: slice)
                let tokenRange = NSRange(location: start + localNSRange.location, length: localNSRange.length)
                
                if let layoutManager = self.layoutManager, let textContainer = self.textContainer {
                    let glyphRange = layoutManager.glyphRange(forCharacterRange: tokenRange, actualCharacterRange: nil)
                    let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                    let paddedRect = rect.insetBy(dx: -4, dy: -4)
                    if paddedRect.contains(point) {
                        let currentToken = fullText.substring(with: tokenRange)
                        let toggled = currentToken.contains(" ") ? "[x]" : "[ ]"
                        if self.shouldChangeText(in: tokenRange, replacementString: toggled) {
                            self.replaceCharacters(in: tokenRange, with: toggled)
                            self.didChangeText()
                            renderMarkdown()
                            notifyTextDidChange()
                            return
                        }
                    }
                }
            }
        }
        
        super.mouseDown(with: event)
    }
}
