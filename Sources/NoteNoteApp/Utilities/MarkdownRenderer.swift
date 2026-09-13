import AppKit
import Foundation

public enum MarkdownFormattingType {
    case bold
    case italic
    case underline
    case strikethrough
    case inlineCode
}

public enum MarkdownRenderer {
    
    // MARK: - Highlight / Render Full Text Storage
    public static func highlight(
        textStorage: NSTextStorage,
        noteColor: NoteColor,
        fontSize: CGFloat = 13.0,
        activeLineRange: NSRange? = nil
    ) {
        let string = textStorage.string
        let fullRange = NSRange(location: 0, length: (string as NSString).length)
        guard fullRange.length > 0 else { return }
        
        let isDark = noteColor.isDark
        let baseTextColor = noteColor.nsTextColor
        let accentColor = noteColor.nsAccentColor
        let dimmedMarkerColor = baseTextColor.withAlphaComponent(0.40)
        let baseFont = NSFont.systemFont(ofSize: fontSize, weight: .regular)
        
        let defaultParagraphStyle = NSMutableParagraphStyle()
        defaultParagraphStyle.lineSpacing = max(2.0, fontSize * 0.25)
        defaultParagraphStyle.paragraphSpacing = max(2.0, fontSize * 0.22)
        
        textStorage.beginEditing()
        
        // Helper to check if a line is currently active (being edited)
        let isLineActive: (NSRange) -> Bool = { lineRange in
            guard let active = activeLineRange else { return false }
            return NSIntersectionRange(lineRange, active).length > 0
        }
        
        // Helper to show markdown markers on active lines, but completely hide them on inactive lines
        func applyMarkerStyle(range: NSRange, on lineRange: NSRange) {
            guard range.length > 0, NSMaxRange(range) <= (string as NSString).length else { return }
            if isLineActive(lineRange) {
                // Active line: Show raw markdown token clearly so user can edit it
                textStorage.addAttribute(.font, value: NSFont.systemFont(ofSize: fontSize, weight: .regular), range: range)
                textStorage.addAttribute(.foregroundColor, value: dimmedMarkerColor, range: range)
            } else {
                // Inactive line: Hide markdown formatting text completely!
                textStorage.addAttribute(.font, value: NSFont.systemFont(ofSize: 0.001), range: range)
                textStorage.addAttribute(.foregroundColor, value: NSColor.clear, range: range)
            }
        }
        
        // 1. Reset base attributes
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: baseTextColor,
            .paragraphStyle: defaultParagraphStyle,
            .underlineStyle: 0,
            .strikethroughStyle: 0,
            .backgroundColor: NSColor.clear
        ]
        textStorage.setAttributes(baseAttributes, range: fullRange)
        
        // 2. Multi-line Code Blocks (``` ... ```)
        var codeBlockRanges: [NSRange] = []
        let codeBlockPattern = "(?m)^```[a-zA-Z0-9_-]*\\n([\\s\\S]*?)\\n```$"
        if let codeBlockRegex = try? NSRegularExpression(pattern: codeBlockPattern, options: []) {
            let matches = codeBlockRegex.matches(in: string, options: [], range: fullRange)
            for match in matches {
                codeBlockRanges.append(match.range)
                let monoFont = NSFont.monospacedSystemFont(ofSize: max(8.0, fontSize - 1.0), weight: .regular)
                let codeBg = isDark ? NSColor.white.withAlphaComponent(0.08) : NSColor.black.withAlphaComponent(0.05)
                textStorage.addAttributes([
                    .font: monoFont,
                    .backgroundColor: codeBg
                ], range: match.range)
            }
        }
        
