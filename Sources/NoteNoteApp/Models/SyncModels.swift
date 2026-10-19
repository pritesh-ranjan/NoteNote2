import Foundation
import CryptoKit

// MARK: - Paired Device Model
public struct PairedDevice: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var linkKeyBase64: String
    public var pairedAt: Date
    public var lastSeenAt: Date
    
    public init(
        id: String,
        name: String,
        linkKeyBase64: String,
        pairedAt: Date = Date(),
        lastSeenAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.linkKeyBase64 = linkKeyBase64
        self.pairedAt = pairedAt
        self.lastSeenAt = lastSeenAt
    }
}

// MARK: - Sync Note DTO (Wire Transfer)
public struct SyncNoteDTO: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var content: String
    public var color: String
    public var isPinned: Bool
    public var isLocked: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?
    
    public init(
        id: UUID = UUID(),
        title: String = "",
        content: String = "",
        color: String = "yellow",
        isPinned: Bool = false,
        isLocked: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.color = color
        self.isPinned = isPinned
        self.isLocked = isLocked
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
    
    public init(from note: NoteModel) {
        self.id = note.id
        self.title = note.title
        self.content = note.content
        self.color = note.color.rawValue
        self.isPinned = note.isPinned
        self.isLocked = note.isLocked
        self.createdAt = note.createdAt
        self.updatedAt = note.updatedAt
        self.deletedAt = note.deletedAt
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case title, name, heading, header
        case content, body, text, description, note
        case color
        case isPinned, pinned
        case isLocked, locked
        case createdAt, created_at
        case updatedAt, updated_at
        case deletedAt, deleted_at
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 1. ID decoding (support UUID string, integer, or arbitrary string)
        if let uuid = try? container.decode(UUID.self, forKey: .id) {
            self.id = uuid
        } else if let idStr = try? container.decode(String.self, forKey: .id) {
            if let uuid = UUID(uuidString: idStr) {
                self.id = uuid
            } else {
                self.id = SyncNoteDTO.deterministicUUID(from: idStr)
            }
        } else if let idInt = try? container.decode(Int.self, forKey: .id) {
            self.id = SyncNoteDTO.deterministicUUID(from: "note-\(idInt)")
        } else {
            self.id = UUID()
        }
        
        // 2. Title decoding (tolerant to alternative field names and nulls)
        self.title = (try? container.decodeIfPresent(String.self, forKey: .title))
            ?? (try? container.decodeIfPresent(String.self, forKey: .name))
            ?? (try? container.decodeIfPresent(String.self, forKey: .heading))
            ?? (try? container.decodeIfPresent(String.self, forKey: .header))
            ?? ""
            
        // 3. Content decoding
        self.content = (try? container.decodeIfPresent(String.self, forKey: .content))
            ?? (try? container.decodeIfPresent(String.self, forKey: .body))
            ?? (try? container.decodeIfPresent(String.self, forKey: .text))
            ?? (try? container.decodeIfPresent(String.self, forKey: .note))
            ?? ""
            
        // 4. Color decoding
        self.color = (try? container.decodeIfPresent(String.self, forKey: .color)) ?? "yellow"
        
        // 5. isPinned decoding (bool, int, or missing)
        if let pinBool = try? container.decodeIfPresent(Bool.self, forKey: .isPinned) {
            self.isPinned = pinBool
        } else if let pinBool = try? container.decodeIfPresent(Bool.self, forKey: .pinned) {
            self.isPinned = pinBool
        } else if let pinInt = try? container.decodeIfPresent(Int.self, forKey: .isPinned) {
            self.isPinned = (pinInt != 0)
        } else {
            self.isPinned = false
        }
        
        // 6. isLocked decoding (bool, int, or missing)
        if let lockBool = try? container.decodeIfPresent(Bool.self, forKey: .isLocked) {
            self.isLocked = lockBool
        } else if let lockBool = try? container.decodeIfPresent(Bool.self, forKey: .locked) {
            self.isLocked = lockBool
        } else if let lockInt = try? container.decodeIfPresent(Int.self, forKey: .isLocked) {
            self.isLocked = (lockInt != 0)
        } else {
            self.isLocked = false
        }
        
        // 7. createdAt decoding (flexible date)
        self.createdAt = SyncNoteDTO.decodeFlexibleDate(from: container, keys: [.createdAt, .created_at]) ?? Date()
        
        // 8. updatedAt decoding (flexible date)
        self.updatedAt = SyncNoteDTO.decodeFlexibleDate(from: container, keys: [.updatedAt, .updated_at]) ?? Date()
        
        // 9. deletedAt decoding (flexible date)
        self.deletedAt = SyncNoteDTO.decodeFlexibleDate(from: container, keys: [.deletedAt, .deleted_at])
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(color, forKey: .color)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encode(isLocked, forKey: .isLocked)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(deletedAt, forKey: .deletedAt)
    }
    
    private static func decodeFlexibleDate(from container: KeyedDecodingContainer<CodingKeys>, keys: [CodingKeys]) -> Date? {
        for key in keys {
            if let dateStr = try? container.decodeIfPresent(String.self, forKey: key) {
                if let d = parseDateString(dateStr) { return d }
            }
            if let num = try? container.decodeIfPresent(Double.self, forKey: key) {
                if num > 100_000_000_000 { return Date(timeIntervalSince1970: num / 1000.0) } // ms
                if num > 100_000_000 { return Date(timeIntervalSince1970: num) } // sec
                return Date(timeIntervalSinceReferenceDate: num)
            }
        }
        return nil
    }
    
    public static func parseDateString(_ str: String) -> Date? {
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: str) { return d }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: str) { return d }
        
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        for fmt in ["yyyy-MM-dd'T'HH:mm:ss.SSSZ", "yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"] {
            df.dateFormat = fmt
            if let d = df.date(from: str) { return d }
        }
        return nil
    }
    
    public static func deterministicUUID(from string: String) -> UUID {
        let digest = Insecure.MD5.hash(data: Data(string.utf8))
        var bytes = Array(digest)
        bytes[6] = (bytes[6] & 0x0F) | 0x40 // Version 4
        bytes[8] = (bytes[8] & 0x3F) | 0x80 // Variant 1
        let uuidTuple: uuid_t = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: uuidTuple)
    }
    
    public func toNoteModel(sourceDeviceId: String?, sourceDeviceName: String?) -> NoteModel {
        let noteColor = NoteColor(rawValue: color) ?? .yellow
        return NoteModel(
            id: id,
            title: title,
            content: content,
            color: noteColor,
            isPrivate: false,
            isLocked: isLocked,
            isPinned: isPinned,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isArchived: false,
            deletedAt: deletedAt,
            sourceDeviceId: sourceDeviceId,
            sourceDeviceName: sourceDeviceName,
            lastSyncedAt: Date()
        )
    }
}

