import AppKit
import SwiftUI

@MainActor
public final class NoteContextMenu {
    
    public static func makeMenu(for noteId: UUID) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        guard let note = NotesStore.shared.notes.first(where: { $0.id == noteId }) else {
            return menu
        }
        
        // Single compact menu item with color swatches and opacity slider only
        let item = NSMenuItem()
        let customView = NoteMenuHeaderView(noteId: noteId, currentNote: note)
        item.view = customView
        menu.addItem(item)
        
        return menu
    }
}

// MARK: - Custom View for Color Swatches + Opacity Slider Only
@MainActor
private final class NoteMenuHeaderView: NSView {
    private let noteId: UUID
    private var currentColor: NoteColor
    private var currentOpacity: Double
    
    private let colorLabel = NSTextField(labelWithString: "COLOR")
    private let opacitySlider = NSSlider()
    
    private var swatchRects: [(rect: NSRect, color: NoteColor)] = []
    private var trackingArea: NSTrackingArea?
    
    init(noteId: UUID, currentNote: NoteModel) {
        self.noteId = noteId
        self.currentColor = currentNote.color
        self.currentOpacity = currentNote.opacity
        super.init(frame: NSRect(x: 0, y: 0, width: 276, height: 116))
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        wantsLayer = true
        
        // 1. Single Unified Color Title Label (No "THEMES" text, no separation)
        colorLabel.font = .systemFont(ofSize: 10, weight: .bold)
        colorLabel.textColor = .secondaryLabelColor
        colorLabel.isSelectable = false
        colorLabel.focusRingType = .none
        colorLabel.frame = NSRect(x: 14, y: 94, width: 248, height: 14)
        addSubview(colorLabel)
        
        // 2. Compute swatch circle frames (24px diameter, slightly larger for clear detail)
        let circleSize: CGFloat = 24
        let spacing: CGFloat = 8
        
        let allColors = NoteColor.allCases
        let row1Colors = Array(allColors.prefix(8))
        let row2Colors = Array(allColors.dropFirst(8))
        
        // Row 1 (8 items, Y=62) - Centered in 276: 8 * 24 + 7 * 8 = 248 -> startX = 14
        let startX1: CGFloat = 14
        let row1Rects = row1Colors.enumerated().map { index, color in
            let x = startX1 + CGFloat(index) * (circleSize + spacing)
            return (NSRect(x: x, y: 62, width: circleSize, height: circleSize), color)
        }
        
        // Row 2 (7 items, Y=32) - Centered in 276: 7 * 24 + 6 * 8 = 216 -> startX = 30
        let startX2: CGFloat = 30
        let row2Rects = row2Colors.enumerated().map { index, color in
            let x = startX2 + CGFloat(index) * (circleSize + spacing)
            return (NSRect(x: x, y: 32, width: circleSize, height: circleSize), color)
        }
        
        swatchRects = row1Rects + row2Rects
        
        // Register tooltips for each swatch
        for item in swatchRects {
            addToolTip(item.rect, owner: item.color.displayName, userData: nil)
        }
        
        // 3. Opacity Slider
        opacitySlider.minValue = 0.20
        opacitySlider.maxValue = 1.0
        opacitySlider.doubleValue = max(0.2, min(1.0, currentOpacity))
        opacitySlider.isContinuous = true
        opacitySlider.focusRingType = .none
        opacitySlider.target = self
        opacitySlider.action = #selector(sliderDidMove(_:))
        opacitySlider.frame = NSRect(x: 12, y: 8, width: 252, height: 16)
        addSubview(opacitySlider)
        
        updateLabel()
    }
    
