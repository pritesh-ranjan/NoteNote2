import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Foundation

@MainActor
public final class ClipboardTyperService: ObservableObject {
    public static let shared = ClipboardTyperService()

    @Published public private(set) var isAccessibilityGranted: Bool = AXIsProcessTrusted()
    @Published public private(set) var isTyping: Bool = false

    private var typingTask: Task<Void, Never>?

    private struct KeyStrokeMapping: Sendable {
        let keyCode: CGKeyCode
        let needsShift: Bool
    }

    private init() {}

    public func refreshAccessibilityStatus() {
        isAccessibilityGranted = AXIsProcessTrusted()
    }

    public func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    public func promptForAccessibilityPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
        NoteNote needs Accessibility permission to type clipboard text as keystrokes into other apps.

        1. Enable NoteNote under Privacy & Security → Accessibility.
        2. Restart NoteNote if macOS doesn't apply the permission immediately.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Restart NoteNote")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openAccessibilitySettings()
        } else if response == .alertSecondButtonReturn {
            ScreenCaptureService.shared.restartApp()
        }
    }

    public func handleHotkeyPressed() {
        if isTyping {
            cancelTyping(reason: "shortcut pressed again")
            return
        }

        refreshAccessibilityStatus()
        guard isAccessibilityGranted else {
            AppLogger.info("Type Clipboard: accessibility permission not granted")
            promptForAccessibilityPermission()
            return
        }

        guard let rawText = NSPasteboard.general.string(forType: .string), !rawText.isEmpty else {
            AppLogger.info("Type Clipboard: clipboard has no plain text")
            if NotesStore.shared.settings.playSounds {
                NSSound.beep()
            }
            return
        }

        let normalizedText = rawText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let layoutMap = Self.buildCurrentKeyboardLayoutMap()
        let speed = NotesStore.shared.settings.typeClipboardSpeed

        isTyping = true
        GlobalHotkeyService.shared.registerCancelHotKey()
        AppLogger.info("Type Clipboard: starting (\(normalizedText.count) chars, speed: \(speed.rawValue))")

        typingTask = Task.detached(priority: .userInitiated) {
            await Self.typeText(normalizedText, layoutMap: layoutMap, speed: speed)
            await MainActor.run {
                ClipboardTyperService.shared.finishTypingSession()
            }
        }
    }

    private func finishTypingSession() {
        GlobalHotkeyService.shared.unregisterCancelHotKey()
        isTyping = false
        typingTask = nil
    }

    public func cancelTyping(reason: String = "cancelled") {
        guard isTyping || typingTask != nil else { return }
        typingTask?.cancel()
        typingTask = nil
        GlobalHotkeyService.shared.unregisterCancelHotKey()
        isTyping = false
        AppLogger.info("Type Clipboard: stopped (\(reason))")
    }

    // MARK: - Active Keyboard Layout Reverse Mapping (MainActor)

    private static let nonCharacterKeyCodes: Set<Int> = [
        kVK_Return, kVK_Tab, kVK_Delete, kVK_Escape,
        kVK_Command, kVK_RightCommand, kVK_Shift, kVK_RightShift,
        kVK_CapsLock, kVK_Option, kVK_RightOption,
        kVK_Control, kVK_RightControl, kVK_Function,
        kVK_ForwardDelete, kVK_Help, kVK_Home, kVK_End,
        kVK_PageUp, kVK_PageDown,
        kVK_LeftArrow, kVK_RightArrow, kVK_DownArrow, kVK_UpArrow,
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6,
        kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12,
        kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
        kVK_VolumeUp, kVK_VolumeDown, kVK_Mute
    ]

    private static func buildCurrentKeyboardLayoutMap() -> [UnicodeScalar: KeyStrokeMapping] {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue()
            ?? TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let rawPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return [:]
        }

        let layoutData = Unmanaged<CFData>.fromOpaque(rawPtr).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(layoutData) else { return [:] }
        let keyboardLayout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
        let keyboardType = UInt32(LMGetKbdType())

        var map: [UnicodeScalar: KeyStrokeMapping] = [:]
        let modifierStates: [(needsShift: Bool, state: UInt32)] = [
            (false, 0),
            (true, UInt32(shiftKey >> 8) & 0xFF)
        ]

        for (needsShift, modState) in modifierStates {
            for keyCode in 0..<128 where !nonCharacterKeyCodes.contains(keyCode) {
                var deadKeyState: UInt32 = 0
                var actualLength = 0
                var chars = [UniChar](repeating: 0, count: 4)

                let status = UCKeyTranslate(
                    keyboardLayout,
                    UInt16(keyCode),
                    UInt16(kUCKeyActionDown),
                    modState,
                    keyboardType,
                    0,
                    &deadKeyState,
                    chars.count,
                    &actualLength,
                    &chars
                )

                // Skip dead keys (deadKeyState != 0) so accented inputs fall back to Unicode events
                guard status == noErr, deadKeyState == 0, actualLength == 1 else { continue }
                let value = UInt32(chars[0])
                guard value >= 0x20, value <= 0x7E, let scalar = UnicodeScalar(value) else { continue }
                if map[scalar] == nil {
                    map[scalar] = KeyStrokeMapping(keyCode: CGKeyCode(keyCode), needsShift: needsShift)
                }
            }
        }

        return map
    }

    // MARK: - Keystroke Synthesis

    nonisolated private static func typeText(
        _ text: String,
        layoutMap: [UnicodeScalar: KeyStrokeMapping],
        speed: TypingSpeed
    ) async {
        // Wait for physical modifiers from the trigger hotkey to be released
        let watchedModifiers: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]
        for _ in 0..<100 {
            if Task.isCancelled { return }
            let current = CGEventSource.flagsState(.combinedSessionState)
            if current.intersection(watchedModifiers).isEmpty {
                break
            }
            try? await Task.sleep(nanoseconds: 15_000_000)
        }

        try? await Task.sleep(nanoseconds: 40_000_000)
        if Task.isCancelled { return }

        guard let source = CGEventSource(stateID: .privateState) else { return }

        var typedCount = 0
        for char in text {
            if Task.isCancelled { break }

            if char == "\n" {
                postVirtualKey(CGKeyCode(kVK_Return), flags: [], holdUs: speed.keyHoldUs, source: source)
                typedCount += 1
                try? await Task.sleep(nanoseconds: speed.specialKeyDelayNs)
            } else if char == "\t" {
                postVirtualKey(CGKeyCode(kVK_Tab), flags: [], holdUs: speed.keyHoldUs, source: source)
                typedCount += 1
                try? await Task.sleep(nanoseconds: speed.specialKeyDelayNs)
            } else if char.unicodeScalars.count == 1,
                      let scalar = char.unicodeScalars.first,
                      let mapping = layoutMap[scalar] {
                postMappedASCII(char: char, mapping: mapping, holdUs: speed.keyHoldUs, source: source)
                typedCount += 1
                try? await Task.sleep(nanoseconds: speed.interKeyDelayNs)
            } else {
                postUnicodeCharacter(char, holdUs: speed.keyHoldUs, source: source)
                typedCount += 1
                try? await Task.sleep(nanoseconds: speed.interKeyDelayNs)
            }
        }

        let cancelled = Task.isCancelled
        let finalTypedCount = typedCount
        await MainActor.run {
            AppLogger.info("Type Clipboard: \(cancelled ? "cancelled" : "finished") (\(finalTypedCount)/\(text.count) chars)")
        }
    }

    nonisolated private static func postVirtualKey(
        _ keyCode: CGKeyCode,
        flags: CGEventFlags,
        holdUs: useconds_t,
        source: CGEventSource
    ) {
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return
        }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        usleep(holdUs)
        up.post(tap: .cghidEventTap)
    }

    /// Executes Shift-down -> Key -> Shift-up atomically (no async suspension) so Shift cannot get stuck.
    nonisolated private static func postMappedASCII(
        char: Character,
        mapping: KeyStrokeMapping,
        holdUs: useconds_t,
        source: CGEventSource
    ) {
        let shiftKeyCode = CGKeyCode(kVK_Shift)
        let keyFlags: CGEventFlags = mapping.needsShift ? .maskShift : []
        var utf16 = Array(String(char).utf16)

        if mapping.needsShift,
           let shiftDown = CGEvent(keyboardEventSource: source, virtualKey: shiftKeyCode, keyDown: true) {
            shiftDown.flags = .maskShift
            shiftDown.post(tap: .cghidEventTap)
            usleep(1_500)
        }

        if let down = CGEvent(keyboardEventSource: source, virtualKey: mapping.keyCode, keyDown: true),
           let up = CGEvent(keyboardEventSource: source, virtualKey: mapping.keyCode, keyDown: false) {
            down.flags = keyFlags
            up.flags = keyFlags
            down.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
            up.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
            down.post(tap: .cghidEventTap)
            usleep(holdUs)
            up.post(tap: .cghidEventTap)
        }

        if mapping.needsShift,
           let shiftUp = CGEvent(keyboardEventSource: source, virtualKey: shiftKeyCode, keyDown: false) {
            usleep(1_500)
            shiftUp.flags = []
            shiftUp.post(tap: .cghidEventTap)
        }
    }

    nonisolated private static func postUnicodeCharacter(
        _ char: Character,
        holdUs: useconds_t,
        source: CGEventSource
    ) {
        let allUnits = Array(String(char).utf16)
        var offset = 0
        while offset < allUnits.count {
            let end = min(offset + 20, allUnits.count)
            var chunk = Array(allUnits[offset..<end])
            if let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
               let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                down.flags = []
                up.flags = []
                down.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: &chunk)
                up.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: &chunk)
                down.post(tap: .cghidEventTap)
                usleep(holdUs)
                up.post(tap: .cghidEventTap)
            }
            offset = end
        }
    }
}