        // 3. Line-by-Line Markdown Elements
        (string as NSString).enumerateSubstrings(in: fullRange, options: .byLines) { substring, lineRange, _, _ in
            guard let line = substring else { return }
            
            // Skip line processing if inside a code block
            for cbRange in codeBlockRanges {
                if NSIntersectionRange(lineRange, cbRange).length > 0 {
                    return
                }
            }
            
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            
            // A. Headings: # H1, ## H2, ### H3, #### H4, ##### H5, ###### H6
            if let headingMatch = matchFirst(pattern: "^(#{1,6})\\s+(.*)$", in: line) {
                let hashes = (line as NSString).substring(with: headingMatch.range(at: 1))
                let level = hashes.count
                
                let headingFont: NSFont = {
                    switch level {
                    case 1: return NSFont.systemFont(ofSize: round(fontSize * 1.38), weight: .bold)
                    case 2: return NSFont.systemFont(ofSize: round(fontSize * 1.20), weight: .bold)
                    case 3: return NSFont.systemFont(ofSize: round(fontSize * 1.08), weight: .semibold)
                    case 4: return NSFont.systemFont(ofSize: round(fontSize * 1.04), weight: .semibold)
                    default: return NSFont.systemFont(ofSize: fontSize, weight: .semibold)
                    }
                }()
                
                textStorage.addAttribute(.font, value: headingFont, range: lineRange)
                
                let textStartLocal = headingMatch.range(at: 2).location
                let markerRange = NSRange(location: lineRange.location, length: textStartLocal)
                applyMarkerStyle(range: markerRange, on: lineRange)
                return
            }
            
            // B. Horizontal Rule: ---, ***, ___
            if let _ = matchFirst(pattern: "^(\\s*[-*_]{3,}\\s*)$", in: line) {
                let dividerColor = baseTextColor.withAlphaComponent(0.25)
                textStorage.addAttributes([
                    .font: NSFont.systemFont(ofSize: 10),
                    .foregroundColor: dividerColor,
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .strikethroughColor: dividerColor
                ], range: lineRange)
                return
            }
            
            // C. Blockquote: > text
            if let quoteMatch = matchFirst(pattern: "^(\\s*>+)\\s*(.*)$", in: line) {
                let textStartLocal = quoteMatch.range(at: 2).location
                let markerRange = NSRange(location: lineRange.location, length: textStartLocal)
                applyMarkerStyle(range: markerRange, on: lineRange)
                
                let italicFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
                textStorage.addAttributes([
                    .font: italicFont,
                    .foregroundColor: baseTextColor.withAlphaComponent(0.85)
                ], range: lineRange)
                return
            }
            
            // D. Checklists: - [ ] or - [x]
            if let checkMatch = matchFirst(pattern: "^(\\s*[-*]\\s*\\[([ xX])\\])\\s*(.*)$", in: line) {
                let markerLocalRange = checkMatch.range(at: 1)
                let markLocalRange = checkMatch.range(at: 2)
                let isChecked = (line as NSString).substring(with: markLocalRange).lowercased() == "x"
                
                let markerRange = NSRange(location: lineRange.location + markerLocalRange.location, length: markerLocalRange.length)
                textStorage.addAttribute(.foregroundColor, value: accentColor, range: markerRange)
                
                if isChecked && checkMatch.numberOfRanges >= 4 {
                    let textLocalRange = checkMatch.range(at: 3)
                    if textLocalRange.length > 0 {
                        let textRange = NSRange(location: lineRange.location + textLocalRange.location, length: textLocalRange.length)
                        textStorage.addAttributes([
                            .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                            .strikethroughColor: baseTextColor.withAlphaComponent(0.55),
                            .foregroundColor: baseTextColor.withAlphaComponent(0.55)
                        ], range: textRange)
                    }
                }
                return
            }
            
            // E. Bullet Lists: • item, - item, * item, + item
            if let bulletMatch = matchFirst(pattern: "^(\\s*[•\\-*+])\\s+(.*)$", in: line) {
                let bulletLocalRange = bulletMatch.range(at: 1)
                let markerRange = NSRange(location: lineRange.location + bulletLocalRange.location, length: bulletLocalRange.length)
                textStorage.addAttribute(.foregroundColor, value: baseTextColor, range: markerRange)
                return
            }
            
            // F. Numbered Lists: 1. item or 1.item
            if let numMatch = matchFirst(pattern: "^(\\s*\\d+\\.)\\s*(.*)$", in: line) {
                let numLocalRange = numMatch.range(at: 1)
                let markerRange = NSRange(location: lineRange.location + numLocalRange.location, length: numLocalRange.length)
                textStorage.addAttribute(.foregroundColor, value: baseTextColor, range: markerRange)
                return
            }
        }
        