// MARK: - Wire Frame Payloads
public enum SyncMessageType: String, Codable, Sendable {
    // Pairing Handshake
    case pairInit = "PAIR_INIT"
    case pairChallenge = "PAIR_CHALLENGE"
    case pairReveal = "PAIR_REVEAL"
    case pairConfirm = "PAIR_CONFIRM"
    case pairComplete = "PAIR_COMPLETE"
    case pairReject = "PAIR_REJECT"
    
    // Trusted Session Handshake
    case sessionInit = "SESSION_INIT"
    case sessionChallenge = "SESSION_CHALLENGE"
    case sessionAuth = "SESSION_AUTH"
    case sessionOk = "SESSION_OK"
    
    // Encrypted Application Frame
    case encrypted = "ENCRYPTED"
    
    // Error
    case error = "ERROR"
}

public struct SyncWireMessage: Codable, Sendable {
    public let type: SyncMessageType
    public var payload: String
    
    public init(type: SyncMessageType, payload: String = "") {
        self.type = type
        self.payload = payload
    }
}

public struct PairInitPayload: Codable, Sendable {
    public let deviceId: String
    public let deviceName: String
    public let clientPubKeyDER: String
    public let clientNonceCommit: String
    
    public init(deviceId: String, deviceName: String, clientPubKeyDER: String, clientNonceCommit: String) {
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.clientPubKeyDER = clientPubKeyDER
        self.clientNonceCommit = clientNonceCommit
    }
}

public struct PairChallengePayload: Codable, Sendable {
    public let serverId: String
    public let serverName: String
    public let serverPubKeyDER: String
    public let serverNonce: String
    
    public init(serverId: String, serverName: String, serverPubKeyDER: String, serverNonce: String) {
        self.serverId = serverId
        self.serverName = serverName
        self.serverPubKeyDER = serverPubKeyDER
        self.serverNonce = serverNonce
    }
}

public struct PairRevealPayload: Codable, Sendable {
    public let clientNonce: String
    
    public init(clientNonce: String) {
        self.clientNonce = clientNonce
    }
}

public struct PairConfirmPayload: Codable, Sendable {
    public let clientHmac: String
    
    public init(clientHmac: String) {
        self.clientHmac = clientHmac
    }
}

public struct PairCompletePayload: Codable, Sendable {
    public let serverHmac: String
    public let status: String
    
    public init(serverHmac: String, status: String = "OK") {
        self.serverHmac = serverHmac
        self.status = status
    }
}

public struct SessionInitPayload: Codable, Sendable {
    public let deviceId: String
    public let clientPubKeyDER: String
    public let clientNonce: String
    
    public init(deviceId: String, clientPubKeyDER: String, clientNonce: String) {
        self.deviceId = deviceId
        self.clientPubKeyDER = clientPubKeyDER
        self.clientNonce = clientNonce
    }
}

public struct SessionChallengePayload: Codable, Sendable {
    public let serverId: String
    public let serverPubKeyDER: String
    public let serverNonce: String
    
    public init(serverId: String, serverPubKeyDER: String, serverNonce: String) {
        self.serverId = serverId
        self.serverPubKeyDER = serverPubKeyDER
        self.serverNonce = serverNonce
    }
}

