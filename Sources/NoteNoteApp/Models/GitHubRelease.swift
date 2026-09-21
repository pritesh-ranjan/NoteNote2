import Foundation

public struct GitHubReleaseAsset: Codable, Identifiable {
    public var id: Int?
    public let name: String
    public let browser_download_url: String
    public let size: Int?
    public let content_type: String?
    
    public init(id: Int? = nil, name: String, browser_download_url: String, size: Int? = nil, content_type: String? = nil) {
        self.id = id
        self.name = name
        self.browser_download_url = browser_download_url
        self.size = size
        self.content_type = content_type
    }
}

public struct GitHubRelease: Codable, Identifiable {
    public var id: Int?
    public let tag_name: String
    public let name: String?
    public let body: String?
    public let html_url: String
    public let published_at: String?
    public let assets: [GitHubReleaseAsset]
    
    public init(
        id: Int? = nil,
        tag_name: String,
        name: String? = nil,
        body: String? = nil,
        html_url: String,
        published_at: String? = nil,
        assets: [GitHubReleaseAsset] = []
    ) {
        self.id = id
        self.tag_name = tag_name
        self.name = name
        self.body = body
        self.html_url = html_url
        self.published_at = published_at
        self.assets = assets
    }
    
    /// Clean version string without leading 'v' or 'V'
    public var cleanVersion: String {
        var version = tag_name.trimmingCharacters(in: .whitespacesAndNewlines)
        if version.hasPrefix("v") || version.hasPrefix("V") {
            version.removeFirst()
        }
        return version
    }
    
    /// Display name or tag if name is empty
    public var displayTitle: String {
        if let name = name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }
        return tag_name
    }
    
    /// Find the direct zip asset (NoteNote.app.zip) or DMG asset as fallback
    public var zipAsset: GitHubReleaseAsset? {
        assets.first { $0.name.lowercased().hasSuffix(".zip") }
    }
    
    public var dmgAsset: GitHubReleaseAsset? {
        assets.first { $0.name.lowercased().hasSuffix(".dmg") }
    }
}