        // 4. Inline Markdown Elements (processed outside code blocks)
        func applyInline(pattern: String, handler: (NSTextCheckingResult) -> Void) {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
            let matches = regex.matches(in: string, options: [], range: fullRange)
            for match in matches {
                // Ignore matches that overlap with multi-line code blocks
                var overlaps = false
                for cb in codeBlockRanges {
                    if NSIntersectionRange(match.range, cb).length > 0 {
                        overlaps = true
                        break
                    }
                }
                if !overlaps {
                    handler(match)
                }
            }
        }
        
        // Inline Code: `code`
        let codeBg = isDark ? NSColor.white.withAlphaComponent(0.12) : NSColor.black.withAlphaComponent(0.06)
        let monoFont = NSFont.monospacedSystemFont(ofSize: max(8.0, fontSize - 1.0), weight: .medium)
        applyInline(pattern: "`([^`\\n]+)`") { match in
            let enclosingLine = (string as NSString).lineRange(for: match.range)
            let innerRange = match.range(at: 1)
            textStorage.addAttributes([
                .font: monoFont,
                .backgroundColor: codeBg
            ], range: isLineActive(enclosingLine) ? match.range : innerRange)
            
            let startTick = NSRange(location: match.range.location, length: 1)
            let endTick = NSRange(location: match.range.location + match.range.length - 1, length: 1)
            applyMarkerStyle(range: startTick, on: enclosingLine)
            applyMarkerStyle(range: endTick, on: enclosingLine)
        }
        
        // Bold + Italic: ***text*** or ___text___
        applyInline(pattern: "(\\*{3}|_{3})([^\\*\\n_]+)(\\*{3}|_{3})") { match in
            let innerRange = match.range(at: 2)
            let enclosingLine = (string as NSString).lineRange(for: match.range)
            if innerRange.length > 0 {
                let currentFont = (textStorage.attribute(.font, at: innerRange.location, effectiveRange: nil) as? NSFont) ?? baseFont
                var font = NSFontManager.shared.convert(currentFont, toHaveTrait: .boldFontMask)
                font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
                textStorage.addAttribute(.font, value: font, range: innerRange)
            }
            applyMarkerStyle(range: match.range(at: 1), on: enclosingLine)
            applyMarkerStyle(range: match.range(at: 3), on: enclosingLine)
        }
        
        // Bold: **text** or __text__
        applyInline(pattern: "(\\*{2}|_{2})([^\\*\\n_]+)(\\*{2}|_{2})") { match in
            let innerRange = match.range(at: 2)
            let enclosingLine = (string as NSString).lineRange(for: match.range)
            if innerRange.length > 0 {
                let currentFont = (textStorage.attribute(.font, at: innerRange.location, effectiveRange: nil) as? NSFont) ?? baseFont
                let font = NSFontManager.shared.convert(currentFont, toHaveTrait: .boldFontMask)
                textStorage.addAttribute(.font, value: font, range: innerRange)
            }
            applyMarkerStyle(range: match.range(at: 1), on: enclosingLine)
            applyMarkerStyle(range: match.range(at: 3), on: enclosingLine)
        }
        