public struct SessionAuthPayload: Codable, Sendable {
    public let clientHmac: String
    
    public init(clientHmac: String) {
        self.clientHmac = clientHmac
    }
}

public struct SessionOkPayload: Codable, Sendable {
    public let serverHmac: String
    public let status: String
    
    public init(serverHmac: String, status: String = "OK") {
        self.serverHmac = serverHmac
        self.status = status
    }
}

public struct EncryptedPayload: Codable, Sendable {
    public let seq: UInt64
    public let iv: String
    public let ciphertext: String
    
    public init(seq: UInt64, iv: String, ciphertext: String) {
        self.seq = seq
        self.iv = iv
        self.ciphertext = ciphertext
    }
}

// MARK: - Encrypted Application Actions
public enum EncryptedAction: String, Codable, Sendable {
    case ping = "PING"
    case pong = "PONG"
    case pushNotes = "PUSH_NOTES"
    case pullNotes = "PULL_NOTES"
    case syncAll = "SYNC_ALL"
    case unpair = "UNPAIR"
    case ack = "ACK"
}

public struct SyncAppRequest: Codable, Sendable {
    public let action: EncryptedAction
    public var notes: [SyncNoteDTO]?
    public var since: Date?
    
    public init(action: EncryptedAction, notes: [SyncNoteDTO]? = nil, since: Date? = nil) {
        self.action = action
        self.notes = notes
        self.since = since
    }
    
    private enum CodingKeys: String, CodingKey {
        case action, notes, since
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 1. Action decoding (case-insensitive & synonym mapping)
        if let actionStr = try? container.decode(String.self, forKey: .action) {
            let normalized = actionStr.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
            switch normalized {
            case "PUSH_NOTES", "PUSH", "PUSHNOTES":
                self.action = .pushNotes
            case "PULL_NOTES", "PULL", "PULLNOTES":
                self.action = .pullNotes
            case "SYNC_ALL", "SYNC", "SYNCALL":
                self.action = .syncAll
            case "PING":
                self.action = .ping
            case "PONG":
                self.action = .pong
            case "UNPAIR":
                self.action = .unpair
            case "ACK":
                self.action = .ack
            default:
                self.action = .syncAll
            }
        } else {
            self.action = .syncAll
        }
        
        // 2. Notes decoding (tolerant of note-level errors)
        if var notesArray = try? container.nestedUnkeyedContainer(forKey: .notes) {
            var decodedNotes: [SyncNoteDTO] = []
            while !notesArray.isAtEnd {
                if let note = try? notesArray.decode(SyncNoteDTO.self) {
                    decodedNotes.append(note)
                } else {
                    // Skip corrupt note without failing entire array
                    _ = try? notesArray.decode(AnyDecodableIgnore.self)
                }
            }
            self.notes = decodedNotes.isEmpty ? nil : decodedNotes
        } else {
            self.notes = nil
        }
        
        // 3. Since date decoding
        if let sinceStr = try? container.decodeIfPresent(String.self, forKey: .since) {
            self.since = SyncNoteDTO.parseDateString(sinceStr)
        } else if let sinceNum = try? container.decodeIfPresent(Double.self, forKey: .since) {
            if sinceNum > 100_000_000_000 { self.since = Date(timeIntervalSince1970: sinceNum / 1000.0) }
            else if sinceNum > 100_000_000 { self.since = Date(timeIntervalSince1970: sinceNum) }
            else { self.since = Date(timeIntervalSinceReferenceDate: sinceNum) }
        } else {
            self.since = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(action.rawValue, forKey: .action)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(since, forKey: .since)
    }
}

fileprivate struct AnyDecodableIgnore: Decodable {
    init(from decoder: Decoder) throws {}
}

public struct SyncAppResponse: Codable, Sendable {
    public var status: String
    public var action: EncryptedAction
    public var notes: [SyncNoteDTO]?
    public var upsertedCount: Int?
    public var serverTime: Date
    public var errorMessage: String?
    
    public init(
        status: String = "OK",
        action: EncryptedAction = .ack,
        notes: [SyncNoteDTO]? = nil,
        upsertedCount: Int? = nil,
        serverTime: Date = Date(),
        errorMessage: String? = nil
    ) {
        self.status = status
        self.action = action
        self.notes = notes
        self.upsertedCount = upsertedCount
        self.serverTime = serverTime
        self.errorMessage = errorMessage
    }
}

// MARK: - Active Pairing Session (In-Memory State for Confirmation Window)
public struct ActivePairingSession: Identifiable, Sendable {
    public let id: UUID = UUID()
    public let deviceId: String
    public let deviceName: String
    public let sixDigitCode: String
    public let createdAt: Date = Date()
    public let expiresAt: Date
    
    public init(deviceId: String, deviceName: String, sixDigitCode: String, timeoutSeconds: TimeInterval = 60) {
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.sixDigitCode = sixDigitCode
        self.expiresAt = Date().addingTimeInterval(timeoutSeconds)
    }
}
