import Foundation
import CoreGraphics

public enum DockEdge: String, Codable, CaseIterable, Sendable {
    case left
    case right
}

public struct NoteModel: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var content: String
    public var color: NoteColor
    public var isPrivate: Bool
    public var isLocked: Bool
    public var isPinned: Bool
    public var linkedAppBundleId: String?
    public var linkedAppName: String?
    public var isDocked: Bool
    public var dockEdge: DockEdge
    public var isCollapsed: Bool
    public var opacity: Double
    public var frameX: Double
    public var frameY: Double
    public var frameWidth: Double
    public var frameHeight: Double
    public var fontSize: Double
    public var createdAt: Date
    public var updatedAt: Date
    public var isArchived: Bool
    public var deletedAt: Date?
    public var imageAttachments: [String]
    
    public init(
        id: UUID = UUID(),
        title: String = "",
        content: String = "",
        color: NoteColor = .yellow,
        isPrivate: Bool = false,
        isLocked: Bool = false,
        isPinned: Bool = false,
        linkedAppBundleId: String? = nil,
        linkedAppName: String? = nil,
        isDocked: Bool = false,
        dockEdge: DockEdge = .right,
        isCollapsed: Bool = false,
        opacity: Double = 1.0,
        frameX: Double = 200,
        frameY: Double = 400,
        frameWidth: Double = 280,
        frameHeight: Double = 280,
        fontSize: Double = 13.0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isArchived: Bool = false,
        deletedAt: Date? = nil,
        imageAttachments: [String] = []
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.color = color
        self.isPrivate = isPrivate
        self.isLocked = isLocked
        self.isPinned = isPinned
        self.linkedAppBundleId = linkedAppBundleId
        self.linkedAppName = linkedAppName
        self.isDocked = isDocked
        self.dockEdge = dockEdge
        self.isCollapsed = isCollapsed
        self.opacity = opacity
        self.frameX = frameX
        self.frameY = frameY
        self.frameWidth = max(frameWidth, 220)
        self.frameHeight = max(frameHeight, 180)
        self.fontSize = max(9.0, min(42.0, fontSize))
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
        self.deletedAt = deletedAt
        self.imageAttachments = imageAttachments
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, content, color, isPrivate, isLocked, isPinned
        case linkedAppBundleId, linkedAppName, isDocked, dockEdge
        case isCollapsed, opacity
        case frameX, frameY, frameWidth, frameHeight
        case fontSize
        case createdAt, updatedAt, isArchived, deletedAt
        case imageAttachments
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        self.color = try container.decodeIfPresent(NoteColor.self, forKey: .color) ?? .yellow
        self.isPrivate = try container.decodeIfPresent(Bool.self, forKey: .isPrivate) ?? false
        self.isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        self.isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        self.linkedAppBundleId = try container.decodeIfPresent(String.self, forKey: .linkedAppBundleId)
        self.linkedAppName = try container.decodeIfPresent(String.self, forKey: .linkedAppName)
        self.isDocked = try container.decodeIfPresent(Bool.self, forKey: .isDocked) ?? false
        self.dockEdge = try container.decodeIfPresent(DockEdge.self, forKey: .dockEdge) ?? .right
        self.isCollapsed = try container.decodeIfPresent(Bool.self, forKey: .isCollapsed) ?? false
        self.opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 1.0
        self.frameX = try container.decodeIfPresent(Double.self, forKey: .frameX) ?? 200
        self.frameY = try container.decodeIfPresent(Double.self, forKey: .frameY) ?? 400
        self.frameWidth = try container.decodeIfPresent(Double.self, forKey: .frameWidth) ?? 280
        self.frameHeight = try container.decodeIfPresent(Double.self, forKey: .frameHeight) ?? 280
        self.fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? 13.0
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        self.isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        self.deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        self.imageAttachments = try container.decodeIfPresent([String].self, forKey: .imageAttachments) ?? []
    }
    
    public var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let clean = line.cleanMarkdownStripped
            if !clean.isEmpty {
                return String(clean.prefix(32))
            }
        }
        return "Untitled Note"
    }
    
    public var checklistProgress: (completed: Int, total: Int)? {
        let lines = content.components(separatedBy: .newlines)
        var total = 0
        var completed = 0
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- [ ]") || trimmed.hasPrefix("* [ ]") {
                total += 1
            } else if trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("- [X]") || trimmed.hasPrefix("* [x]") || trimmed.hasPrefix("* [X]") {
                total += 1
                completed += 1
            }
        }
        return total > 0 ? (completed, total) : nil
    }
}
