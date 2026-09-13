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
        .padding(20)
        .frame(width: 480, height: 430)
    }
    
    private var generalTab: some View {
        Form {
            Section {
                Toggle("Launch NoteNote at Mac Login (Start on Boot)", isOn: Binding(
                    get: { startupService.isLaunchAtLoginEnabled },
                    set: { startupService.setLaunchAtLogin(enabled: $0) }
                ))
                
                Text("NoteNote will automatically start whenever you log into your Mac so your stickies are immediately ready.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("System & Startup")
            }
            
            Section {
                HStack {
                    Text("New Note Color")
                    Spacer()
                    Text("Random Palette (Each Note)")
                        .foregroundColor(.secondary)
                }
                
                Toggle("Enable Screen Privacy Shield by default", isOn: $store.settings.defaultHideFromScreenCapture)
                    .onChange(of: store.settings.defaultHideFromScreenCapture) { _, _ in
                        store.requestSave()
                    }
            } header: {
                Text("New Note Defaults")
            }
            
            Section {
                Toggle("Play Sound Effects", isOn: $store.settings.playSounds)
                    .onChange(of: store.settings.playSounds) { _, _ in
                        store.requestSave()
                    }
                
                Picker("Default Edge Dock Side", selection: $store.settings.defaultDockEdge) {
                    Text("Right Edge").tag(DockEdge.right)
                    Text("Left Edge").tag(DockEdge.left)
                }
                .onChange(of: store.settings.defaultDockEdge) { _, _ in
                    store.requestSave()
                }
            } header: {
                Text("Behavior")
            }
        }
    }
    
    private var shortcutsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Global Keyboard Shortcuts")
                .font(.headline)
            
            VStack(spacing: 8) {
                shortcutRow(label: "Quick Add Capture", keys: ["⌘", "⇧", "N"], desc: "Spotlight-style capture from anywhere")
                shortcutRow(label: "Show / Hide All Stickies", keys: ["⌘", "⇧", "H"], desc: "Instantly toggle all floating notes")
                shortcutRow(label: "Capture Sticky Screenshot", keys: ["⌘", "⇧", "S"], desc: "Snip screen area directly into a note")
                shortcutRow(label: "New Sticky Note", keys: ["⌘", "N"], desc: "Create a new note")
                shortcutRow(label: "Cascade Stack Layout", keys: ["⌘", "⇧", "2"], desc: "Neatly cascade notes from corner")
                shortcutRow(label: "Tile Grid Layout", keys: ["⌘", "⇧", "3"], desc: "Arrange notes in a tidy grid")
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            
            Spacer()
        }
    }
    
    private func shortcutRow(label: String, keys: [String], desc: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                Text(desc)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(NSColor.windowBackgroundColor))
                        .cornerRadius(4)
                        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                }
            }
        }
    }
    
    private var aboutTab: some View {
        VStack(spacing: 12) {
            Spacer()
            
            Image(systemName: "note.text")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            
            Text("NoteNote for Mac")
                .font(.title2.bold())
            
            Text("Version 1.0.0")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Fast, native, and always-on-top sticky notes built with pure Swift, SwiftUI, and AppKit.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 24)
            
            Spacer()
            
            Text("Built for macOS power users")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.7))
        }
    }
}
