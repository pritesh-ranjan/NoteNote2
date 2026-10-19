import Foundation
import Network
import CryptoKit

@MainActor
public final class LocalSyncServer: ObservableObject {
    public static let shared = LocalSyncServer()
    
    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var localPort: UInt16 = 52849
    @Published public private(set) var localIPAddresses: [String] = []
    @Published public private(set) var activeConnectionCount: Int = 0
    @Published public private(set) var activePairingSession: ActivePairingSession? = nil
    @Published public fileprivate(set) var connectedDeviceNames: [String] = []
    @Published public fileprivate(set) var isSyncing: Bool = false
    @Published public fileprivate(set) var lastSyncDate: Date? = nil
    
    private var listener: NWListener?
    private let serverQueue = DispatchQueue(label: "com.priteshranjan.NoteNote.LocalSyncServer", qos: .utility)
    private var activeSessions: [ObjectIdentifier: SyncConnectionSession] = [:]
    
    private init() {
        refreshNetworkInfo()
    }
    
    public func refreshNetworkInfo() {
        self.localIPAddresses = getLocalIPv4Addresses()
    }
    
    public func updateConnectedDevices() {
        self.connectedDeviceNames = activeSessions.values.compactMap { $0.authenticatedDeviceName }
    }
    
    public func triggerSync() {
        guard isRunning else {
            start()
            return
        }
        
        refreshNetworkInfo()
        updateConnectedDevices()
        let authSessions = activeSessions.values.filter { $0.isAuthenticated }
        
        isSyncing = true
        if authSessions.isEmpty {
            AppLogger.info("Manual sync triggered on Mac: No phone currently connected. Listening on port \(localPort)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.isSyncing = false
            }
            return
        }
        
        for session in authSessions {
            session.pushMacNotesToClient()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.isSyncing = false
            self?.lastSyncDate = Date()
        }
    }
    
    public func start() {
        guard !isRunning else { return }
        refreshNetworkInfo()
        
        let desiredPort = NotesStore.shared.settings.wifiSyncPort
        self.localPort = desiredPort
        
        do {
            let parameters = NWParameters.tcp
            parameters.acceptLocalOnly = true
            
            let wsOptions = NWProtocolWebSocket.Options()
            wsOptions.autoReplyPing = true
            wsOptions.maximumMessageSize = 16 * 1024 * 1024 // 16MB guard
            parameters.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)
            
            let port = NWEndpoint.Port(rawValue: desiredPort) ?? 52849
            let newListener = try NWListener(using: parameters, on: port)
            
            let serverName = Host.current().localizedName ?? "NoteNote Mac"
            newListener.service = NWListener.Service(name: serverName, type: "_notenote-sync._tcp")
            
            newListener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    switch state {
                    case .ready:
                        if let actualPort = newListener.port?.rawValue {
                            self.localPort = actualPort
                        }
                        self.isRunning = true
                        AppLogger.info("LocalSyncServer listening on port \(self.localPort) (_notenote-sync._tcp)")
                    case .failed(let error):
                        AppLogger.error("LocalSyncServer failed", error: error)
                        self.stop()
                    case .cancelled:
                        self.isRunning = false
                        AppLogger.info("LocalSyncServer stopped")
                    default:
                        break
                    }
                }
            }
            
            newListener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor [weak self] in
                    self?.handleNewConnection(connection)
                }
            }
            
            newListener.start(queue: serverQueue)
            self.listener = newListener
            AppLogger.info("Starting LocalSyncServer on port \(desiredPort)...")
        } catch {
            AppLogger.error("Failed to start LocalSyncServer", error: error)
            self.isRunning = false
        }
    }
    
    public func stop() {
        listener?.cancel()
        listener = nil
        
        for session in activeSessions.values {
            session.cancel()
        }
        activeSessions.removeAll()
        activeConnectionCount = 0
        connectedDeviceNames = []
        isSyncing = false
        isRunning = false
        activePairingSession = nil
    }
    
    private func handleNewConnection(_ connection: NWConnection) {
        guard activeSessions.count < 4 else {
            connection.cancel()
            AppLogger.warning("Rejected sync connection: max connections limit reached")
            return
        }
        
        let session = SyncConnectionSession(connection: connection, server: self)
        let id = ObjectIdentifier(session)
        activeSessions[id] = session
        activeConnectionCount = activeSessions.count
        
        session.onClose = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.activeSessions.removeValue(forKey: id)
                self.activeConnectionCount = self.activeSessions.count
                self.updateConnectedDevices()
            }
        }
        
        session.start()
    }
    
    fileprivate func setPairingSession(_ session: ActivePairingSession?) {
        self.activePairingSession = session
    }
}

