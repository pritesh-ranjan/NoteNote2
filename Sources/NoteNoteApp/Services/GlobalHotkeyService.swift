import Carbon.HIToolbox
import Combine
import Foundation

@MainActor
public final class GlobalHotkeyService: ObservableObject {
    public static let shared = GlobalHotkeyService()

    @Published public private(set) var registrationError: String? = nil

    private var eventHandlerRef: EventHandlerRef?
    private var typeClipboardHotKeyRef: EventHotKeyRef?
    private var cancelHotKeyRef: EventHotKeyRef?
    private var isSuspendedForRecording = false

    nonisolated private static let signature: OSType = 0x4E4E484B // 'NNHK'
    nonisolated private static let typeClipboardHotKeyID: UInt32 = 1
    nonisolated private static let cancelHotKeyID: UInt32 = 2

    private init() {}

    public func start() {
        guard eventHandlerRef == nil else {
            syncWithSettings()
            return
        }

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, _ -> OSStatus in
                guard let eventRef else { return OSStatus(eventNotHandledErr) }
                var hotKeyID = EventHotKeyID()
                let err = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard err == noErr, hotKeyID.signature == GlobalHotkeyService.signature else {
                    return OSStatus(eventNotHandledErr)
                }
                let id = hotKeyID.id
                DispatchQueue.main.async {
                    GlobalHotkeyService.shared.handleHotKey(id: id)
                }
                return noErr
            },
            1,
            &eventSpec,
            nil,
            &eventHandlerRef
        )

        if status != noErr {
            AppLogger.error("Failed to install Carbon hotkey event handler (status: \(status))")
        }

        syncWithSettings()
    }

    public func stop() {
        unregisterTypeClipboardHotKey()
        unregisterCancelHotKey()
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }

    public func syncWithSettings() {
        unregisterTypeClipboardHotKey()
        registrationError = nil

        guard !isSuspendedForRecording, NotesStore.shared.settings.typeClipboardEnabled else {
            return
        }

        let shortcut = NotesStore.shared.settings.typeClipboardShortcut
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: Self.typeClipboardHotKeyID)
        var ref: EventHotKeyRef?

        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        if status == noErr {
            typeClipboardHotKeyRef = ref
            AppLogger.info("Registered Type Clipboard hotkey: \(shortcut.displayString)")
        } else {
            registrationError = "Shortcut \(shortcut.displayString) is already in use by another app or macOS."
            AppLogger.warning("Failed to register Type Clipboard hotkey \(shortcut.displayString) (status: \(status))")
        }
    }

    public func setSuspendedForRecording(_ suspended: Bool) {
        guard isSuspendedForRecording != suspended else { return }
        isSuspendedForRecording = suspended
        syncWithSettings()
    }

    public func registerCancelHotKey() {
        unregisterCancelHotKey()
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: Self.cancelHotKeyID)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(kVK_Escape),
            0,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr {
            cancelHotKeyRef = ref
        }
    }

    public func unregisterCancelHotKey() {
        if let ref = cancelHotKeyRef {
            UnregisterEventHotKey(ref)
            cancelHotKeyRef = nil
        }
    }

    private func unregisterTypeClipboardHotKey() {
        if let ref = typeClipboardHotKeyRef {
            UnregisterEventHotKey(ref)
            typeClipboardHotKeyRef = nil
        }
    }

    private func handleHotKey(id: UInt32) {
        switch id {
        case Self.typeClipboardHotKeyID:
            ClipboardTyperService.shared.handleHotkeyPressed()
        case Self.cancelHotKeyID:
            ClipboardTyperService.shared.cancelTyping(reason: "Escape key")
        default:
            break
        }
    }
}
