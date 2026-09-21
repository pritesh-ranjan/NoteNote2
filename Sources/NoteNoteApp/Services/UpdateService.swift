import AppKit
import Foundation
import Combine

@MainActor
public final class UpdateService: ObservableObject {
    public static let shared = UpdateService()
    
    // MARK: - Published States
    @Published public private(set) var isChecking: Bool = false
    @Published public private(set) var isDownloading: Bool = false
    @Published public private(set) var downloadProgress: Double = 0.0
    @Published public private(set) var latestRelease: GitHubRelease? = nil
    @Published public private(set) var hasNewUpdate: Bool = false
    @Published public private(set) var statusMessage: String = ""
    @Published public private(set) var lastCheckDate: Date? = nil
    
    // GitHub Repository Configuration
    public let repoOwner = "pritesh-ranjan"
    public let repoName = "NoteNote2"
    
    private var periodicTimer: Timer?
    
    public var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.2.0"
    }
    
    public var currentBuildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "6"
    }
    
    private init() {
        self.lastCheckDate = NotesStore.shared.settings.lastUpdateCheckDate
    }
    
    // MARK: - Periodic & Daily Cadence
    
    public func startPeriodicTimer() {
        periodicTimer?.invalidate()
        // Check every 2 hours to see if 24 hours have elapsed since the last check
        periodicTimer = Timer.scheduledTimer(withTimeInterval: 7200, repeats: true) { _ in
            Task { @MainActor in
                UpdateService.shared.checkDailyUpdateIfNeeded()
            }
        }
    }
    
    public func checkDailyUpdateIfNeeded() {
        guard NotesStore.shared.settings.autoCheckForUpdates else {
            return
        }
        
        let lastCheck = NotesStore.shared.settings.lastUpdateCheckDate
        let oneDayInSeconds: TimeInterval = 86400
        
        if let lastCheck = lastCheck, Date().timeIntervalSince(lastCheck) < oneDayInSeconds {
            // Already checked within the last 24 hours
            return
        }
        
        // Run silent background check
        checkForUpdates(interactive: false)
    }
    
    // MARK: - Version Comparison
    
    /// Compares two version strings (e.g. "2.1.0" and "v2.2.0").
    /// Returns:
    /// - `.orderedAscending` if `current` is older than `remote` (i.e. update available)
    /// - `.orderedSame` if versions are identical
    /// - `.orderedDescending` if `current` is newer than `remote`
    public static func compareVersions(current: String, remote: String) -> ComparisonResult {
        func parseComponents(_ version: String) -> [Int] {
            var v = version.trimmingCharacters(in: .whitespacesAndNewlines)
            if v.hasPrefix("v") || v.hasPrefix("V") {
                v.removeFirst()
            }
            // Strip any trailing prerelease tags (e.g. "-beta", "-rc") for numeric comparison
            let base = v.components(separatedBy: "-").first ?? v
            return base.components(separatedBy: ".").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        }
        
        let currentParts = parseComponents(current)
        let remoteParts = parseComponents(remote)
        
        let maxCount = max(currentParts.count, remoteParts.count)
        for i in 0..<maxCount {
            let curr = i < currentParts.count ? currentParts[i] : 0
            let rem = i < remoteParts.count ? remoteParts[i] : 0
            
            if curr < rem {
                return .orderedAscending
            } else if curr > rem {
                return .orderedDescending
            }
        }
        
        return .orderedSame
    }
    
    // MARK: - Validation & Security
    
    /// Verifies that the release and asset URLs originate strictly from the official repository.
    public static func isRepoURLValid(release: GitHubRelease) -> Bool {
        // Release page URL must belong to the official repository
        let expectedReleasePrefix = "https://github.com/pritesh-ranjan/NoteNote2/releases"
        guard release.html_url.hasPrefix(expectedReleasePrefix) else {
            AppLogger.error("Update rejected: invalid release html_url '\(release.html_url)'")
            return false
        }
        
        // Asset download URLs must originate from the official repository release downloads
        if let zipAsset = release.zipAsset {
            let expectedDownloadPrefix = "https://github.com/pritesh-ranjan/NoteNote2/releases/download/"
            guard zipAsset.browser_download_url.hasPrefix(expectedDownloadPrefix) else {
                AppLogger.error("Update rejected: invalid zip asset download URL '\(zipAsset.browser_download_url)'")
                return false
            }
        }
        if let dmgAsset = release.dmgAsset {
            let expectedDownloadPrefix = "https://github.com/pritesh-ranjan/NoteNote2/releases/download/"
            guard dmgAsset.browser_download_url.hasPrefix(expectedDownloadPrefix) else {
                AppLogger.error("Update rejected: invalid dmg asset download URL '\(dmgAsset.browser_download_url)'")
                return false
            }
        }
        return true
    }
    
    /// Verifies code signature of the downloaded app bundle against NoteNote requirements.
    public static func verifyCodeSignature(newAppURL: URL, currentAppURL: URL) -> Bool {
        // 1. Strict signature validity check
        let strictProcess = Process()
        strictProcess.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        strictProcess.arguments = ["-v", "--strict", newAppURL.path]
        do {
            try strictProcess.run()
            strictProcess.waitUntilExit()
            guard strictProcess.terminationStatus == 0 else {
                AppLogger.error("Codesign verification failed: strict check returned exit \(strictProcess.terminationStatus)")
                return false
            }
        } catch {
            AppLogger.error("Codesign verification failed to execute strict check", error: error)
            return false
        }
        
        // 2. Explicit designated requirement check for NoteNote bundle identifier
        let idProcess = Process()
        idProcess.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        idProcess.arguments = ["-v", "-R=identifier \"com.priteshranjan.NoteNote\"", newAppURL.path]
        do {
            try idProcess.run()
            idProcess.waitUntilExit()
            guard idProcess.terminationStatus == 0 else {
                AppLogger.error("Codesign verification failed: requirement identifier mismatch (exit \(idProcess.terminationStatus))")
                return false
            }
        } catch {
            AppLogger.error("Codesign verification failed to execute requirement check", error: error)
            return false
        }
        
        // 3. Match against current running app's designated requirement if present
        let reqProcess = Process()
        reqProcess.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        reqProcess.arguments = ["-d", "-r-", currentAppURL.path]
        let pipe = Pipe()
        reqProcess.standardOutput = pipe
        reqProcess.standardError = pipe
        do {
            try reqProcess.run()
            reqProcess.waitUntilExit()
            if reqProcess.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    for line in output.components(separatedBy: .newlines) {
                        if let range = line.range(of: "designated => ") {
                            let requirement = String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                            if !requirement.isEmpty {
                                let matchProcess = Process()
                                matchProcess.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
                                matchProcess.arguments = ["-v", "-R=\(requirement)", newAppURL.path]
                                try matchProcess.run()
                                matchProcess.waitUntilExit()
                                guard matchProcess.terminationStatus == 0 else {
                                    AppLogger.error("Codesign verification failed: does not match current designated requirement '\(requirement)'")
                                    return false
                                }
                            }
                        }
                    }
                }
            }
        } catch {
            AppLogger.error("Failed to read current app designated requirement", error: error)
            return false
        }
        
        return true
    }
    
    // MARK: - Check For Updates
    
    public func checkForUpdates(interactive: Bool = false) {
        guard !isChecking else { return }
        
        isChecking = true
        statusMessage = "Checking for updates..."
        
        Task {
            defer {
                self.isChecking = false
            }
            
            let endpoint = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
            guard let url = URL(string: endpoint) else {
                self.statusMessage = "Invalid update URL"
                return
            }
            
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
            request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            request.setValue("NoteNote/\(currentVersion)", forHTTPHeaderField: "User-Agent")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NSError(domain: "UpdateService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
                }
                
                guard httpResponse.statusCode == 200 else {
                    if httpResponse.statusCode == 404 {
                        self.statusMessage = "No published releases found."
                        // Silent: no popup
                        return
                    }
                    throw NSError(domain: "UpdateService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "GitHub API responded with status \(httpResponse.statusCode)"])
                }
                
                let decoder = JSONDecoder()
                let release = try decoder.decode(GitHubRelease.self, from: data)
                
                // Record timestamp
                let now = Date()
                self.lastCheckDate = now
                NotesStore.shared.settings.lastUpdateCheckDate = now
                NotesStore.shared.requestSave()
                
                let comparison = Self.compareVersions(current: self.currentVersion, remote: release.tag_name)
                let isRepoValid = Self.isRepoURLValid(release: release)
                
                if comparison == .orderedAscending && isRepoValid {
                    // Actual higher release verified from official repository!
                    self.latestRelease = release
                    self.hasNewUpdate = true
                    self.statusMessage = "Update available: \(release.tag_name)"
                    
                    // Show popup ONLY when we have an actual update!
                    UpdateWindowController.shared.show(release: release)
                } else {
                    self.latestRelease = release
                    self.hasNewUpdate = false
                    self.statusMessage = "NoteNote is up to date (\(self.currentVersion))"
                    // Silent: No popup when up to date
                }
            } catch {
                AppLogger.error("Failed to check for updates", error: error)
                self.statusMessage = "Could not check for updates"
                // Silent: No popup on network or check failure
            }
        }
    }
    
    // MARK: - Download & Install
    
    public func downloadAndInstall(release: GitHubRelease) {
        guard !isDownloading else { return }
        
        // Ensure repo URL is verified
        guard Self.isRepoURLValid(release: release) else {
            self.statusMessage = "Security error: untrusted release repository."
            AppLogger.error("Rejected installation: repository URL validation failed.")
            return
        }
        
        // Find zip asset first, then DMG fallback
        guard let downloadAsset = release.zipAsset ?? release.dmgAsset,
              let downloadURL = URL(string: downloadAsset.browser_download_url) else {
            // Fallback: Open GitHub release page in browser
            if let releaseURL = URL(string: release.html_url) {
                NSWorkspace.shared.open(releaseURL)
            }
            return
        }
        
        isDownloading = true
        downloadProgress = 0.0
        statusMessage = "Downloading \(release.displayTitle)..."
        
        Task {
            do {
                let tempLocalFile = try await downloadFileWithProgress(from: downloadURL)
                
                if downloadAsset.name.lowercased().hasSuffix(".zip") {
                    try await extractAndRelaunch(zipFileURL: tempLocalFile)
                } else {
                    // It's a DMG installer
                    self.isDownloading = false
                    self.statusMessage = "Downloaded installer. Opening..."
                    NSWorkspace.shared.open(tempLocalFile)
                }
            } catch {
                self.isDownloading = false
                self.statusMessage = "Update failed: \(error.localizedDescription)"
                AppLogger.error("Update download/install failed", error: error)
            }
        }
    }
    
    private func downloadFileWithProgress(from url: URL) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            let delegate = DownloadDelegate(
                onProgress: { progress in
                    Task { @MainActor in
                        UpdateService.shared.downloadProgress = progress
                    }
                },
                onFinish: { result in
                    continuation.resume(with: result)
                }
            )
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            let task = session.downloadTask(with: url)
            task.resume()
        }
    }
    
    // MARK: - Extraction, Codesign Verification & Atomic Replacement
    
    private func extractAndRelaunch(zipFileURL: URL) async throws {
        let fileManager = FileManager.default
        let extractDir = zipFileURL.deletingLastPathComponent().appendingPathComponent("extracted")
        try fileManager.createDirectory(at: extractDir, withIntermediateDirectories: true)
        
        // Extract zip preserving macOS symlinks and metadata using /usr/bin/ditto
        let dittoProcess = Process()
        dittoProcess.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        dittoProcess.arguments = ["-xk", zipFileURL.path, extractDir.path]
        try dittoProcess.run()
        dittoProcess.waitUntilExit()
        
        guard dittoProcess.terminationStatus == 0 else {
            throw NSError(domain: "UpdateService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to decompress update package."])
        }
        
        // Locate NoteNote.app inside extracted folder
        let enumerator = fileManager.enumerator(at: extractDir, includingPropertiesForKeys: nil)
        var newAppBundleURL: URL?
        while let file = enumerator?.nextObject() as? URL {
            if file.lastPathComponent == "NoteNote.app" && file.hasDirectoryPath {
                newAppBundleURL = file
                break
            }
        }
        
        guard let validNewAppURL = newAppBundleURL else {
            throw NSError(domain: "UpdateService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Update archive did not contain NoteNote.app."])
        }
        
        // 1. Verify bundle identifier
        let infoPlistURL = validNewAppURL.appendingPathComponent("Contents/Info.plist")
        if let plistData = try? Data(contentsOf: infoPlistURL),
           let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
           let bundleId = plist["CFBundleIdentifier"] as? String {
            guard bundleId == "com.priteshranjan.NoteNote" else {
                throw NSError(domain: "UpdateService", code: -4, userInfo: [NSLocalizedDescriptionKey: "Invalid bundle identifier in update archive: \(bundleId)"])
            }
        }
        
        // 2. Strict Codesign Verification: Must match designated code requirement
        let codesignMatches = Self.verifyCodeSignature(newAppURL: validNewAppURL, currentAppURL: Bundle.main.bundleURL)
        guard codesignMatches else {
            AppLogger.error("Update rejected: Code signature verification failed on extracted app bundle.")
            throw NSError(domain: "UpdateService", code: -5, userInfo: [NSLocalizedDescriptionKey: "Security verification failed: code signature does not match NoteNote requirements."])
        }
        
        // 3. Determine target app path to replace
        var targetAppURL = Bundle.main.bundleURL
        if targetAppURL.path.contains("/.build/") || targetAppURL.path.contains("/DerivedData/") {
            // If running inside dev build folder, target /Applications/NoteNote.app if installed, or local NoteNote.app
            let appInApplications = URL(fileURLWithPath: "/Applications/NoteNote.app")
            let localApp = URL(fileURLWithPath: "NoteNote.app")
            if fileManager.fileExists(atPath: appInApplications.path) {
                targetAppURL = appInApplications
            } else if fileManager.fileExists(atPath: localApp.path) {
                targetAppURL = localApp
            }
        }
        
        let targetAppPath = targetAppURL.path
        let tempParentDir = zipFileURL.deletingLastPathComponent().path
        let newAppPath = validNewAppURL.path
        
        // Execute detached atomic swap script and terminate current app
        let script = """
        (
            sleep 0.8
            rm -rf "\(targetAppPath)"
            cp -R "\(newAppPath)" "\(targetAppPath)"
            xattr -dr com.apple.quarantine "\(targetAppPath)" 2>/dev/null || true
            rm -rf "\(tempParentDir)"
            open "\(targetAppPath)"
        ) >/dev/null 2>&1 &
        """
        
        let swapProcess = Process()
        swapProcess.executableURL = URL(fileURLWithPath: "/bin/sh")
        swapProcess.arguments = ["-c", script]
        try swapProcess.run()
        
        // Gracefully terminate this instance
        NSApp.terminate(nil)
    }
}

// MARK: - DownloadDelegate

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let onProgress: (Double) -> Void
    private let onFinish: (Result<URL, Error>) -> Void
    
    init(onProgress: @escaping (Double) -> Void, onFinish: @escaping (Result<URL, Error>) -> Void) {
        self.onProgress = onProgress
        self.onFinish = onFinish
        super.init()
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            onProgress(progress)
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("NoteNoteUpdate_\(UUID().uuidString)")
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let destURL = tempDir.appendingPathComponent(downloadTask.response?.suggestedFilename ?? "NoteNote_update.zip")
            try FileManager.default.moveItem(at: location, to: destURL)
            onFinish(.success(destURL))
        } catch {
            onFinish(.failure(error))
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            onFinish(.failure(error))
        }
    }
}

