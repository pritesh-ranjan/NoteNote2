import AppKit

@MainActor
public final class HotkeyService {
    public static let shared = HotkeyService()
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    public var onQuickAddTriggered: (() -> Void)?
    public var onToggleAllTriggered: (() -> Void)?
    
    private init() {}
    
    public func start() {
        // Monitor global key downs (Command + Shift + N / H)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        
        // Monitor local key downs inside app
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil // Handled
            }
            return event
        }
    }
    
    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isCmdShift = flags == [.command, .shift]
        
        guard let chars = event.charactersIgnoringModifiers?.uppercased() else {
            return false
        }
        
        if isCmdShift && chars == "N" {
            onQuickAddTriggered?()
            return true
        }
        
        if isCmdShift && chars == "H" {
            onToggleAllTriggered?()
            return true
        }
        
        return false
    }
    
    public func stop() {
        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
    }
}
