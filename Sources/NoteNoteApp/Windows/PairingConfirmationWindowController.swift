import AppKit
import SwiftUI
import Combine

@MainActor
public final class PairingConfirmationWindowController: NSObject, NSWindowDelegate {
    public static let shared = PairingConfirmationWindowController()
    
    private var window: NSWindow?
    private var completionHandler: ((Bool) -> Void)?
    
    private override init() {
        super.init()
    }
    
    public func present(
        session: ActivePairingSession,
        completion: @escaping (Bool) -> Void
    ) {
        // Cancel any existing session prompt
        dismiss(confirmed: false)
        self.completionHandler = completion
        
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 320),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.title = "Pairing Request"
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.isMovableByWindowBackground = true
        win.level = .floating
        win.center()
        win.backgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
        win.isReleasedWhenClosed = false
        win.delegate = self
        
        let rootView = PairingConfirmationView(session: session) { [weak self] confirmed in
            self?.dismiss(confirmed: confirmed)
        }
        win.contentView = NSHostingView(rootView: rootView)
        
        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func dismiss(confirmed: Bool) {
        if let handler = completionHandler {
            completionHandler = nil
            handler(confirmed)
        }
        window?.orderOut(nil)
        window = nil
    }
    
    public func windowWillClose(_ notification: Notification) {
        dismiss(confirmed: false)
    }
}

// MARK: - SwiftUI Confirmation View
public struct PairingConfirmationView: View {
    public let session: ActivePairingSession
    public let onComplete: (Bool) -> Void
    
    @State private var timeRemaining: Int = 60
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    public var formattedCode: String {
        guard session.sixDigitCode.count == 6 else { return session.sixDigitCode }
        let first = session.sixDigitCode.prefix(3)
        let last = session.sixDigitCode.suffix(3)
        return "\(first) \(last)"
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Icon & Header
            VStack(spacing: 8) {
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .font(.system(size: 36))
                    .foregroundColor(Color(red: 0.35, green: 0.75, blue: 1.0))
                    .padding(.top, 8)
                
                Text("Pairing Request")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("\"\(session.deviceName)\" wants to pair for note syncing over Wi-Fi.")
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            
            // 6-Digit Code Box
            VStack(spacing: 4) {
                Text("CONFIRMATION CODE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.45))
                    .tracking(1.2)
                
                Text(formattedCode)
                    .font(.system(size: 36, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                    .tracking(4)
                    .padding(.vertical, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            )
            .padding(.horizontal, 20)
            
            Text("Confirm this exact code matches the code shown on your phone.")
                .font(.system(size: 11))
                .foregroundColor(Color.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Spacer(minLength: 4)
            
            // Action Buttons
            HStack(spacing: 12) {
                Button("Decline") {
                    onComplete(false)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .keyboardShortcut(.cancelAction)
                
                Button("Confirm & Pair") {
                    onComplete(true)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.20, green: 0.55, blue: 0.95))
                .controlSize(.regular)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.bottom, 6)
            
            Text("Expires in \(timeRemaining)s")
                .font(.system(size: 10))
                .foregroundColor(Color.white.opacity(0.35))
        }
        .padding(20)
        .frame(width: 380, height: 320)
        .preferredColorScheme(.dark)
        .onReceive(timer) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                onComplete(false)
            }
        }
    }
}
