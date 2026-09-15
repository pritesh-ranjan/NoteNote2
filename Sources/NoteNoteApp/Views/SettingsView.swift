import SwiftUI

public struct SettingsView: View {
    @StateObject private var store = NotesStore.shared
    @ObservedObject private var startupService = StartupService.shared
    @State private var selectedTab = 0
    
    public init() {}
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(0)
            
            shortcutsTab
                .tabItem {
                    Label("Shortcuts", systemImage: "command")
                }
                .tag(1)
            
            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(2)
        }
        .frame(width: 500, height: 470)
    }
    
    private var generalTab: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // Section 1: System & Startup
                settingsSection(title: "System & Startup") {
                    VStack(spacing: 0) {
                        settingRow(
                            title: "Launch NoteNote at Login",
                            subtitle: "Automatically start NoteNote when you log in to your Mac so notes are ready"
                        ) {
                            Toggle("", isOn: Binding(
                                get: { startupService.isLaunchAtLoginEnabled },
                                set: { startupService.setLaunchAtLogin(enabled: $0) }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                        }
                    }
                }
                
                // Section 2: New Note Defaults
                settingsSection(title: "New Note Defaults") {
                    VStack(spacing: 0) {
                        settingRow(
                            title: "Default Note Color",
                            subtitle: "Initial color assigned when creating a new sticky note"
                        ) {
                            Picker("", selection: $store.settings.defaultColor) {
                                ForEach(NoteColor.allCases) { color in
                                    HStack {
                                        Circle()
                                            .fill(color.dotColor)
                                            .frame(width: 8, height: 8)
                                        Text(color.displayName)
                                    }
                                    .tag(color)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 140)
                            .onChange(of: store.settings.defaultColor) { _, _ in
                                store.requestSave()
                            }
                        }
                        
                        Divider()
                            .padding(.leading, 14)
                        
                        settingRow(
                            title: "Screen Privacy Shield",
                            subtitle: "Best-effort AppKit window privacy shield (hides from legacy capture) for newly created notes"
                        ) {
                            Toggle("", isOn: $store.settings.defaultHideFromScreenCapture)
                                .toggleStyle(.switch)
                                .labelsHidden()
                                .onChange(of: store.settings.defaultHideFromScreenCapture) { _, _ in
                                    store.requestSave()
                                }
                        }
                    }
                }
                
                // Section 3: Behavior & Docking
                settingsSection(title: "Behavior & Docking") {
                    VStack(spacing: 0) {
                        settingRow(
                            title: "Play Sound Effects",
                            subtitle: "Audio cues when creating, deleting, and snapping stickies"
                        ) {
                            Toggle("", isOn: $store.settings.playSounds)
                                .toggleStyle(.switch)
                                .labelsHidden()
                                .onChange(of: store.settings.playSounds) { _, _ in
                                    store.requestSave()
                                }
                        }
                        
                        Divider()
                            .padding(.leading, 14)
                        
                        settingRow(
                            title: "Default Edge Dock Side",
                            subtitle: "Which screen edge notes dock and fold into when dragged off-screen"
                        ) {
                            Picker("", selection: $store.settings.defaultDockEdge) {
                                Text("Right Edge").tag(DockEdge.right)
                                Text("Left Edge").tag(DockEdge.left)
                            }
                            .labelsHidden()
                            .frame(width: 130)
                            .onChange(of: store.settings.defaultDockEdge) { _, _ in
                                store.requestSave()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }
    
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 4)
            
            content()
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 0.5)
                )
        }
    }
    
    private func settingRow<Control: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Spacer(minLength: 16)
            
            control()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
    
    private var shortcutsTab: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Global Keyboard Shortcuts")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .padding(.leading, 4)
                
                VStack(spacing: 0) {
                    shortcutRow(label: "Quick Add Capture", keys: ["⌘", "⇧", "N"], desc: "Spotlight-style capture from anywhere")
                    Divider().padding(.leading, 14)
                    shortcutRow(label: "Show / Hide All Stickies", keys: ["⌘", "⇧", "H"], desc: "Instantly toggle all floating notes")
                    Divider().padding(.leading, 14)
                    shortcutRow(label: "New Sticky Note", keys: ["⌘", "N"], desc: "Create a new note")
                    Divider().padding(.leading, 14)
                    shortcutRow(label: "Cascade Stack Layout", keys: ["⌘", "⇧", "2"], desc: "Neatly cascade notes from corner")
                    Divider().padding(.leading, 14)
                    shortcutRow(label: "Tile Grid Layout", keys: ["⌘", "⇧", "3"], desc: "Arrange notes in a tidy grid")
                }
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 0.5)
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }
    
    private func shortcutRow(label: String, keys: [String], desc: String) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer(minLength: 16)
            
            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(NSColor.windowBackgroundColor))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 0.5)
                        )
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
    
    private var aboutTab: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "note.text")
                .font(.system(size: 52))
                .foregroundColor(.accentColor)
                .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
            
            VStack(spacing: 4) {
                Text("NoteNote")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1.0") (macOS Native)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Text("Fast, native, and always-on-top sticky notes built with pure Swift, SwiftUI, and AppKit.")
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 340)
            
            Spacer()
            
            Text("Built for macOS power users • Zero external dependencies")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.7))
                .padding(.bottom, 12)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
