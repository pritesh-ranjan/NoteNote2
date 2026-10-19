import SwiftUI
import AppKit

// MARK: - Dashboard Tab Enum
public enum DashboardTab: String, CaseIterable, Identifiable {
    case macNotes = "Mac Notes"
    case phoneSync = "Phone Sync"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .macNotes: return "macwindow"
        case .phoneSync: return "iphone"
        }
    }
}

// MARK: - Main Dashboard View
@MainActor
public struct DashboardView: View {
    @ObservedObject private var store = NotesStore.shared
    @ObservedObject private var appWatcher = AppWatcherService.shared
    @ObservedObject private var syncServer = LocalSyncServer.shared
    
    @State private var selectedTab: DashboardTab = .macNotes
    @State private var searchQuery: String = ""
    
    public init() {}
    
    private var currentNotes: [NoteModel] {
        let source = selectedTab == .phoneSync ? store.syncedNotes : store.notes
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.isEmpty {
            return source
        }
        return source.filter { note in
            if note.title.lowercased().contains(trimmed) { return true }
            if note.content.lowercased().contains(trimmed) { return true }
            if let appName = note.linkedAppName, appName.lowercased().contains(trimmed) { return true }
            return false
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // 1. Solid, Non-Transparent Header Bar
            headerBar
            
            // 2. Main Content Area (Clean borderless card grid)
            contentArea
        }
        .frame(minWidth: 640, minHeight: 440)
        .background(Color(red: 0.12, green: 0.125, blue: 0.14))
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Header Bar (Solid, Non-Transparent, Top-Left Title)
    private var headerBar: some View {
        HStack(spacing: 16) {
            // Traffic Light Clearance Space
            Spacer()
                .frame(width: 68)
            
            // Top Left: "Notes Dashboard"
            Text("Notes Dashboard")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            // Two Tabs Switcher: [ Mac Notes ]  [ Phone Sync ]
            HStack(spacing: 2) {
                tabButton(tab: .macNotes)
                tabButton(tab: .phoneSync)
            }
            .padding(3)
            .background(Color.black.opacity(0.35))
            .clipShape(Capsule())
            
            Spacer()
            
            // Minimalist Search Field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.40))
                
                TextField("Filter...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .frame(width: 120)
                
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            
            // Action Buttons
            HStack(spacing: 6) {
                // Search HUD (Triggers Spotlight Search)
                Button {
                    SearchNotesWindowController.shared.presentSearch()
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.85))
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Spotlight Search HUD")
                
                // Show Deleted Notes (Trash & Recovery)
                Button {
                    TrashWindowController.shared.show()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(store.deletedNotes.isEmpty ? Color.white.opacity(0.85) : Color(red: 0.98, green: 0.45, blue: 0.40))
                        
                        if !store.deletedNotes.isEmpty {
                            Text("\(store.deletedNotes.count)")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.red.opacity(0.85))
                                .clipShape(Capsule())
                        }
                    }
                    .frame(height: 26)
                    .padding(.horizontal, store.deletedNotes.isEmpty ? 7 : 6)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Show Deleted Notes (Trash & Recovery)")
                
                // Gear Icon (Preferences)
                Button {
                    SettingsWindowController.shared.show()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.85))
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Preferences")
                
                // + New Sticky Note
                Button {
                    let note = store.createNote()
                    StickyWindowManager.shared.focusNote(id: note.id)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("New")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 9)
                    .frame(height: 26)
                    .background(Color(red: 0.20, green: 0.55, blue: 0.95))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Create a new sticky note")
            }
            .padding(.trailing, 16)
        }
        .padding(.vertical, 10)
        .background(Color(red: 0.12, green: 0.125, blue: 0.14))
    }
    
    private func tabButton(tab: DashboardTab) -> some View {
        let isSelected = selectedTab == tab
        let count = tab == .phoneSync ? store.syncedNotes.count : store.notes.count
        
        return Button {
            withAnimation(.easeInOut(duration: 0.12)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                Text(tab.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(isSelected ? .white : Color.white.opacity(0.5))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(isSelected ? Color.white.opacity(0.25) : Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
            .foregroundColor(isSelected ? .white : Color.white.opacity(0.65))
            .padding(.horizontal, 11)
            .padding(.vertical, 4)
            .background(
                Group {
                    if isSelected {
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
    
    // MARK: - Content Area
    private var contentArea: some View {
        let notes = currentNotes
        
        return Group {
            if notes.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 240, maximum: 320), spacing: 14)],
                        spacing: 14
                    ) {
                        ForEach(notes) { note in
                            DashboardNoteCard(
                                note: note,
                                onFocus: {
                                    if selectedTab == .phoneSync {
                                        store.promoteSyncedNoteToDesktop(id: note.id)
                                    } else {
                                        StickyWindowManager.shared.focusNote(id: note.id)
                                    }
                                },
                                onTogglePin: {
                                    if selectedTab == .phoneSync {
                                        if let idx = store.syncedNotes.firstIndex(where: { $0.id == note.id }) {
                                            store.syncedNotes[idx].isPinned.toggle()
                                            store.requestSave()
                                        }
                                    } else {
                                        store.togglePin(id: note.id)
                                    }
                                }
                            )
                        }
                    }
                    .padding(18)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            
            if selectedTab == .phoneSync {
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .font(.system(size: 38, weight: .light))
                    .foregroundColor(Color.white.opacity(0.35))
                
                Text("Phone Sync")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
                
                Text("Connect your phone on the same Wi-Fi network to sync stickies seamlessly.")
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
                
                if !syncServer.isRunning {
                    Button("Turn On Wi-Fi Sync") {
                        store.settings.wifiSyncEnabled = true
                        store.requestSave()
                        syncServer.start()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.20, green: 0.55, blue: 0.95))
                    .padding(.top, 4)
                } else {
                    HStack(spacing: 5) {
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                        Text("Ready for pairing on local Wi-Fi")
                            .font(.system(size: 11))
                            .foregroundColor(Color.white.opacity(0.6))
                    }
                    .padding(.top, 4)
                }
            } else if !searchQuery.isEmpty {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(Color.white.opacity(0.3))
                
                Text("No notes match \"\(searchQuery)\"")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
                
                Button("Clear Search") {
                    searchQuery = ""
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.top, 4)
            } else {
                Image(systemName: "note.text")
                    .font(.system(size: 38, weight: .light))
                    .foregroundColor(Color.white.opacity(0.3))
                
                Text("No Sticky Notes Yet")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
                
                Button {
                    let newNote = store.createNote()
                    StickyWindowManager.shared.focusNote(id: newNote.id)
                } label: {
                    Label("Create Sticky Note", systemImage: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.20, green: 0.55, blue: 0.95))
                .padding(.top, 4)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Simplified Dashboard Note Card
@MainActor
public struct DashboardNoteCard: View {
    let note: NoteModel
    let onFocus: () -> Void
    let onTogglePin: () -> Void
    
    @ObservedObject private var appWatcher = AppWatcherService.shared
    @State private var isHovered: Bool = false
    
    private var linkedAppIcon: NSImage? {
        guard let bundleId = note.linkedAppBundleId, !bundleId.isEmpty else { return nil }
        if let running = appWatcher.runningApps.first(where: { $0.bundleIdentifier == bundleId }), let icon = running.icon {
            return icon
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return nil
    }
    
    private var contentSnippet: String {
        let lines = note.content.components(separatedBy: .newlines)
            .map { $0.cleanMarkdownStripped }
            .filter { !$0.isEmpty }
        if lines.isEmpty {
            return "No content"
        }
        return lines.prefix(2).joined(separator: " • ")
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header Row: Color Dot + Title + Pin Button
            HStack(spacing: 6) {
                // Subtle 7pt Theme Color Dot
                Circle()
                    .fill(note.color.dotColor)
                    .frame(width: 7, height: 7)
                
                // Note Title
                Text(note.displayTitle)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                // Only Button: Pin / Unpin
                Button(action: onTogglePin) {
                    Image(systemName: note.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 11))
                        .foregroundColor(note.isPinned ? Color(red: 1.0, green: 0.78, blue: 0.28) : Color.white.opacity(0.35))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(note.isPinned ? "Unpin note" : "Pin note on top")
            }
            
            // Truncated Content Snippet
            Text(contentSnippet)
                .font(.system(size: 11))
                .foregroundColor(Color.white.opacity(0.60))
                .lineLimit(2)
                .frame(minHeight: 28, alignment: .topLeading)
            
            // Metadata: Date + Bound App (Only if bound) + Photos
            HStack(spacing: 8) {
                // Date modified/created
                Text(note.updatedAt.relativeTimeString)
                    .font(.system(size: 10))
                    .foregroundColor(Color.white.opacity(0.40))
                
                // Bound Apps — ONLY shown when something is actually bound!
                if let appName = note.linkedAppName, !appName.isEmpty {
                    HStack(spacing: 4) {
                        if let icon = linkedAppIcon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 10, height: 10)
                        } else {
                            Image(systemName: "link")
                                .font(.system(size: 8))
                        }
                        Text(appName)
                            .font(.system(size: 9, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundColor(Color.white.opacity(0.85))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Capsule())
                }
                
                // Photos Badge
                if !note.imageAttachments.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "photo")
                            .font(.system(size: 8))
                        Text("\(note.imageAttachments.count)")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundColor(Color.white.opacity(0.65))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }
                
                Spacer()
            }
        }
        .padding(12)
        .background(
            ZStack {
                // Subtle tint of note color
                note.color.backgroundColor.opacity(0.05)
                // Solid dark card surface — NO borders/strokes!
                Color(red: 0.16, green: 0.17, blue: 0.19)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(
            color: Color.black.opacity(isHovered ? 0.35 : 0.12),
            radius: isHovered ? 8 : 3,
            x: 0,
            y: isHovered ? 3 : 1
        )
        .offset(y: isHovered ? -2 : 0)
        .scaleEffect(isHovered ? 1.012 : 1.0)
        .animation(.easeInOut(duration: 0.14), value: isHovered)
        .onHover { isHovered = $0 }
        .onTapGesture {
            onFocus()
        }
    }
}