        // Italic: *text* or _text_
        applyInline(pattern: "(?<![\\*_\\w])(\\*{1}|_{1})([^\\*_\\n]+)(\\*{1}|_{1})(?![\\*_\\w])") { match in
            let innerRange = match.range(at: 2)
            let enclosingLine = (string as NSString).lineRange(for: match.range)
            if innerRange.length > 0 {
                let currentFont = (textStorage.attribute(.font, at: innerRange.location, effectiveRange: nil) as? NSFont) ?? baseFont
                let font = NSFontManager.shared.convert(currentFont, toHaveTrait: .italicFontMask)
                textStorage.addAttribute(.font, value: font, range: innerRange)
            }
            applyMarkerStyle(range: match.range(at: 1), on: enclosingLine)
            applyMarkerStyle(range: match.range(at: 3), on: enclosingLine)
        }
        
        // Underline: <u>text</u> or ++text++
        applyInline(pattern: "(<u>|\\+\\+)(.*?)(<\\/u>|\\+\\+)") { match in
            let innerRange = match.range(at: 2)
            let enclosingLine = (string as NSString).lineRange(for: match.range)
            if innerRange.length > 0 {
                textStorage.addAttributes([
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .underlineColor: baseTextColor
                ], range: innerRange)
            }
            applyMarkerStyle(range: match.range(at: 1), on: enclosingLine)
            applyMarkerStyle(range: match.range(at: 3), on: enclosingLine)
        }
        
        // Strikethrough: ~~text~~ or ~text~
        applyInline(pattern: "(~{1,2})([^~\\n]+)(~{1,2})") { match in
            let innerRange = match.range(at: 2)
            let enclosingLine = (string as NSString).lineRange(for: match.range)
            if innerRange.length > 0 {
                textStorage.addAttributes([
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .strikethroughColor: baseTextColor.withAlphaComponent(0.65)
                ], range: innerRange)
            }
            applyMarkerStyle(range: match.range(at: 1), on: enclosingLine)
            applyMarkerStyle(range: match.range(at: 3), on: enclosingLine)
        }
        
        // Highlight / Mark: ==text==
        let highlightBg = isDark ? NSColor.systemYellow.withAlphaComponent(0.28) : NSColor.systemYellow.withAlphaComponent(0.38)
        applyInline(pattern: "==([^=\\n]+)==") { match in
            let innerRange = match.range(at: 1)
            let enclosingLine = (string as NSString).lineRange(for: match.range)
            if innerRange.length > 0 {
                textStorage.addAttribute(.backgroundColor, value: highlightBg, range: innerRange)
            }
            let start = NSRange(location: match.range.location, length: 2)
            let end = NSRange(location: match.range.location + match.range.length - 2, length: 2)
            applyMarkerStyle(range: start, on: enclosingLine)
            applyMarkerStyle(range: end, on: enclosingLine)
        }
        
        // Links: [text](url)
        applyInline(pattern: "\\[([^\\]]+)\\]\\(([^\\)]+)\\)") { match in
            let titleRange = match.range(at: 1)
            let urlRange = match.range(at: 2)
            let enclosingLine = (string as NSString).lineRange(for: match.range)
            if titleRange.length > 0 {
                textStorage.addAttributes([
                    .foregroundColor: accentColor,
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .underlineColor: accentColor
                ], range: titleRange)
            }
            
            if isLineActive(enclosingLine) {
                let openBracket = NSRange(location: match.range.location, length: 1)
                let middlePart = NSRange(location: titleRange.location + titleRange.length, length: 2) // "][("
                let closeParen = NSRange(location: match.range.location + match.range.length - 1, length: 1)
                applyMarkerStyle(range: openBracket, on: enclosingLine)
                applyMarkerStyle(range: middlePart, on: enclosingLine)
                textStorage.addAttribute(.foregroundColor, value: dimmedMarkerColor, range: urlRange)
                applyMarkerStyle(range: closeParen, on: enclosingLine)
            } else {
                let openBracket = NSRange(location: match.range.location, length: 1)
                let afterTitle = NSRange(location: titleRange.location + titleRange.length, length: match.range.length - (titleRange.location - match.range.location) - titleRange.length)
                applyMarkerStyle(range: openBracket, on: enclosingLine)
                applyMarkerStyle(range: afterTitle, on: enclosingLine)
            }
        }
        
