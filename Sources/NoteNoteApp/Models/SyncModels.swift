import Foundation

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