    private func updateLabel(hoverColor: NoteColor? = nil) {
        let active = hoverColor ?? currentColor
        colorLabel.stringValue = "COLOR • \(active.displayName.uppercased())"
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }
    
    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let hovered = swatchRects.first(where: { $0.rect.contains(point) })?.color
        updateLabel(hoverColor: hovered)
    }
    
    override func mouseExited(with event: NSEvent) {
        updateLabel(hoverColor: nil)
    }
    
    @objc private func sliderDidMove(_ sender: NSSlider) {
        let newOpacity = sender.doubleValue
        self.currentOpacity = newOpacity
        
        // 1. Immediately update window alpha live in real-time
        StickyWindowManager.shared.updatePanelOpacityLive(id: noteId, opacity: newOpacity)
        
        // 2. Persist updated opacity
        if let idx = NotesStore.shared.notes.firstIndex(where: { $0.id == noteId }) {
            NotesStore.shared.notes[idx].opacity = newOpacity
            NotesStore.shared.requestSave()
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        for (rect, color) in swatchRects {
            let isSelected = (color == currentColor)
            
            context.saveGState()
            
            // Clip to circular swatch
            context.addEllipse(in: rect)
            context.clip()
            
            // 1. Draw base note background
            if color == .glass {
                context.setFillColor(NSColor.windowBackgroundColor.withAlphaComponent(0.4).cgColor)
                context.fill(rect)
                
                // Subtle frosted diagonal sheen
                context.setStrokeColor(NSColor.white.withAlphaComponent(0.45).cgColor)
                context.setLineWidth(1.5)
                context.move(to: CGPoint(x: rect.minX + 3, y: rect.maxY - 3))
                context.addLine(to: CGPoint(x: rect.maxX - 3, y: rect.minY + 3))
                context.strokePath()
            } else {
                context.setFillColor(color.nsBackgroundColor.cgColor)
                context.fill(rect)
            }
            
            // 2. Draw miniature representation of the actual theme look (NO colored dots inside)
            switch color {
            case .gundam:
                // Technical blue graph paper grid on white paper
                drawMiniGrid(in: rect, context: context, lineColor: NSColor(red: 0.78, green: 0.85, blue: 0.94, alpha: 0.9))
                
            case .tokyoDrift:
                // Dark asphalt with subtle dark grid
                drawMiniGrid(in: rect, context: context, lineColor: NSColor(white: 0.22, alpha: 0.85))
                
            case .vendetta:
                // Pitch black with subtle matrix dots
                drawMiniDots(in: rect, context: context, dotColor: NSColor(white: 0.35, alpha: 0.8))
                
            case .piccolo:
                // Crisp off-white paper with vibrant lime green dashed margin guide on left
                drawMiniMarginGuide(in: rect, context: context, lineColor: NSColor(red: 0.16, green: 0.75, blue: 0.45, alpha: 0.95))
                
            case .a24:
                // Deep obsidian jade black with sage matrix dots
                drawMiniDots(in: rect, context: context, dotColor: NSColor(red: 0.22, green: 0.34, blue: 0.26, alpha: 0.8))
                
            case .brave:
                // Warm parchment ivory with warm graph paper grid
                drawMiniGrid(in: rect, context: context, lineColor: NSColor(red: 0.84, green: 0.79, blue: 0.71, alpha: 0.9))
                
            case .agrabah:
                // Midnight navy with glowing purple grid
                drawMiniGrid(in: rect, context: context, lineColor: NSColor(red: 0.26, green: 0.24, blue: 0.52, alpha: 0.9))
                
            case .mononoke:
                // Charcoal slate with vertical vermillion war-paint stripe on right border
                drawMiniRightStripe(in: rect, context: context, color: NSColor(red: 0.94, green: 0.32, blue: 0.32, alpha: 1.0))
                
            default:
                break
            }
            
            context.restoreGState()
            
            // 3. Subtle circular outer border
            context.setStrokeColor(NSColor.black.withAlphaComponent(color.isDark ? 0.35 : 0.18).cgColor)
            context.setLineWidth(0.8)
            context.strokeEllipse(in: rect)
            
            // 4. Selection indicator ring (outer halo, never covers internal theme artwork)
            if isSelected {
                let ringRect = rect.insetBy(dx: -2.8, dy: -2.8)
                context.setStrokeColor(NSColor.controlAccentColor.cgColor)
                context.setLineWidth(2.2)
                context.strokeEllipse(in: ringRect)
            }
        }
    }
    
    // MARK: - Mini Pattern Drawing Helpers
    private func drawMiniGrid(in rect: NSRect, context: CGContext, lineColor: NSColor) {
        context.setLineDash(phase: 0, lengths: [])
        context.setStrokeColor(lineColor.cgColor)
        context.setLineWidth(0.6)
        
        let step: CGFloat = 6.0
        var x = rect.minX + step
        while x < rect.maxX {
            context.move(to: CGPoint(x: x, y: rect.minY))
            context.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += step
        }
        var y = rect.minY + step
        while y < rect.maxY {
            context.move(to: CGPoint(x: rect.minX, y: y))
            context.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += step
        }
        context.strokePath()
    }
    
    private func drawMiniDots(in rect: NSRect, context: CGContext, dotColor: NSColor) {
        context.setFillColor(dotColor.cgColor)
        let step: CGFloat = 6.0
        var x = rect.minX + step
        while x < rect.maxX {
            var y = rect.minY + step
            while y < rect.maxY {
                context.fillEllipse(in: CGRect(x: x - 0.75, y: y - 0.75, width: 1.5, height: 1.5))
                y += step
            }
            x += step
        }
    }
    
    private func drawMiniMarginGuide(in rect: NSRect, context: CGContext, lineColor: NSColor) {
        context.setStrokeColor(lineColor.cgColor)
        context.setLineWidth(1.0)
        let dashes: [CGFloat] = [2.5, 2.0]
        context.setLineDash(phase: 0, lengths: dashes)
        let x = rect.minX + 6.5
        context.move(to: CGPoint(x: x, y: rect.minY))
        context.addLine(to: CGPoint(x: x, y: rect.maxY))
        context.strokePath()
        context.setLineDash(phase: 0, lengths: [])
    }
    
    private func drawMiniRightStripe(in rect: NSRect, context: CGContext, color: NSColor) {
        context.setFillColor(color.cgColor)
        let stripeWidth: CGFloat = 3.5
        let stripeRect = NSRect(x: rect.maxX - stripeWidth, y: rect.minY, width: stripeWidth, height: rect.height)
        context.fill(stripeRect)
    }
    
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        
        // Check if any color circle was clicked
        for (rect, color) in swatchRects {
            if rect.contains(point) {
                currentColor = color
                updateLabel()
                needsDisplay = true
                
                if let idx = NotesStore.shared.notes.firstIndex(where: { $0.id == noteId }) {
                    NotesStore.shared.notes[idx].color = color
                    NotesStore.shared.requestSave()
                }
                
                // Dismiss menu after selection
                self.enclosingMenuItem?.menu?.cancelTracking()
                return
            }
        }
        
        super.mouseDown(with: event)
    }
}

