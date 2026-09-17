import SwiftUI

public struct SettingsView: View {
    @StateObject private var store = NotesStore.shared
    @ObservedObject private var startupService = StartupService.shared
    @State private var selectedTab: Int
    private let scrollToGestures: Bool
    
    public init(selectedTab: Int = 0, scrollToGestures: Bool = false) {
        self._selectedTab = State(initialValue: selectedTab)
        self.scrollToGestures = scrollToGestures
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Unified Top Header Bar with Centered Capsule Segmented Tabs matching README
            headerBar
            
            // Tab Content
            Group {
                switch selectedTab {
                case 0:
                    generalTab
                case 1:
                    shortcutsTab
                case 2:
                    aboutTab
                default:
                    generalTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 480)
        .frame(minHeight: 482)
        .background(Color(red: 0.125, green: 0.125, blue: 0.125))
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Header Bar
    private var headerBar: some View {
        HStack {
            Spacer()
            
            HStack(spacing: 0) {
                tabButton(title: "General", index: 0)
                divider
                tabButton(title: "Shortcuts", index: 1)
                divider
                tabButton(title: "About", index: 2)
            }
            .padding(3)
            .background(Color.black.opacity(0.45))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            )
            
            Spacer()
        }
        .padding(.top, 14)
        .padding(.bottom, 12)
    }
    
    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 1, height: 14)
    }
    
    private func tabButton(title: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.12)) {
                selectedTab = index
            }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: selectedTab == index ? .semibold : .medium))
                .foregroundColor(selectedTab == index ? .white : .white.opacity(0.75))
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .background(
                    Group {
                        if selectedTab == index {
                            Capsule()
                                .fill(Color(white: 0.28))
                                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                        } else {
                            Color.clear
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - General Tab
    private var generalTab: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
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
                            .tint(.blue)
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
                                    HStack(spacing: 8) {
                                        NoteColorSwatchView(color: color, size: 12)
                                        Text(color.displayName)
                                    }
                                    .tag(color)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 170)
                            .onChange(of: store.settings.defaultColor) { _, _ in
                                store.requestSave()
                            }
                        }
                        
                        Divider()
                            .padding(.leading, 14)
                        
                        settingRow(
                            title: "Screen Privacy Shield",
                            subtitle: "Hide notes from screenshots, screen recordings, and screen sharing by default"
                        ) {
                            Toggle("", isOn: $store.settings.defaultHideFromScreenCapture)
                                .toggleStyle(.switch)
                                .tint(.blue)
                                .labelsHidden()
                                .onChange(of: store.settings.defaultHideFromScreenCapture) { _, _ in
                                    store.requestSave()
                                }
                        }
                        
                        Divider()
                            .padding(.leading, 14)
                        
                        settingRow(
                            title: "Pin Notes on Top by Default",
                            subtitle: "Keep new sticky notes floating on top of all other app windows"
                        ) {
                            Toggle("", isOn: $store.settings.defaultPinned)
                                .toggleStyle(.switch)
                                .tint(.blue)
                                .labelsHidden()
                                .onChange(of: store.settings.defaultPinned) { _, _ in
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
                                .tint(.blue)
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
                
                // Section 3: Data & Storage
                settingsSection(title: "Data & Storage") {
                    VStack(spacing: 0) {
                        settingRow(
                            title: "Notes Storage File",
                            subtitle: "Stored in a dedicated file (~/Library/Application Support/NoteNote/notes.json), safely preserved across app reinstalls"
                        ) {
                            Button("Reveal in Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([store.notesFileURL])
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        
                        Divider()
                            .padding(.leading, 14)
                        
                        settingRow(
                            title: "Storage & Redundancy Folder",
                            subtitle: "Contains active notes, live backup snapshot (notes.backup.json), and trash"
                        ) {
                            Button("Open Folder") {
                                NSWorkspace.shared.open(store.storageDirectory)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 16)
        }
    }
    
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(white: 0.55))
                .textCase(.uppercase)
                .padding(.leading, 4)
            
            content()
                .background(Color(red: 0.155, green: 0.155, blue: 0.155))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
                )
        }
    }
    
    private func settingRow<Control: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(Color(white: 0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Spacer(minLength: 16)
            
            control()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
    
    // MARK: - Shortcuts Tab
    private var shortcutsTab: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    // 1. Active Sticky Note Window Shortcuts
                    settingsSection(title: "Active Note Window Shortcuts") {
                        VStack(spacing: 0) {
                            shortcutRow(
                                label: "Next Note",
                                keys: ["⌘", "]"],
                                desc: "Cycle to next note in its original position & size"
                            )
                            Divider().padding(.leading, 14)
                            shortcutRow(
                                label: "Previous Note",
                                keys: ["⌘", "["],
                                desc: "Cycle to previous note in its original position & size"
                            )
                            Divider().padding(.leading, 14)
                            shortcutRow(
                                label: "Pin / Unpin Active Note",
                                keys: ["⌘", "P"],
                                desc: "Toggle Always on Top floating level"
                            )
                            Divider().padding(.leading, 14)
                            shortcutRow(
                                label: "Lock Active Note",
                                keys: ["⌘", "L"],
                                desc: "Protect active note with Touch ID / Passcode"
                            )
                            Divider().padding(.leading, 14)
                            shortcutRow(
                                label: "Text Zoom In / Out",
                                keys: ["⌘", "+", "/", "−"],
                                desc: "Adjust font size (⌘0 to reset to 13pt)"
                            )
                            Divider().padding(.leading, 14)
                            shortcutRow(
                                label: "Markdown Formatting",
                                keys: ["⌘", "B", "I", "U"],
                                desc: "Bold, italic, underline, or strikethrough (⌘⇧X)"
                            )
                        }
                    }
                    
                    // 3. Trackpad Gestures
                    settingsSection(title: "Trackpad Gestures (Active Note Window)") {
                        VStack(spacing: 0) {
                            gestureRow(
                                label: "Swipe from Up",
                                gestureDesc: "Pull down from top or 3-finger swipe",
                                actionDesc: "Opens Spotlight Note Search HUD"
                            )
                            Divider().padding(.leading, 14)
                            gestureRow(
                                label: "Swipe Left",
                                gestureDesc: "2-finger swipe left or 3-finger swipe",
                                actionDesc: "Brings next note forward in original position & size"
                            )
                            Divider().padding(.leading, 14)
                            gestureRow(
                                label: "Swipe Right",
                                gestureDesc: "2-finger swipe right or 3-finger swipe",
                                actionDesc: "Brings previous note forward in original position & size"
                            )
                        }
                    }
                    .id("gesturesSection")
                    
                    // 4. Menu Bar & Layout Actions
                    settingsSection(title: "Menu Bar & Layout Shortcuts") {
                        VStack(spacing: 0) {
                            shortcutRow(
                                label: "New Sticky Note",
                                keys: ["⌘", "N"],
                                desc: "Create a new note when NoteNote menu is open"
                            )
                            Divider().padding(.leading, 14)
                            shortcutRow(
                                label: "Cascade Stack Layout",
                                keys: ["⌘", "⇧", "2"],
                                desc: "Neatly cascade notes from screen corner"
                            )
                            Divider().padding(.leading, 14)
                            shortcutRow(
                                label: "Tile Grid Layout",
                                keys: ["⌘", "⇧", "3"],
                                desc: "Arrange notes in a tidy desktop grid"
                            )
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 18)
            }
            .onAppear {
                if scrollToGestures {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        proxy.scrollTo("gesturesSection", anchor: .top)
                    }
                }
            }
        }
    }
    
    private func gestureRow(label: String, gestureDesc: String, actionDesc: String) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                Text(actionDesc)
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.6))
            }
            
            Spacer(minLength: 16)
            
            Text(gestureDesc)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(white: 0.55))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(white: 0.20))
                .cornerRadius(4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
    
    private func shortcutRow(label: String, keys: [String], desc: String) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.6))
            }
            
            Spacer(minLength: 16)
            
            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
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
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
    
    // MARK: - About Tab
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
                    .foregroundColor(.white)
                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.1.0") (macOS Native)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(white: 0.6))
            }
            
            Text("Fast, native, and always-on-top sticky notes built with pure Swift, SwiftUI, and AppKit.")
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .foregroundColor(Color(white: 0.7))
                .frame(maxWidth: 340)
            
            Spacer()
            
            Text("Built for macOS power users • Zero external dependencies")
                .font(.system(size: 11))
                .foregroundColor(Color(white: 0.45))
                .padding(.bottom, 12)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
