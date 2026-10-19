import Foundation
import CryptoKit
import Network

@MainActor
public final class SyncVerificationService {
    public static let shared = SyncVerificationService()
    
    private init() {}
    
    public func runVerificationTest() {
        Task {
            print("🧪 [SyncTest] Starting Wi-Fi Sync & Encryption Verification...")
            
            // 1. Ensure server is started
            LocalSyncServer.shared.start()
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
            
            let port = LocalSyncServer.shared.localPort
            print("🧪 [SyncTest] Server running on port \(port)")
            
            let url = URL(string: "ws://127.0.0.1:\(port)")!
            let session = URLSession(configuration: .default)
            let wsTask = session.webSocketTask(with: url)
            wsTask.resume()
            
            do {
                // 2. Generate client P-256 ephemeral keys & nonce
                let clientPrivKey = SyncCryptoService.generateEphemeralPrivateKey()
                let clientPubKeyDER = SyncCryptoService.exportPublicKeyDER(clientPrivKey.publicKey)
                let clientNonce = SyncCryptoService.generateRandomBytes(count: 32)
                let clientNonceCommit = SyncCryptoService.sha256(clientNonce)
                
                let deviceId = "test-android-device-\(UUID().uuidString.prefix(8))"
                let deviceName = "Google Pixel 8 Pro (Test)"
                
                // 3. Send PAIR_INIT
                let initPayload = PairInitPayload(
                    deviceId: deviceId,
                    deviceName: deviceName,
                    clientPubKeyDER: clientPubKeyDER.base64EncodedString(),
                    clientNonceCommit: clientNonceCommit.base64EncodedString()
                )
                let initWire = SyncWireMessage(
                    type: .pairInit,
                    payload: String(data: try JSONEncoder().encode(initPayload), encoding: .utf8)!
                )
                try await wsTask.send(.data(try JSONEncoder().encode(initWire)))
                print("🧪 [SyncTest] Sent PAIR_INIT")
                
                // 4. Receive PAIR_CHALLENGE
                let challengeMsg = try await receiveWireMessage(from: wsTask)
                assert(challengeMsg.type == .pairChallenge, "Expected PAIR_CHALLENGE, got \(challengeMsg.type)")
                let challengePayload = try JSONDecoder().decode(PairChallengePayload.self, from: challengeMsg.payload.data(using: .utf8)!)
                let serverPubKeyDER = Data(base64Encoded: challengePayload.serverPubKeyDER)!
                let serverNonce = Data(base64Encoded: challengePayload.serverNonce)!
                let serverPubKey = try SyncCryptoService.importPublicKeyDER(serverPubKeyDER)
                print("🧪 [SyncTest] Received PAIR_CHALLENGE from '\(challengePayload.serverName)'")
                
                // 5. Send PAIR_REVEAL
                let revealPayload = PairRevealPayload(clientNonce: clientNonce.base64EncodedString())
                let revealWire = SyncWireMessage(
                    type: .pairReveal,
                    payload: String(data: try JSONEncoder().encode(revealPayload), encoding: .utf8)!
                )
                try await wsTask.send(.data(try JSONEncoder().encode(revealWire)))
                print("🧪 [SyncTest] Sent PAIR_REVEAL with client nonce")
                
                // 6. Compute client 6-digit code
                let clientCode = SyncCryptoService.computeSixDigitCode(
                    clientPubKeyDER: clientPubKeyDER,
                    serverPubKeyDER: serverPubKeyDER,
                    clientNonce: clientNonce,
                    serverNonce: serverNonce
                )
                print("🧪 [SyncTest] Client computed 6-digit code: \(clientCode)")
                
                // Give Mac server a moment to compute and present pairing dialog
                try? await Task.sleep(nanoseconds: 400_000_000)
                if let serverSession = LocalSyncServer.shared.activePairingSession {
                    print("🧪 [SyncTest] Server active pairing session code: \(serverSession.sixDigitCode)")
                    assert(serverSession.sixDigitCode == clientCode, "6-digit code mismatch between client and server!")
                    print("✅ [SyncTest] 6-digit confirmation codes MATCH!")
                }
                
                // Simulate Mac user clicking "Confirm & Pair"
                PairingConfirmationWindowController.shared.dismiss(confirmed: true)
                print("🧪 [SyncTest] Approved pairing on Mac")
                
                // 7. Derive client keys
                let sharedSecret = try SyncCryptoService.deriveSharedSecret(privateKey: clientPrivKey, peerPublicKey: serverPubKey)
                let linkKey = SyncCryptoService.deriveLinkKey(sharedSecret: sharedSecret, clientNonce: clientNonce, serverNonce: serverNonce)
                let sessionKey = SyncCryptoService.deriveSessionKey(sharedSecret: sharedSecret, linkKey: linkKey, clientNonce: clientNonce, serverNonce: serverNonce)
                
                // 8. Send PAIR_CONFIRM with HMAC
                var clientExpectedMsg = "CLIENT_PAIR_CONFIRM".data(using: .utf8)!
                clientExpectedMsg.append(clientNonce)
                clientExpectedMsg.append(serverNonce)
                let clientHmac = SyncCryptoService.computeHMAC(key: linkKey, message: clientExpectedMsg)
                
                let confirmPayload = PairConfirmPayload(clientHmac: clientHmac.base64EncodedString())
                let confirmWire = SyncWireMessage(
                    type: .pairConfirm,
                    payload: String(data: try JSONEncoder().encode(confirmPayload), encoding: .utf8)!
                )
                try await wsTask.send(.data(try JSONEncoder().encode(confirmWire)))
                print("🧪 [SyncTest] Sent PAIR_CONFIRM HMAC proof")
                
                // 9. Receive PAIR_COMPLETE
                let completeMsg = try await receiveWireMessage(from: wsTask)
                assert(completeMsg.type == .pairComplete, "Expected PAIR_COMPLETE, got \(completeMsg.type)")
                let completePayload = try JSONDecoder().decode(PairCompletePayload.self, from: completeMsg.payload.data(using: .utf8)!)
                
                // Verify server HMAC
                var serverExpectedMsg = "SERVER_PAIR_COMPLETE".data(using: .utf8)!
                serverExpectedMsg.append(serverNonce)
                serverExpectedMsg.append(clientNonce)
                let serverExpectedHmac = SyncCryptoService.computeHMAC(key: linkKey, message: serverExpectedMsg)
                assert(completePayload.serverHmac == serverExpectedHmac.base64EncodedString(), "Server HMAC verification failed!")
                print("✅ [SyncTest] Server HMAC verified. Pairing complete!")
                
                // Verify device saved in NotesStore
                assert(NotesStore.shared.pairedDevices.contains(where: { $0.id == deviceId }), "Paired device was not stored in NotesStore!")
                print("✅ [SyncTest] Device successfully stored in NotesStore.pairedDevices")
                
                // 10. Send Encrypted PUSH_NOTES (seq=1)
                let testNote = SyncNoteDTO(
                    id: UUID(),
                    title: "Hello from Android Wi-Fi!",
                    content: "This note was encrypted with AES-256-GCM and synced over local Wi-Fi.\n\n- [x] Ephemeral P-256 ECDH\n- [x] 6-digit numeric comparison\n- [x] AES-GCM replay protection",
                    color: "green",
                    isPinned: true
                )
                let pushReq = SyncAppRequest(action: .pushNotes, notes: [testNote])
                let (pushIv, pushCiphertext) = try SyncCryptoService.encryptAESGCM(
                    key: sessionKey,
                    plaintext: try JSONEncoder().encode(pushReq),
                    seq: 1,
                    direction: "C2S"
                )
                let pushEncPayload = EncryptedPayload(
                    seq: 1,
                    iv: pushIv.base64EncodedString(),
                    ciphertext: pushCiphertext.base64EncodedString()
                )
                let pushWire = SyncWireMessage(
                    type: .encrypted,
                    payload: String(data: try JSONEncoder().encode(pushEncPayload), encoding: .utf8)!
                )
                try await wsTask.send(.data(try JSONEncoder().encode(pushWire)))
                print("🧪 [SyncTest] Sent encrypted PUSH_NOTES")
                
                // Receive encrypted response (seq=1)
                let pushRespWire = try await receiveWireMessage(from: wsTask)
                assert(pushRespWire.type == .encrypted, "Expected ENCRYPTED response")
                let pushRespEnc = try JSONDecoder().decode(EncryptedPayload.self, from: pushRespWire.payload.data(using: .utf8)!)
                let pushRespData = try SyncCryptoService.decryptAESGCM(
                    key: sessionKey,
                    iv: Data(base64Encoded: pushRespEnc.iv)!,
                    ciphertextWithTag: Data(base64Encoded: pushRespEnc.ciphertext)!,
                    seq: pushRespEnc.seq,
                    direction: "S2C"
                )
                let pushResp = try JSONDecoder().decode(SyncAppResponse.self, from: pushRespData)
                assert(pushResp.status == "OK" && pushResp.upsertedCount == 1, "Expected status OK and upsertedCount 1")
                print("✅ [SyncTest] PUSH_NOTES succeeded. Upserted: \(pushResp.upsertedCount ?? 0)")
                
                // Verify note exists in syncedNotes
                assert(NotesStore.shared.syncedNotes.contains(where: { $0.id == testNote.id }), "Pushed note not found in syncedNotes!")
                print("✅ [SyncTest] Note verified in NotesStore.syncedNotes!")
                
                // 11. Send Encrypted PULL_NOTES (seq=2)
                let pullReq = SyncAppRequest(action: .pullNotes)
                let (pullIv, pullCiphertext) = try SyncCryptoService.encryptAESGCM(
                    key: sessionKey,
                    plaintext: try JSONEncoder().encode(pullReq),
                    seq: 2,
                    direction: "C2S"
                )
                let pullEncPayload = EncryptedPayload(
                    seq: 2,
                    iv: pullIv.base64EncodedString(),
                    ciphertext: pullCiphertext.base64EncodedString()
                )
                let pullWire = SyncWireMessage(
                    type: .encrypted,
                    payload: String(data: try JSONEncoder().encode(pullEncPayload), encoding: .utf8)!
                )
                try await wsTask.send(.data(try JSONEncoder().encode(pullWire)))
                print("🧪 [SyncTest] Sent encrypted PULL_NOTES")
                
                // Receive encrypted response (seq=2)
                let pullRespWire = try await receiveWireMessage(from: wsTask)
                assert(pullRespWire.type == .encrypted, "Expected ENCRYPTED response")
                let pullRespEnc = try JSONDecoder().decode(EncryptedPayload.self, from: pullRespWire.payload.data(using: .utf8)!)
                let pullRespData = try SyncCryptoService.decryptAESGCM(
                    key: sessionKey,
                    iv: Data(base64Encoded: pullRespEnc.iv)!,
                    ciphertextWithTag: Data(base64Encoded: pullRespEnc.ciphertext)!,
                    seq: pullRespEnc.seq,
                    direction: "S2C"
                )
                let pullResp = try JSONDecoder().decode(SyncAppResponse.self, from: pullRespData)
                assert(pullResp.status == "OK" && (pullResp.notes?.count ?? 0) > 0, "Expected non-empty notes list from Mac")
                print("✅ [SyncTest] PULL_NOTES succeeded. Received \(pullResp.notes?.count ?? 0) notes from Mac!")
                
                // Close initial session
                wsTask.cancel(with: .normalClosure, reason: nil)
                print("🧪 [SyncTest] Closed pairing connection. Testing automatic reconnect with linkKey...")
                
                // 12. Test Passwordless SESSION_INIT Reconnect
                let reconnectWs = session.webSocketTask(with: url)
                reconnectWs.resume()
                
                let clientSessionPrivKey = SyncCryptoService.generateEphemeralPrivateKey()
                let clientSessionPubKeyDER = SyncCryptoService.exportPublicKeyDER(clientSessionPrivKey.publicKey)
                let clientSessionNonce = SyncCryptoService.generateRandomBytes(count: 32)
                
                let sessionInitPayload = SessionInitPayload(
                    deviceId: deviceId,
                    clientPubKeyDER: clientSessionPubKeyDER.base64EncodedString(),
                    clientNonce: clientSessionNonce.base64EncodedString()
                )
                let sessionInitWire = SyncWireMessage(
                    type: .sessionInit,
                    payload: String(data: try JSONEncoder().encode(sessionInitPayload), encoding: .utf8)!
                )
                try await reconnectWs.send(.data(try JSONEncoder().encode(sessionInitWire)))
                
                let sessionChallengeMsg = try await receiveWireMessage(from: reconnectWs)
                assert(sessionChallengeMsg.type == .sessionChallenge, "Expected SESSION_CHALLENGE")
                let sessionChallengePayload = try JSONDecoder().decode(SessionChallengePayload.self, from: sessionChallengeMsg.payload.data(using: .utf8)!)
                let serverSessionPubKey = try SyncCryptoService.importPublicKeyDER(Data(base64Encoded: sessionChallengePayload.serverPubKeyDER)!)
                let serverSessionNonce = Data(base64Encoded: sessionChallengePayload.serverNonce)!
                
                let sessionSharedSecret = try SyncCryptoService.deriveSharedSecret(privateKey: clientSessionPrivKey, peerPublicKey: serverSessionPubKey)
                let reconnectedSessionKey = SyncCryptoService.deriveSessionKey(
                    sharedSecret: sessionSharedSecret,
                    linkKey: linkKey,
                    clientNonce: clientSessionNonce,
                    serverNonce: serverSessionNonce
                )
                
                var clientSessionMsg = "CLIENT_SESSION_AUTH".data(using: .utf8)!
                clientSessionMsg.append(clientSessionNonce)
                clientSessionMsg.append(serverSessionNonce)
                let clientSessionHmac = SyncCryptoService.computeHMAC(key: reconnectedSessionKey, message: clientSessionMsg)
                
                let sessionAuthPayload = SessionAuthPayload(clientHmac: clientSessionHmac.base64EncodedString())
                let sessionAuthWire = SyncWireMessage(
                    type: .sessionAuth,
                    payload: String(data: try JSONEncoder().encode(sessionAuthPayload), encoding: .utf8)!
                )
                try await reconnectWs.send(.data(try JSONEncoder().encode(sessionAuthWire)))
                
                let sessionOkMsg = try await receiveWireMessage(from: reconnectWs)
                assert(sessionOkMsg.type == .sessionOk, "Expected SESSION_OK")
                print("✅ [SyncTest] Passwordless trusted reconnect succeeded!")
                
                reconnectWs.cancel(with: .normalClosure, reason: nil)
                
                print("🎉 [SyncTest] ALL TESTS PASSED SUCCESSFULLY!")
                exit(0)
            } catch {
                print("❌ [SyncTest] Test failed with error: \(error)")
                exit(1)
            }
        }
    }
    
    private func receiveWireMessage(from wsTask: URLSessionWebSocketTask) async throws -> SyncWireMessage {
        let msg = try await wsTask.receive()
        switch msg {
        case .data(let data):
            return try JSONDecoder().decode(SyncWireMessage.self, from: data)
        case .string(let str):
            let data = str.data(using: .utf8)!
            return try JSONDecoder().decode(SyncWireMessage.self, from: data)
        @unknown default:
            fatalError("Unknown message format")
        }
    }
}