// MARK: - SwiftUI View Modifier for Custom Note Context Menu
private struct NoteContextMenuModifier: ViewModifier {
    let noteId: UUID
    
    func body(content: Content) -> some View {
        content.overlay(
            ContextMenuBridgeView(noteId: noteId)
                .allowsHitTesting(true)
        )
    }
}

private struct ContextMenuBridgeView: NSViewRepresentable {
    let noteId: UUID
    
    func makeNSView(context: Context) -> CustomMenuView {
        let view = CustomMenuView()
        view.menuProvider = {
            NoteContextMenu.makeMenu(for: noteId)
        }
        return view
    }
    
    func updateNSView(_ nsView: CustomMenuView, context: Context) {
        nsView.menuProvider = {
            NoteContextMenu.makeMenu(for: noteId)
        }
    }
}

private final class CustomMenuView: NSView {
    var menuProvider: (() -> NSMenu?)?
    
    override func menu(for event: NSEvent) -> NSMenu? {
        return menuProvider?()
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        // Only intercept right-clicks so normal clicks pass through to child buttons
        if let currentEvent = NSApp.currentEvent, currentEvent.type == .rightMouseDown {
            return self
        }
        return nil
    }
}

extension View {
    public func noteHeaderContextMenu(noteId: UUID) -> some View {
        self.modifier(NoteContextMenuModifier(noteId: noteId))
    }
    
