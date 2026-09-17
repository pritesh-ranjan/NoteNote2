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
    
    init(noteId: UUID, currentNote: NoteModel) {
        self.noteId = noteId
        self.currentColor = currentNote.color
        self.currentOpacity = currentNote.opacity
        super.init(frame: NSRect(x: 0, y: 0, width: 236, height: 74))
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        wantsLayer = true
        
        // 1. Color Title Label
        colorLabel.font = .systemFont(ofSize: 10, weight: .bold)
        colorLabel.textColor = .secondaryLabelColor
        colorLabel.isSelectable = false
        colorLabel.focusRingType = .none
        colorLabel.frame = NSRect(x: 14, y: 54, width: 208, height: 14)
        addSubview(colorLabel)
        
        // 2. Compute swatch circle frames
        let startX: CGFloat = 14
        let circleY: CGFloat = 28
        let circleSize: CGFloat = 20
        let spacing: CGFloat = 11
        
        swatchRects = NoteColor.allCases.enumerated().map { index, color in
            let x = startX + CGFloat(index) * (circleSize + spacing)
            return (NSRect(x: x, y: circleY, width: circleSize, height: circleSize), color)
        }
        
        // 3. Opacity Slider (no text above, no focus ring)
        opacitySlider.minValue = 0.20
        opacitySlider.maxValue = 1.0
        opacitySlider.doubleValue = max(0.2, min(1.0, currentOpacity))
        opacitySlider.isContinuous = true
        opacitySlider.focusRingType = .none
        opacitySlider.target = self
        opacitySlider.action = #selector(sliderDidMove(_:))
        opacitySlider.frame = NSRect(x: 12, y: 6, width: 212, height: 16)
        addSubview(opacitySlider)
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
        
        // Draw Swatches
        for (rect, color) in swatchRects {
            let isSelected = (color == currentColor)
            
            // Draw circle fill
            context.setFillColor(color.nsDotColor.cgColor)
            context.fillEllipse(in: rect)
            
            // Subtle border for light/dark colors
            context.setStrokeColor(NSColor.black.withAlphaComponent(0.18).cgColor)
            context.setLineWidth(1.0)
            context.strokeEllipse(in: rect)
            
            // If selected, draw a crisp white and accent indicator ring
            if isSelected {
                let ringRect = rect.insetBy(dx: -2.5, dy: -2.5)
                context.setStrokeColor(NSColor.controlAccentColor.cgColor)
                context.setLineWidth(2.0)
                context.strokeEllipse(in: ringRect)
                
                // Draw inner dot or check
                let innerRect = rect.insetBy(dx: 5.5, dy: 5.5)
                context.setFillColor(NSColor.white.withAlphaComponent(0.95).cgColor)
                context.fillEllipse(in: innerRect)
            }
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        
        // Check if any color circle was clicked
        for (rect, color) in swatchRects {
            if rect.contains(point) {
                currentColor = color
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
}
