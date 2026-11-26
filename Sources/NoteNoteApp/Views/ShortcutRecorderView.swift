import AppKit
import Carbon.HIToolbox
import SwiftUI

public struct ShortcutRecorderView: View {
    @Binding var shortcut: KeyShortcut
    let defaultShortcut: KeyShortcut
    var onChange: (KeyShortcut) -> Void

    @State private var isRecording = false
    @State private var validationHint: String? = nil
    @State private var keyMonitor: Any? = nil

    private static let modifierKeyCodes: Set<UInt16> = [
        UInt16(kVK_Command), UInt16(kVK_RightCommand),
        UInt16(kVK_Shift), UInt16(kVK_RightShift),
        UInt16(kVK_CapsLock),
        UInt16(kVK_Option), UInt16(kVK_RightOption),
        UInt16(kVK_Control), UInt16(kVK_RightControl),
        UInt16(kVK_Function)
    ]

    public init(
        shortcut: Binding<KeyShortcut>,
        defaultShortcut: KeyShortcut = .defaultTypeClipboard,
        onChange: @escaping (KeyShortcut) -> Void
    ) {
        self._shortcut = shortcut
        self.defaultShortcut = defaultShortcut
        self.onChange = onChange
    }

    public var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 6) {
                if isRecording {
                    HStack(spacing: 6) {
                        Text("Press shortcut…")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                        Button {
                            stopRecording()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Color(white: 0.65))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.22))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.blue.opacity(0.8), lineWidth: 1)
                    )
                } else {
                    Button {
                        startRecording()
                    } label: {
                        HStack(spacing: 4) {
                            ForEach(Array(shortcut.displayTokens.enumerated()), id: \.offset) { _, token in
                                Text(token)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color(white: 0.22))
                                    .cornerRadius(4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                                    )
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Click to record a new shortcut")

                    if shortcut != defaultShortcut {
                        Button {
                            shortcut = defaultShortcut
                            onChange(defaultShortcut)
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(white: 0.6))
                                .padding(4)
                        }
                        .buttonStyle(.plain)
                        .help("Reset to default (\(defaultShortcut.displayString))")
                    }
                }
            }

            if let hint = validationHint {
                Text(hint)
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        stopRecording()
        validationHint = nil
        isRecording = true
        GlobalHotkeyService.shared.setSuspendedForRecording(true)

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                DispatchQueue.main.async {
                    stopRecording()
                }
                return nil
            }

            if Self.modifierKeyCodes.contains(event.keyCode) {
                return nil
            }

            let carbonMods = KeyShortcut.carbonModifiers(from: event.modifierFlags)
            guard KeyShortcut.hasPrimaryModifier(carbonMods) else {
                DispatchQueue.main.async {
                    validationHint = "Include ⌘, ⌃, or ⌥"
                }
                return nil
            }

            let updated = KeyShortcut(keyCode: UInt32(event.keyCode), carbonModifiers: carbonMods)
            DispatchQueue.main.async {
                shortcut = updated
                onChange(updated)
                stopRecording()
            }
            return nil
        }
    }

    private func stopRecording() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        if isRecording {
            isRecording = false
            validationHint = nil
            GlobalHotkeyService.shared.setSuspendedForRecording(false)
        }
    }
}