    public func noteBodyContextMenu(noteId: UUID) -> some View {
        self.modifier(NoteBodyContextMenuModifier(noteId: noteId))
    }
}

// MARK: - SwiftUI View Modifier for Note Body Context Menu
private struct NoteBodyContextMenuModifier: ViewModifier {
    let noteId: UUID
    
    func body(content: Content) -> some View {
        content.overlay(
            BodyContextMenuBridgeView(noteId: noteId)
                .allowsHitTesting(true)
        )
    }
}

private struct BodyContextMenuBridgeView: NSViewRepresentable {
    let noteId: UUID
    
    func makeNSView(context: Context) -> CustomMenuView {
        let view = CustomMenuView()
        view.menuProvider = {
            NoteBodyContextMenu.makeMenu(for: noteId)
        }
        return view
    }
    
    func updateNSView(_ nsView: CustomMenuView, context: Context) {
        nsView.menuProvider = {
            NoteBodyContextMenu.makeMenu(for: noteId)
        }
    }
}

// MARK: - Note Body Context Menu (For remaining note window)
@MainActor
public final class NoteBodyContextMenu {
    
    public static func clipboardImage() -> NSImage? {
        let pasteboard = NSPasteboard.general
        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let first = images.first {
            return first
        }
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in urls {
                if let image = NSImage(contentsOf: url), image.isValid {
                    return image
                }
            }
        }
        return nil
    }
    
    /// Displays a native macOS popup menu for an image (paste or drag-and-drop),
    /// identical in styling, vibrancy, and behavior to the right-click context menu.
    public static func showImageActionMenu(
        for image: NSImage,
        noteId: UUID,
        at location: NSPoint,
        in view: NSView
    ) {
        let menu = NSMenu(title: "Image Options")
        menu.autoenablesItems = false
        let handler = NoteMenuActionHandler.shared
        let context = ImageActionContext(noteId: noteId, image: image)
        
        // 1. Header with thumbnail preview
        let thumb = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
            image.draw(in: rect)
            return true
        }
        let headerItem = NSMenuItem(title: "Image Detected", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        headerItem.image = thumb
        menu.addItem(headerItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 2. Paste Image
        let photoConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        let pasteImageItem = NSMenuItem(
            title: "Paste Image",
            action: #selector(handler.pasteImageAction(_:)),
            keyEquivalent: ""
        )
        pasteImageItem.image = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)?.withSymbolConfiguration(photoConfig)
        pasteImageItem.representedObject = context
        pasteImageItem.target = handler
        menu.addItem(pasteImageItem)
        
        // 3. Paste Image Text (Vision OCR)
        let pasteTextItem = NSMenuItem(
            title: "Paste Image Text (Vision OCR)",
            action: #selector(handler.pasteImageTextAction(_:)),
            keyEquivalent: ""
        )
        pasteTextItem.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: nil)?.withSymbolConfiguration(photoConfig)
        pasteTextItem.representedObject = context
        pasteTextItem.target = handler
        menu.addItem(pasteTextItem)
        
        menu.popUp(positioning: nil, at: location, in: view)
    }
    
    public static func makeMenu(for noteId: UUID, targetTextView: NSTextView? = nil) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        guard let note = NotesStore.shared.notes.first(where: { $0.id == noteId }) else {
            return menu
        }
        
        let handler = NoteMenuActionHandler.shared
        
        // 1. Image Actions (if clipboard has image)
        if clipboardImage() != nil {
            let pasteImageItem = NSMenuItem(
                title: "Paste Image",
                action: #selector(handler.pasteImageAction(_:)),
                keyEquivalent: ""
            )
            let photoConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            pasteImageItem.image = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)?.withSymbolConfiguration(photoConfig)
            pasteImageItem.representedObject = noteId
            pasteImageItem.target = handler
            menu.addItem(pasteImageItem)
            
            let pasteTextItem = NSMenuItem(
                title: "Paste Image Text (Vision OCR)",
                action: #selector(handler.pasteImageTextAction(_:)),
                keyEquivalent: ""
            )
            pasteTextItem.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: nil)?.withSymbolConfiguration(photoConfig)
            pasteTextItem.representedObject = noteId
            pasteTextItem.target = handler
            menu.addItem(pasteTextItem)
            
            menu.addItem(NSMenuItem.separator())
        }
        
        // 2. Text editing items if invoked inside a text view
        if let tv = targetTextView {
            let undoItem = NSMenuItem(title: "Undo", action: #selector(tv.undoManager?.undo), keyEquivalent: "z")
            undoItem.target = tv.undoManager
            undoItem.isEnabled = tv.undoManager?.canUndo ?? false
            menu.addItem(undoItem)
            
            let redoItem = NSMenuItem(title: "Redo", action: #selector(tv.undoManager?.redo), keyEquivalent: "Z")
            redoItem.target = tv.undoManager
            redoItem.isEnabled = tv.undoManager?.canRedo ?? false
            menu.addItem(redoItem)
            
            menu.addItem(NSMenuItem.separator())
            
            let cutItem = NSMenuItem(title: "Cut", action: #selector(tv.cut(_:)), keyEquivalent: "x")
            cutItem.target = tv
            cutItem.isEnabled = tv.selectedRange().length > 0
            menu.addItem(cutItem)
            
            let copyItem = NSMenuItem(title: "Copy", action: #selector(tv.copy(_:)), keyEquivalent: "c")
            copyItem.target = tv
            copyItem.isEnabled = tv.selectedRange().length > 0
            menu.addItem(copyItem)
            
            let pasteItem = NSMenuItem(title: "Paste", action: #selector(tv.paste(_:)), keyEquivalent: "v")
            pasteItem.target = tv
            menu.addItem(pasteItem)
            
            let selectAllItem = NSMenuItem(title: "Select All", action: #selector(tv.selectAll(_:)), keyEquivalent: "a")
            selectAllItem.target = tv
            menu.addItem(selectAllItem)
            
            menu.addItem(NSMenuItem.separator())
        }
        
        // 3. Lock Note
        let lockTitle = note.isLocked ? "Unlock Note" : "Lock Note"
        let lockIcon = note.isLocked ? "lock.open.fill" : "lock.fill"
        let lockItem = NSMenuItem(
            title: lockTitle,
            action: #selector(handler.lockNoteAction(_:)),
            keyEquivalent: "l"
        )
        lockItem.image = NSImage(systemSymbolName: lockIcon, accessibilityDescription: nil)
        lockItem.representedObject = noteId
        lockItem.target = handler
        menu.addItem(lockItem)
        
        // 4. Save As / Export Submenu
        let exportMenu = NSMenu(title: "Save As")
        
        let pdfItem = NSMenuItem(
            title: "Export as PDF...",
            action: #selector(handler.exportPDFAction(_:)),
            keyEquivalent: ""
        )
        pdfItem.image = NSImage(systemSymbolName: "doc.richtext", accessibilityDescription: nil)
        pdfItem.representedObject = noteId
        pdfItem.target = handler
        exportMenu.addItem(pdfItem)
        
        let mdItem = NSMenuItem(
            title: "Export as Markdown (.md)...",
            action: #selector(handler.exportMarkdownAction(_:)),
            keyEquivalent: ""
        )
        mdItem.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
        mdItem.representedObject = noteId
        mdItem.target = handler
        exportMenu.addItem(mdItem)
        
        let txtItem = NSMenuItem(
            title: "Export as Plain Text (.txt)...",
            action: #selector(handler.exportPlainTextAction(_:)),
            keyEquivalent: ""
        )
        txtItem.image = NSImage(systemSymbolName: "text.alignleft", accessibilityDescription: nil)
        txtItem.representedObject = noteId
        txtItem.target = handler
        exportMenu.addItem(txtItem)
        
        let exportParent = NSMenuItem(title: "Save As", action: nil, keyEquivalent: "")
        exportParent.image = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: nil)
        exportParent.submenu = exportMenu
        menu.addItem(exportParent)
        
        menu.addItem(NSMenuItem.separator())
        
        // 5. Capture Screen as Sticky
        let captureItem = NSMenuItem(
            title: "Capture Screen as Sticky...",
            action: #selector(handler.captureScreenAction(_:)),
            keyEquivalent: ""
        )
        captureItem.image = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: nil)
        captureItem.target = handler
        menu.addItem(captureItem)
        
        return menu
    }
}

// MARK: - Context Object for Direct Image Actions (e.g. from Drag & Drop or Paste)
@MainActor
public final class ImageActionContext: NSObject {
    public let noteId: UUID
    public let image: NSImage
    
    public init(noteId: UUID, image: NSImage) {
        self.noteId = noteId
        self.image = image
    }
}

// MARK: - Action Handler Target for Note Body Context Menu Items
@MainActor
final class NoteMenuActionHandler: NSObject {
    static let shared = NoteMenuActionHandler()
    
    @objc func pasteImageAction(_ sender: NSMenuItem) {
        if let ctx = sender.representedObject as? ImageActionContext {
            NotesStore.shared.addImageAttachment(to: ctx.noteId, image: ctx.image)
            return
        }
        guard let noteId = sender.representedObject as? UUID,
              let image = NoteBodyContextMenu.clipboardImage() else { return }
        NotesStore.shared.addImageAttachment(to: noteId, image: image)
    }
    
    @objc func pasteImageTextAction(_ sender: NSMenuItem) {
        let noteId: UUID
        let image: NSImage
        if let ctx = sender.representedObject as? ImageActionContext {
            noteId = ctx.noteId
            image = ctx.image
        } else if let id = sender.representedObject as? UUID,
                  let img = NoteBodyContextMenu.clipboardImage() {
            noteId = id
            image = img
        } else {
            return
        }
        
        VisionOCRService.shared.recognizeText(from: image) { recognizedText in
            guard let text = recognizedText, !text.isEmpty else {
                NSSound.beep()
                return
            }
            
            // If sticky text view is currently first responder, insert at current selection
            if let keyWin = NSApp.keyWindow,
               let tv = keyWin.firstResponder as? StickyTextView,
               tv.noteId == noteId {
                let sel = tv.selectedRange()
                if tv.shouldChangeText(in: sel, replacementString: text) {
                    tv.replaceCharacters(in: sel, with: text)
                    tv.didChangeText()
                    tv.setSelectedRange(NSRange(location: sel.location + (text as NSString).length, length: 0))
                    tv.renderMarkdown()
                    return
                }
            }
            
            // Otherwise append to note in store
            NotesStore.shared.appendContent(to: noteId, newText: text)
        }
    }
    
    @objc func lockNoteAction(_ sender: NSMenuItem) {
        guard let noteId = sender.representedObject as? UUID else { return }
        NotificationCenter.default.post(name: .toggleNoteLock, object: noteId)
    }
    
    @objc func exportPDFAction(_ sender: NSMenuItem) {
        guard let noteId = sender.representedObject as? UUID,
              let note = NotesStore.shared.notes.first(where: { $0.id == noteId }) else { return }
        NoteExportService.shared.exportToPDF(note: note, window: NSApp.keyWindow)
    }
    
    @objc func exportMarkdownAction(_ sender: NSMenuItem) {
        guard let noteId = sender.representedObject as? UUID,
              let note = NotesStore.shared.notes.first(where: { $0.id == noteId }) else { return }
        NoteExportService.shared.exportToMarkdown(note: note, window: NSApp.keyWindow)
    }
    
    @objc func exportPlainTextAction(_ sender: NSMenuItem) {
        guard let noteId = sender.representedObject as? UUID,
              let note = NotesStore.shared.notes.first(where: { $0.id == noteId }) else { return }
        NoteExportService.shared.exportToPlainText(note: note, window: NSApp.keyWindow)
    }
    
    @objc func captureScreenAction(_ sender: NSMenuItem) {
        ScreenCaptureService.shared.captureScreenInteractive()
    }
}

