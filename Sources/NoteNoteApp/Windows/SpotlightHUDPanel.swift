import AppKit
import SwiftUI

@MainActor
public final class SpotlightHUDPanel: NSPanel {
    public static let standardWidth: CGFloat = 540
    
    public var onDismiss: (() -> Void)?
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?
    
    public static func standardFrame(height: CGFloat) -> NSRect {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let width = standardWidth
        let x = screen.visibleFrame.midX - (width / 2)
        // Top-anchored origin: top edge stays at constant position across HUD sizes
        let y = screen.visibleFrame.maxY - height - 130
        return NSRect(x: x, y: y, width: width, height: height)
    }
    
    public init(contentRect: NSRect, onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.hidesOnDeactivate = false
    }
    
    public override var canBecomeKey: Bool {
        return true
    }
    
    public override var canBecomeMain: Bool {
        return true
    }
    
    // Clicking outside deactivates key status -> dismiss immediately
    public override func resignKey() {
        super.resignKey()
        handleDismiss()
    }
    
    public func startMonitoringClicksOutside() {
        stopMonitoringClicksOutside()
        
        // 1. Monitor global clicks when another app or desktop is clicked
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.isVisible else { return }
            let clickPoint = NSEvent.mouseLocation
            if !self.frame.contains(clickPoint) {
                self.handleDismiss()
            }
        }
        
        // 2. Monitor local clicks within the app (e.g. clicking a background note or menu)
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.isVisible else { return event }
            if event.window != self {
                self.handleDismiss()
            }
            return event
        }
    }
    
    public func stopMonitoringClicksOutside() {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
        if let monitor = localClickMonitor {
            NSEvent.removeMonitor(monitor)
            localClickMonitor = nil
        }
    }
    
    private func handleDismiss() {
        stopMonitoringClicksOutside()
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isVisible else { return }
            self.orderOut(nil)
            self.onDismiss?()
        }
    }
    
    public override var contentView: NSView? {
        didSet {
            setupContentView()
        }
    }
    
    private func setupContentView() {
        guard let cv = self.contentView else { return }
        cv.wantsLayer = true
        cv.layer?.cornerRadius = 16
        cv.layer?.cornerCurve = .continuous
        cv.layer?.masksToBounds = true
        cv.layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    public func present() {
        setupContentView()
        invalidateShadow()
        makeKeyAndOrderFront(nil)
        makeKey()
        NSApp.activate(ignoringOtherApps: true)
        startMonitoringClicksOutside()
    }
    
    public func dismiss() {
        stopMonitoringClicksOutside()
        orderOut(nil)
        onDismiss?()
    }
    
    deinit {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localClickMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

// MARK: - Shared Spotlight Visual Styling
public struct SpotlightHUDStyle: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ZStack {
                    VisualEffectView(material: .hudWindow, blendingMode: .behindWindow, cornerRadius: 16)
                    Color(red: 0.12, green: 0.13, blue: 0.16).opacity(0.85)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            )
    }
}

extension View {
    public func spotlightHUDStyle() -> some View {
        self.modifier(SpotlightHUDStyle())
    }
}
