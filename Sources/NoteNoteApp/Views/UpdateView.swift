import SwiftUI
import AppKit

public struct UpdateView: View {
    public let release: GitHubRelease
    @ObservedObject private var updateService = UpdateService.shared
    public var onClose: (() -> Void)?
    
    public init(release: GitHubRelease, onClose: (() -> Void)? = nil) {
        self.release = release
        self.onClose = onClose
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack(alignment: .top, spacing: 16) {
                if let appIcon = NSImage(named: "AppIcon") {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(LinearGradient(colors: [Color.blue, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 60, height: 60)
                            .shadow(color: Color.blue.opacity(0.3), radius: 6, x: 0, y: 3)
                        
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("New Version Available")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("A new release of NoteNote is available to update.")
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.65))
                    
                    HStack(spacing: 8) {
                        Text("Current: v\(updateService.currentVersion)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(white: 0.5))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(white: 0.2))
                            .cornerRadius(4)
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(white: 0.4))
                        
                        Text("New: \(release.tag_name)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(4)
                    }
                    .padding(.top, 4)
                }
                
                Spacer()
            }
            .padding(.horizontal, 4)
            
            // Release Notes Card
            VStack(alignment: .leading, spacing: 6) {
                Text("Release Notes (\(release.displayTitle))")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(white: 0.6))
                    .textCase(.uppercase)
                    .padding(.leading, 2)
                
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 8) {
                        if let body = release.body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(body)
                                .font(.system(size: 12))
                                .foregroundColor(Color(white: 0.85))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text("No additional release notes provided.")
                                .font(.system(size: 12))
                                .foregroundColor(Color(white: 0.5))
                                .italic()
                        }
                    }
                    .padding(12)
                }
                .frame(maxHeight: 180)
                .background(Color(red: 0.14, green: 0.14, blue: 0.14))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
            }
            
            // Download Progress Bar if downloading
            if updateService.isDownloading {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Downloading update package...")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(white: 0.75))
                        Spacer()
                        Text("\(Int(updateService.downloadProgress * 100))%")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.blue)
                    }
                    
                    ProgressView(value: updateService.downloadProgress, total: 1.0)
                        .progressViewStyle(.linear)
                        .tint(.blue)
                }
                .padding(.horizontal, 4)
            }
            
            // Bottom Action Bar
            HStack(spacing: 12) {
                Button("View on GitHub") {
                    if let url = URL(string: release.html_url) {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(Color.blue)
                
                Spacer()
                
                Button("Remind Me Later") {
                    onClose?()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(Color(white: 0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(white: 0.22))
                .cornerRadius(6)
                .disabled(updateService.isDownloading)
                
                Button {
                    updateService.downloadAndInstall(release: release)
                } label: {
                    HStack(spacing: 6) {
                        if updateService.isDownloading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 13))
                        }
                        Text(updateService.isDownloading ? "Updating..." : "Update & Relaunch")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(6)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.plain)
                .disabled(updateService.isDownloading)
            }
            .padding(.top, 4)
        }
        .padding(24)
        .frame(width: 480)
        .background(Color(red: 0.12, green: 0.12, blue: 0.12))
        .preferredColorScheme(.dark)
    }
}