        textStorage.endEditing()
    }
    
    // MARK: - Shortcut Toggling (Ctrl+B, Ctrl+I, Ctrl+U, etc.)
    public static func toggleFormatting(in textView: NSTextView, type: MarkdownFormattingType) {
        let selectedRange = textView.selectedRange()
        let text = textView.string as NSString
        let fullLength = text.length
        
        let (openTag, closeTag): (String, String) = {
            switch type {
            case .bold: return ("**", "**")
            case .italic: return ("*", "*")
            case .underline: return ("<u>", "</u>")
            case .strikethrough: return ("~~", "~~")
            case .inlineCode: return ("`", "`")
            }
        }()
        
        let openLen = (openTag as NSString).length
        let closeLen = (closeTag as NSString).length
        
        // 1. Text is selected
        if selectedRange.length > 0 {
            let selectedText = text.substring(with: selectedRange)
            
            // Check if selectedText is already wrapped internally
            if selectedText.hasPrefix(openTag) && selectedText.hasSuffix(closeTag) && selectedText.count >= (openLen + closeLen) {
                let inner = String(selectedText.dropFirst(openLen).dropLast(closeLen))
                if textView.shouldChangeText(in: selectedRange, replacementString: inner) {
                    textView.replaceCharacters(in: selectedRange, with: inner)
                    textView.didChangeText()
                    textView.setSelectedRange(NSRange(location: selectedRange.location, length: (inner as NSString).length))
                }
                return
            }
            
            // Check if selection is surrounded by tags externally
            let canCheckBefore = selectedRange.location >= openLen
            let canCheckAfter = (selectedRange.location + selectedRange.length + closeLen) <= fullLength
            if canCheckBefore && canCheckAfter {
                let beforeRange = NSRange(location: selectedRange.location - openLen, length: openLen)
                let afterRange = NSRange(location: selectedRange.location + selectedRange.length, length: closeLen)
                if text.substring(with: beforeRange) == openTag && text.substring(with: afterRange) == closeTag {
                    let totalRange = NSRange(location: selectedRange.location - openLen, length: selectedRange.length + openLen + closeLen)
                    if textView.shouldChangeText(in: totalRange, replacementString: selectedText) {
                        textView.replaceCharacters(in: totalRange, with: selectedText)
                        textView.didChangeText()
                        textView.setSelectedRange(NSRange(location: selectedRange.location - openLen, length: selectedRange.length))
                    }
                    return
                }
            }
            
            // Otherwise, wrap the selection
            let wrapped = "\(openTag)\(selectedText)\(closeTag)"
            if textView.shouldChangeText(in: selectedRange, replacementString: wrapped) {
                textView.replaceCharacters(in: selectedRange, with: wrapped)
                textView.didChangeText()
                textView.setSelectedRange(NSRange(location: selectedRange.location + openLen, length: selectedRange.length))
            }
        } else {
            // 2. Cursor only (no selection)
            let insertStr = "\(openTag)\(closeTag)"
            if textView.shouldChangeText(in: selectedRange, replacementString: insertStr) {
                textView.replaceCharacters(in: selectedRange, with: insertStr)
                textView.didChangeText()
                textView.setSelectedRange(NSRange(location: selectedRange.location + openLen, length: 0))
            }
        }
    }
    
    // MARK: - Convert Asterisk/Dash/Plus Bullets to Actual Bullets (•)
    public static func convertBulletsToSymbols(in text: String) -> String {
        // Replace leading "* ", "- ", "+ " with "• " unless it's a checklist "[ ]" or "[x]"
        let pattern = "(?m)^([ \\t]*)[*+-]\\s+(?!\\[[ xX]\\])"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return text }
        let range = NSRange(location: 0, length: (text as NSString).length)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "$1• ")
    }
    
    // MARK: - Helper Regex Matcher
    private static func matchFirst(pattern: String, in string: String) -> NSTextCheckingResult? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(location: 0, length: (string as NSString).length)
        return regex.firstMatch(in: string, options: [], range: range)
    }
}
