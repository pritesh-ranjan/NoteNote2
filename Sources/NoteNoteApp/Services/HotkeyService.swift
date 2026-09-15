import AppKit
import Carbon

@MainActor
public final class HotkeyService {
    public static let shared = HotkeyService()
    
    private var eventHandler: EventHandlerRef?
    private var quickAddHotKeyRef: EventHotKeyRef?
    private var toggleAllHotKeyRef: EventHotKeyRef?
    private var localMonitor: Any?
    
    public var onQuickAddTriggered: (() -> Void)?
    public var onToggleAllTriggered: (() -> Void)?
    
    private init() {}
    
    public func start() {
        // 1. Register native macOS Carbon Event Handler (works system-wide without Accessibility privileges)
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, theEvent, userData) -> OSStatus in
                var hotKeyID = EventHotKeyID()
                let err = GetEventParameter(
                    theEvent,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                if err == noErr {
                    DispatchQueue.main.async {
                        if hotKeyID.id == 1 {
                            AppLogger.info("Global shortcut triggered: Quick Add (⌘⇧N)")
                            HotkeyService.shared.onQuickAddTriggered?()
                        } else if hotKeyID.id == 2 {
                            AppLogger.info("Global shortcut triggered: Toggle All Notes (⌘⇧H)")
                            HotkeyService.shared.onToggleAllTriggered?()
                        }
                    }
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandler
        )
        
        if installStatus != noErr {
            AppLogger.error("Failed to install Carbon hotkey handler: \(installStatus)")
        }
        
        // 2. Register ⌘⇧N for Quick Add
        let quickAddID = EventHotKeyID(signature: OSType(0x4E4F5445), id: 1) // 'NOTE', 1
        let regN = RegisterEventHotKey(
            UInt32(kVK_ANSI_N),
            UInt32(cmdKey | shiftKey),
            quickAddID,
            GetApplicationEventTarget(),
            0,
            &quickAddHotKeyRef
        )
        if regN == noErr {
            AppLogger.info("Registered Carbon global hotkey: ⌘⇧N (Quick Add)")
        } else {
            AppLogger.warning("RegisterEventHotKey for ⌘⇧N returned \(regN)")
        }
        
        // 3. Register ⌘⇧H for Toggle All Stickies
        let toggleAllID = EventHotKeyID(signature: OSType(0x4E4F5445), id: 2) // 'NOTE', 2
        let regH = RegisterEventHotKey(
            UInt32(kVK_ANSI_H),
            UInt32(cmdKey | shiftKey),
            toggleAllID,
            GetApplicationEventTarget(),
            0,
            &toggleAllHotKeyRef
        )
        if regH == noErr {
            AppLogger.info("Registered Carbon global hotkey: ⌘⇧H (Toggle All Stickies)")
        } else {
            AppLogger.warning("RegisterEventHotKey for ⌘⇧H returned \(regH)")
        }
        
        // 4. Local in-app monitor fallback
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleLocalKeyEvent(event) == true {
                return nil
            }
            return event
        }
    }
    
    @discardableResult
    private func handleLocalKeyEvent(_ event: NSEvent) -> Bool {
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
        if let ref = quickAddHotKeyRef {
            UnregisterEventHotKey(ref)
            quickAddHotKeyRef = nil
        }
        if let ref = toggleAllHotKeyRef {
            UnregisterEventHotKey(ref)
            toggleAllHotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
        if let local = localMonitor {
            NSEvent.removeMonitor(local)
            localMonitor = nil
        }
        AppLogger.info("HotkeyService stopped.")
    }
}
