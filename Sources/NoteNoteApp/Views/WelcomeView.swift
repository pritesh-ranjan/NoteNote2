import SwiftUI
import AppKit

public struct WelcomeView: View {
    @ObservedObject private var startupService = StartupService.shared
    @State private var launchAtLogin: Bool = true
    public var onClose: (() -> Void)?
    
    public init(onClose: (() -> Void)? = nil) {
        self.onClose = onClose
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 10) {
                if let appIcon = NSImage(named: "AppIcon") {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 72, height: 72)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(LinearGradient(colors: [Color.yellow, Color.orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 68, height: 68)
                            .shadow(color: Color.orange.opacity(0.3), radius: 8, x: 0, y: 4)
                        
                        Image(systemName: "note.text")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                
                Text("Welcome to NoteNote")
                    .font(.system(size: 24, weight: .bold))
                
                Text("Fast, native, always-on-top sticky notes for your Mac.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
            
            // Feature / Setup Cards
            VStack(spacing: 12) {
                featureRow(
                    icon: "sparkles",
                    iconColor: .orange,
                    title: "Ready on Startup",
                    description: "NoteNote automatically launches with your Mac so your reminders and notes are always in place."
                )
                
                featureRow(
                    icon: "menubar.rectangle",
                    iconColor: .blue,
                    title: "Lives in Your Menu Bar",
                    description: "Click the NoteNote icon in your top menu bar anytime to create notes, cascade, tile, or adjust preferences."
                )
                
                featureRow(
                    icon: "command",
                    iconColor: .purple,
                    title: "Global Quick Add (⌘⇧N)",
                    description: "Press ⌘⇧N from any app on your Mac to summon the instant capture bar without interrupting your workflow."
                )
                
                featureRow(
                    icon: "shield.lefthalf.filled",
                    iconColor: .green,
                    title: "Screen Privacy Shield",
                    description: "Keep confidential notes, tokens, or passwords 100% invisible during Zoom, Teams, or screen sharing."
                )
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
            .cornerRadius(12)
            
            // Startup Toggle & Get Started Button
            VStack(spacing: 14) {
                Toggle("Launch NoteNote automatically at Mac login", isOn: $launchAtLogin)
                    .toggleStyle(.checkbox)
                    .font(.callout)
                    .onChange(of: launchAtLogin) { _, newValue in
                        startupService.setLaunchAtLogin(enabled: newValue)
                    }
                
                Button(action: {
                    onClose?()
                }) {
                    Text("Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.bottom, 6)
        }
        .padding(26)
        .frame(width: 500, height: 520)
        .onAppear {
            startupService.refreshStatus()
            launchAtLogin = startupService.isLaunchAtLoginEnabled
        }
    }
    
    private func featureRow(icon: String, iconColor: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}