// MARK: - Per-Connection Session State Machine
@MainActor
fileprivate final class SyncConnectionSession: Identifiable {
    enum State {
        case idle
        case pairingPendingReveal(
            deviceId: String,
            deviceName: String,
            clientPubKey: P256.KeyAgreement.PublicKey,
            clientNonceCommit: Data,
            serverPrivKey: P256.KeyAgreement.PrivateKey,
            serverPubKeyDER: Data,
            serverNonce: Data
        )
        case pairingAwaitingConfirm(
            deviceId: String,
            deviceName: String,
            linkKey: SymmetricKey,
            sessionKey: SymmetricKey,
            serverNonce: Data,
            clientNonce: Data,
            userConfirmed: Bool,
            clientConfirmed: Bool
        )
        case sessionAwaitingAuth(
            device: PairedDevice,
            sessionKey: SymmetricKey,
            clientNonce: Data,
            serverNonce: Data
        )
        case authenticated(
            device: PairedDevice,
            sessionKey: SymmetricKey,
            inSeq: UInt64,
            outSeq: UInt64
        )
    }
    
    let connection: NWConnection
    unowned let server: LocalSyncServer
    var onClose: (() -> Void)?
    
    private var state: State = .idle
    private let sessionQueue = DispatchQueue(label: "com.priteshranjan.NoteNote.SyncSession", qos: .utility)
    
    init(connection: NWConnection, server: LocalSyncServer) {
        self.connection = connection
        self.server = server
    }
    
    func start() {
        connection.stateUpdateHandler = { [weak self] connState in
            Task { @MainActor [weak self] in
                switch connState {
                case .ready:
                    self?.receiveNextMessage()
                case .failed(let err):
                    AppLogger.debug("Sync connection failed: \(err.localizedDescription)")
                    self?.close()
                case .cancelled:
                    self?.close()
                default:
                    break
                }
            }
        }
        connection.start(queue: sessionQueue)
    }
    
    func cancel() {
        connection.cancel()
        close()
    }
    
    private func close() {
        onClose?()
        onClose = nil
    }
    
    private func receiveNextMessage() {
        connection.receiveMessage { [weak self] content, context, isComplete, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let error = error {
                    AppLogger.debug("Receive error: \(error.localizedDescription)")
                    self.cancel()
                    return
                }
                guard let data = content, !data.isEmpty else {
                    self.receiveNextMessage()
                    return
                }
                
                self.handleIncomingData(data)
                self.receiveNextMessage()
            }
        }
    }
    
    private func sendWireMessage(type: SyncMessageType, payload: Codable) {
        do {
            let payloadData = try JSONEncoder().encode(payload)
            let payloadString = String(data: payloadData, encoding: .utf8) ?? ""
            let message = SyncWireMessage(type: type, payload: payloadString)
            let wireData = try JSONEncoder().encode(message)
            
            let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
            let context = NWConnection.ContentContext(identifier: "syncFrame", metadata: [metadata])
            
            connection.send(content: wireData, contentContext: context, isComplete: true, completion: .contentProcessed { [weak self] error in
                if let error = error {
                    AppLogger.error("Failed to send wire message \(type.rawValue)", error: error)
                    Task { @MainActor [weak self] in
                        self?.cancel()
                    }
                }
            })
        } catch {
            AppLogger.error("Error encoding wire message \(type.rawValue)", error: error)
        }
    }
    
    private func handleIncomingData(_ data: Data) {
        guard let message = try? JSONDecoder().decode(SyncWireMessage.self, from: data) else {
            AppLogger.warning("Received malformed sync wire frame")
            return
        }
        guard let payloadData = message.payload.data(using: .utf8) else { return }
        
        switch message.type {
        case .pairInit:
            handlePairInit(payloadData)
        case .pairReveal:
            handlePairReveal(payloadData)
        case .pairConfirm:
            handlePairConfirm(payloadData)
        case .sessionInit:
            handleSessionInit(payloadData)
        case .sessionAuth:
            handleSessionAuth(payloadData)
        case .encrypted:
            handleEncryptedFrame(payloadData)
        default:
            AppLogger.debug("Unhandled wire message type: \(message.type.rawValue)")
        }
    }
    
    // MARK: - Pairing Handshake
    private func handlePairInit(_ data: Data) {
        guard let initMsg = try? JSONDecoder().decode(PairInitPayload.self, from: data),
              let clientPubKeyData = Data(base64Encoded: initMsg.clientPubKeyDER),
              let clientPubKey = try? SyncCryptoService.importPublicKeyDER(clientPubKeyData),
              let clientNonceCommit = Data(base64Encoded: initMsg.clientNonceCommit) else {
            sendError("Invalid PAIR_INIT parameters")
            return
        }
        
        let serverPrivKey = SyncCryptoService.generateEphemeralPrivateKey()
        let serverPubKeyDER = SyncCryptoService.exportPublicKeyDER(serverPrivKey.publicKey)
        let serverNonce = SyncCryptoService.generateRandomBytes(count: 32)
        
        self.state = .pairingPendingReveal(
            deviceId: initMsg.deviceId,
            deviceName: initMsg.deviceName,
            clientPubKey: clientPubKey,
            clientNonceCommit: clientNonceCommit,
            serverPrivKey: serverPrivKey,
            serverPubKeyDER: serverPubKeyDER,
            serverNonce: serverNonce
        )
        
        let challenge = PairChallengePayload(
            serverId: "NoteNote-Mac",
            serverName: Host.current().localizedName ?? "NoteNote Mac",
            serverPubKeyDER: serverPubKeyDER.base64EncodedString(),
            serverNonce: serverNonce.base64EncodedString()
        )
        sendWireMessage(type: .pairChallenge, payload: challenge)
    }
    
    private func handlePairReveal(_ data: Data) {
        guard case let .pairingPendingReveal(deviceId, deviceName, clientPubKey, clientNonceCommit, serverPrivKey, serverPubKeyDER, serverNonce) = self.state else {
            sendError("Unexpected PAIR_REVEAL")
            return
        }
        guard let revealMsg = try? JSONDecoder().decode(PairRevealPayload.self, from: data),
              let clientNonce = Data(base64Encoded: revealMsg.clientNonce) else {
            sendError("Malformed PAIR_REVEAL payload")
            return
        }
        
        // Verify commitment: SHA256(clientNonce) == clientNonceCommit
        let computedCommit = SyncCryptoService.sha256(clientNonce)
        guard computedCommit == clientNonceCommit else {
            sendError("Client nonce commitment check failed")
            cancel()
            return
        }
        
        let clientPubKeyDER = SyncCryptoService.exportPublicKeyDER(clientPubKey)
        let sixDigitCode = SyncCryptoService.computeSixDigitCode(
            clientPubKeyDER: clientPubKeyDER,
            serverPubKeyDER: serverPubKeyDER,
            clientNonce: clientNonce,
            serverNonce: serverNonce
        )
        
        guard let sharedSecret = try? SyncCryptoService.deriveSharedSecret(privateKey: serverPrivKey, peerPublicKey: clientPubKey) else {
            sendError("Failed to derive shared secret")
            cancel()
            return
        }
        let linkKey = SyncCryptoService.deriveLinkKey(sharedSecret: sharedSecret, clientNonce: clientNonce, serverNonce: serverNonce)
        let sessionKey = SyncCryptoService.deriveSessionKey(sharedSecret: sharedSecret, linkKey: linkKey, clientNonce: clientNonce, serverNonce: serverNonce)
        
        self.state = .pairingAwaitingConfirm(
            deviceId: deviceId,
            deviceName: deviceName,
            linkKey: linkKey,
            sessionKey: sessionKey,
            serverNonce: serverNonce,
            clientNonce: clientNonce,
            userConfirmed: false,
            clientConfirmed: false
        )
        
        // Present confirmation dialog on Mac
        let session = ActivePairingSession(deviceId: deviceId, deviceName: deviceName, sixDigitCode: sixDigitCode)
        server.setPairingSession(session)
        
        PairingConfirmationWindowController.shared.present(session: session) { [weak self] confirmed in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.server.setPairingSession(nil)
                if confirmed {
                    self.onUserConfirmedMac()
                } else {
                    self.sendWireMessage(type: .pairReject, payload: ["reason": "User declined pairing"])
                    self.cancel()
                }
            }
        }
    }
    
    private func onUserConfirmedMac() {
        guard case let .pairingAwaitingConfirm(deviceId, deviceName, linkKey, sessionKey, serverNonce, clientNonce, _, clientConfirmed) = self.state else {
            return
        }
        
        if clientConfirmed {
            completePairing(deviceId: deviceId, deviceName: deviceName, linkKey: linkKey, sessionKey: sessionKey, serverNonce: serverNonce, clientNonce: clientNonce)
        } else {
            self.state = .pairingAwaitingConfirm(
                deviceId: deviceId,
                deviceName: deviceName,
                linkKey: linkKey,
                sessionKey: sessionKey,
                serverNonce: serverNonce,
                clientNonce: clientNonce,
                userConfirmed: true,
                clientConfirmed: false
            )
        }
    }
    
    private func handlePairConfirm(_ data: Data) {
        guard case let .pairingAwaitingConfirm(deviceId, deviceName, linkKey, sessionKey, serverNonce, clientNonce, userConfirmed, _) = self.state else {
            sendError("Unexpected PAIR_CONFIRM")
            return
        }
        guard let confirmMsg = try? JSONDecoder().decode(PairConfirmPayload.self, from: data),
              let clientHmacData = Data(base64Encoded: confirmMsg.clientHmac) else {
            sendError("Malformed PAIR_CONFIRM payload")
            return
        }
        
        // Expected client HMAC = HMAC(linkKey, "CLIENT_PAIR_CONFIRM" + clientNonce + serverNonce)
        var clientExpectedMsg = "CLIENT_PAIR_CONFIRM".data(using: .utf8)!
        clientExpectedMsg.append(clientNonce)
        clientExpectedMsg.append(serverNonce)
        
        guard SyncCryptoService.verifyHMAC(key: linkKey, message: clientExpectedMsg, expected: clientHmacData) else {
            sendError("Invalid pairing proof")
            cancel()
            return
        }
        
        if userConfirmed {
            completePairing(deviceId: deviceId, deviceName: deviceName, linkKey: linkKey, sessionKey: sessionKey, serverNonce: serverNonce, clientNonce: clientNonce)
        } else {
            self.state = .pairingAwaitingConfirm(
                deviceId: deviceId,
                deviceName: deviceName,
                linkKey: linkKey,
                sessionKey: sessionKey,
                serverNonce: serverNonce,
                clientNonce: clientNonce,
                userConfirmed: false,
                clientConfirmed: true
            )
        }
    }
    
    private func completePairing(
        deviceId: String,
        deviceName: String,
        linkKey: SymmetricKey,
        sessionKey: SymmetricKey,
        serverNonce: Data,
        clientNonce: Data
    ) {
        // Compute server HMAC = HMAC(linkKey, "SERVER_PAIR_COMPLETE" + serverNonce + clientNonce)
        var serverExpectedMsg = "SERVER_PAIR_COMPLETE".data(using: .utf8)!
        serverExpectedMsg.append(serverNonce)
        serverExpectedMsg.append(clientNonce)
        let serverHmac = SyncCryptoService.computeHMAC(key: linkKey, message: serverExpectedMsg)
        
        // Save paired device in NotesStore
        let linkKeyBase64 = linkKey.withUnsafeBytes { Data($0).base64EncodedString() }
        let paired = PairedDevice(id: deviceId, name: deviceName, linkKeyBase64: linkKeyBase64)
        NotesStore.shared.addPairedDevice(paired)
        
        // Transition to authenticated state
        self.state = .authenticated(device: paired, sessionKey: sessionKey, inSeq: 1, outSeq: 1)
        server.updateConnectedDevices()
        
        let completePayload = PairCompletePayload(serverHmac: serverHmac.base64EncodedString(), status: "OK")
        sendWireMessage(type: .pairComplete, payload: completePayload)
        AppLogger.info("Successfully paired with Android device '\(deviceName)' (\(deviceId))")
    }
    
    // MARK: - Trusted Session Reconnect
    private func handleSessionInit(_ data: Data) {
        guard let initMsg = try? JSONDecoder().decode(SessionInitPayload.self, from: data),
              let clientPubKeyData = Data(base64Encoded: initMsg.clientPubKeyDER),
              let clientPubKey = try? SyncCryptoService.importPublicKeyDER(clientPubKeyData),
              let clientNonce = Data(base64Encoded: initMsg.clientNonce) else {
            sendError("Invalid SESSION_INIT")
            return
        }
        
        guard let pairedDevice = NotesStore.shared.pairedDevices.first(where: { $0.id == initMsg.deviceId }),
              let linkKeyData = Data(base64Encoded: pairedDevice.linkKeyBase64) else {
            sendError("Device not paired")
            cancel()
            return
        }
        
        let serverPrivKey = SyncCryptoService.generateEphemeralPrivateKey()
        let serverPubKeyDER = SyncCryptoService.exportPublicKeyDER(serverPrivKey.publicKey)
        let serverNonce = SyncCryptoService.generateRandomBytes(count: 32)
        
        guard let sharedSecret = try? SyncCryptoService.deriveSharedSecret(privateKey: serverPrivKey, peerPublicKey: clientPubKey) else {
            sendError("Failed to compute session shared secret")
            cancel()
            return
        }
        let linkKey = SymmetricKey(data: linkKeyData)
        let sessionKey = SyncCryptoService.deriveSessionKey(sharedSecret: sharedSecret, linkKey: linkKey, clientNonce: clientNonce, serverNonce: serverNonce)
        
        self.state = .sessionAwaitingAuth(
            device: pairedDevice,
            sessionKey: sessionKey,
            clientNonce: clientNonce,
            serverNonce: serverNonce
        )
        
        let challenge = SessionChallengePayload(
            serverId: "NoteNote-Mac",
            serverPubKeyDER: serverPubKeyDER.base64EncodedString(),
            serverNonce: serverNonce.base64EncodedString()
        )
        sendWireMessage(type: .sessionChallenge, payload: challenge)
    }
    
    private func handleSessionAuth(_ data: Data) {
        guard case let .sessionAwaitingAuth(device, sessionKey, clientNonce, serverNonce) = self.state else {
            sendError("Unexpected SESSION_AUTH")
            return
        }
        guard let authMsg = try? JSONDecoder().decode(SessionAuthPayload.self, from: data),
              let clientHmacData = Data(base64Encoded: authMsg.clientHmac) else {
            sendError("Malformed SESSION_AUTH payload")
            return
        }
        
        // Expected client HMAC = HMAC(sessionKey, "CLIENT_SESSION_AUTH" + clientNonce + serverNonce)
        var expectedMsg = "CLIENT_SESSION_AUTH".data(using: .utf8)!
        expectedMsg.append(clientNonce)
        expectedMsg.append(serverNonce)
        
        guard SyncCryptoService.verifyHMAC(key: sessionKey, message: expectedMsg, expected: clientHmacData) else {
            sendError("Invalid session authentication proof")
            cancel()
            return
        }
        
        // Server HMAC = HMAC(sessionKey, "SERVER_SESSION_OK" + serverNonce + clientNonce)
        var serverMsg = "SERVER_SESSION_OK".data(using: .utf8)!
        serverMsg.append(serverNonce)
        serverMsg.append(clientNonce)
        let serverHmac = SyncCryptoService.computeHMAC(key: sessionKey, message: serverMsg)
        
        self.state = .authenticated(device: device, sessionKey: sessionKey, inSeq: 1, outSeq: 1)
        server.updateConnectedDevices()
        
        let okPayload = SessionOkPayload(serverHmac: serverHmac.base64EncodedString(), status: "OK")
        sendWireMessage(type: .sessionOk, payload: okPayload)
        AppLogger.info("Authenticated trusted session for device '\(device.name)'")
    }
    
    var isAuthenticated: Bool {
        if case .authenticated = state { return true }
        return false
    }
    
    var authenticatedDeviceName: String? {
        if case let .authenticated(device, _, _, _) = state { return device.name }
        return nil
    }
    
    func pushMacNotesToClient() {
        guard case let .authenticated(device, sessionKey, inSeq, outSeq) = state else { return }
        let macNotes = NotesStore.shared.exportableNotesForSync()
        let response = SyncAppResponse(
            status: "OK",
            action: .syncAll,
            notes: macNotes,
            serverTime: Date()
        )
        sendEncryptedResponse(response, sessionKey: sessionKey, seq: outSeq)
        self.state = .authenticated(device: device, sessionKey: sessionKey, inSeq: inSeq, outSeq: outSeq + 1)
        AppLogger.info("Pushed \(macNotes.count) notes to '\(device.name)' via manual Mac sync trigger")
    }
    
    private static func makeFlexibleJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let str = try? container.decode(String.self) {
                if let d = SyncNoteDTO.parseDateString(str) { return d }
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date string: \(str)")
            }
            if let num = try? container.decode(Double.self) {
                if num > 100_000_000_000 { return Date(timeIntervalSince1970: num / 1000.0) }
                if num > 100_000_000 { return Date(timeIntervalSince1970: num) }
                return Date(timeIntervalSinceReferenceDate: num)
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected ISO8601 date string or number")
        }
        return decoder
    }
    
    private static func makeISO8601JSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func handleEncryptedFrame(_ data: Data) {
        guard case let .authenticated(device, sessionKey, inSeq, outSeq) = self.state else {
            sendError("Not authenticated")
            cancel()
            return
        }
        guard let encPayload = try? JSONDecoder().decode(EncryptedPayload.self, from: data),
              let ivData = Data(base64Encoded: encPayload.iv),
              let ciphertextData = Data(base64Encoded: encPayload.ciphertext) else {
            sendError("Malformed encrypted frame")
            return
        }
        
        // Tolerate sequence counter matching or starting at 0
        guard encPayload.seq == inSeq || (encPayload.seq == 0 && inSeq == 1) else {
            AppLogger.warning("Rejected encrypted frame: expected seq \(inSeq), got \(encPayload.seq)")
            sendError("Invalid sequence counter")
            cancel()
            return
        }
        let effectiveInSeq = max(inSeq, encPayload.seq)
        
        do {
            let plaintextData = try SyncCryptoService.decryptAESGCM(
                key: sessionKey,
                iv: ivData,
                ciphertextWithTag: ciphertextData,
                seq: encPayload.seq,
                direction: "C2S"
            )
            
            let rawJson = String(data: plaintextData, encoding: .utf8) ?? "<non-utf8>"
            AppLogger.info("Decrypted sync message from '\(device.name)': \(rawJson.prefix(300))")
            
            let request: SyncAppRequest
            if let decoded = try? Self.makeFlexibleJSONDecoder().decode(SyncAppRequest.self, from: plaintextData) {
                request = decoded
            } else if let rawObj = try? JSONSerialization.jsonObject(with: plaintextData) as? [String: Any] {
                let actionStr = (rawObj["action"] as? String)?.uppercased() ?? "SYNC_ALL"
                let action: EncryptedAction
                switch actionStr {
                case "PUSH_NOTES", "PUSH": action = .pushNotes
                case "PULL_NOTES", "PULL": action = .pullNotes
                case "PING": action = .ping
                default: action = .syncAll
                }
                var notesList: [SyncNoteDTO] = []
                if let rawNotes = rawObj["notes"] as? [[String: Any]] {
                    for noteDict in rawNotes {
                        if let noteData = try? JSONSerialization.data(withJSONObject: noteDict),
                           let note = try? Self.makeFlexibleJSONDecoder().decode(SyncNoteDTO.self, from: noteData) {
                            notesList.append(note)
                        }
                    }
                }
                request = SyncAppRequest(action: action, notes: notesList.isEmpty ? nil : notesList)
            } else {
                request = try Self.makeFlexibleJSONDecoder().decode(SyncAppRequest.self, from: plaintextData)
            }
            
            processAppRequest(request, device: device, sessionKey: sessionKey, nextInSeq: effectiveInSeq + 1, currentOutSeq: outSeq)
        } catch {
            AppLogger.error("Failed to decrypt or decode encrypted frame", error: error)
            sendError("Decryption failure")
        }
    }
    
    private func processAppRequest(
        _ request: SyncAppRequest,
        device: PairedDevice,
        sessionKey: SymmetricKey,
        nextInSeq: UInt64,
        currentOutSeq: UInt64
    ) {
        var response = SyncAppResponse(status: "OK", action: request.action)
        
        switch request.action {
        case .ping:
            response.action = .pong
            
        case .pushNotes:
            let notes = request.notes ?? []
            NotesStore.shared.upsertSyncedNotes(notes, from: device)
            response.upsertedCount = notes.count
            AppLogger.info("Received \(notes.count) notes from '\(device.name)'")
            
        case .pullNotes:
            let macNotes = NotesStore.shared.exportableNotesForSync()
            if let since = request.since {
                response.notes = macNotes.filter { $0.updatedAt > since }
            } else {
                response.notes = macNotes
            }
            AppLogger.info("Sent \(response.notes?.count ?? 0) notes to '\(device.name)'")
            
        case .syncAll:
            if let incoming = request.notes, !incoming.isEmpty {
                NotesStore.shared.upsertSyncedNotes(incoming, from: device)
                response.upsertedCount = incoming.count
            }
            let macNotes = NotesStore.shared.exportableNotesForSync()
            if let since = request.since {
                response.notes = macNotes.filter { $0.updatedAt > since }
            } else {
                response.notes = macNotes
            }
            AppLogger.info("Bidirectional sync completed with '\(device.name)': pushed \(request.notes?.count ?? 0), pulled \(response.notes?.count ?? 0)")
            
        case .unpair:
            NotesStore.shared.removePairedDevice(id: device.id)
            response.status = "UNPAIRED"
            AppLogger.info("Unpaired device '\(device.name)' requested by client")
            
        default:
            response.action = .ack
        }
        
        sendEncryptedResponse(response, sessionKey: sessionKey, seq: currentOutSeq)
        self.state = .authenticated(device: device, sessionKey: sessionKey, inSeq: nextInSeq, outSeq: currentOutSeq + 1)
        server.lastSyncDate = Date()
    }
    
    private func sendEncryptedResponse(_ response: SyncAppResponse, sessionKey: SymmetricKey, seq: UInt64) {
        do {
            let plaintextData = try Self.makeISO8601JSONEncoder().encode(response)
            let (iv, ciphertext) = try SyncCryptoService.encryptAESGCM(
                key: sessionKey,
                plaintext: plaintextData,
                seq: seq,
                direction: "S2C"
            )
            let encPayload = EncryptedPayload(
                seq: seq,
                iv: iv.base64EncodedString(),
                ciphertext: ciphertext.base64EncodedString()
            )
            sendWireMessage(type: .encrypted, payload: encPayload)
        } catch {
            AppLogger.error("Failed to encrypt application response", error: error)
        }
    }
    
    private func sendError(_ message: String) {
        sendWireMessage(type: .error, payload: ["error": message])
    }
}

// MARK: - Local IPv4 Interface Discovery
fileprivate func getLocalIPv4Addresses() -> [String] {
    var addresses: [String] = []
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    
    guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return [] }
    defer { freeifaddrs(ifaddr) }
    
    for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
        let interface = ptr.pointee
        let addrFamily = interface.ifa_addr.pointee.sa_family
        if addrFamily == UInt8(AF_INET) {
            let name = String(cString: interface.ifa_name)
            // Filter loopback and check flags (must be UP and RUNNING)
            let flags = Int32(interface.ifa_flags)
            if (flags & IFF_UP) != 0 && (flags & IFF_RUNNING) != 0 && (flags & IFF_LOOPBACK) == 0 {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(
                    interface.ifa_addr,
                    socklen_t(interface.ifa_addr.pointee.sa_len),
                    &hostname,
                    socklen_t(hostname.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                )
                let ip = String(cString: hostname)
                if !ip.isEmpty && !addresses.contains(ip) {
                    // Prefer en0/en1 (Wi-Fi) first
                    if name.hasPrefix("en") {
                        addresses.insert(ip, at: 0)
                    } else {
                        addresses.append(ip)
                    }
                }
            }
        }
    }
    return addresses
}
