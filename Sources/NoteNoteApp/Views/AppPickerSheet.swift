import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct AppPickerSheet: View {
    let currentBundleId: String?
    let onSelect: (String?, String?) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var appWatcher = AppWatcherService.shared
    @State private var searchText = ""
    
    public init(currentBundleId: String?, onSelect: @escaping (String?, String?) -> Void) {
        self.currentBundleId = currentBundleId
        self.onSelect = onSelect
    }
    
    private var filteredApps: [RunningAppInfo] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return appWatcher.runningApps
        }
        return appWatcher.runningApps.filter {
            $0.localizedName.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Link Note to Application")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text("Note will automatically appear when the linked app is active.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding([.horizontal, .top], 16)
            .padding(.bottom, 12)
            
            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search running apps...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            
            Divider()
            
            // App List
            List {
                // Unlink Option
                Button {
                    onSelect(nil, nil)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "link.badge.plus")
                            .foregroundColor(.secondary)
                            .frame(width: 28, height: 28)
                        VStack(alignment: .leading) {
                            Text("No App Link (Always Available)")
                                .font(.body)
                            Text("Keep note visible across all apps")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if currentBundleId == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                                .font(.subheadline.bold())
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
                
                // Browse /Applications Option
                Button {
                    chooseOtherApp()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "folder.badge.gearshape")
                            .foregroundColor(.secondary)
                            .frame(width: 28, height: 28)
                        VStack(alignment: .leading) {
                            Text("Choose Other Application...")
                                .font(.body)
                            Text("Select any app from /Applications")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
                
                Section("Running Applications") {
                    ForEach(filteredApps) { app in
                        Button {
                            onSelect(app.bundleIdentifier, app.localizedName)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                if let icon = app.icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 28, height: 28)
                                        .cornerRadius(6)
                                } else {
                                    Image(systemName: "app.dashed")
                                        .frame(width: 28, height: 28)
                                }
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(app.localizedName)
                                        .font(.body)
                                        .fontWeight(.medium)
                                    Text(app.bundleIdentifier)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if currentBundleId == app.bundleIdentifier {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                        .font(.subheadline.bold())
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.inset)
        }
        .frame(width: 360, height: 420)
        .onAppear {
            appWatcher.refreshRunningApps()
        }
    }
    
    private func chooseOtherApp() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = [.application]
        openPanel.directoryURL = URL(fileURLWithPath: "/Applications")
        openPanel.prompt = "Select Application"
        openPanel.message = "Choose an application to link with this note"
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            if let bundle = Bundle(url: url), let bundleId = bundle.bundleIdentifier {
                let name = (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
                    ?? (bundle.infoDictionary?["CFBundleName"] as? String)
                    ?? url.deletingPathExtension().lastPathComponent
                onSelect(bundleId, name)
                dismiss()
            }
        }
    }
}
