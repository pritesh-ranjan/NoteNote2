import Foundation
import CryptoKit

public enum SyncCryptoError: LocalizedError {
    case invalidPublicKey
    case invalidCiphertext
    case commitmentMismatch
    case authenticationFailed
    case replayOrOutdatedSequence
    
    public var errorDescription: String? {
        switch self {
        case .invalidPublicKey:
            return "Invalid peer public key"
        case .invalidCiphertext:
            return "Ciphertext is malformed or corrupted"
        case .commitmentMismatch:
            return "Client nonce does not match commitment"
        case .authenticationFailed:
            return "Handshake proof verification failed"
        case .replayOrOutdatedSequence:
            return "Rejected frame with invalid or replayed sequence number"
        }
    }
}

public enum SyncCryptoService {
    
    // MARK: - Key Generation & Exchange (P-256)
    public static func generateEphemeralPrivateKey() -> P256.KeyAgreement.PrivateKey {
        P256.KeyAgreement.PrivateKey()
    }
    
    public static func exportPublicKeyDER(_ publicKey: P256.KeyAgreement.PublicKey) -> Data {
        publicKey.derRepresentation
    }
    
    public static func importPublicKeyDER(_ data: Data) throws -> P256.KeyAgreement.PublicKey {
        try P256.KeyAgreement.PublicKey(derRepresentation: data)
    }
    
    public static func generateRandomBytes(count: Int = 32) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes)
    }
    
    public static func sha256(_ data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }
    
    // MARK: - Numeric Comparison Code (Bluetooth SSP Style)
    public static func computeSixDigitCode(
        clientPubKeyDER: Data,
        serverPubKeyDER: Data,
        clientNonce: Data,
        serverNonce: Data
    ) -> String {
        var transcript = Data()
        transcript.append("NoteNote-Pair-v1".data(using: .utf8)!)
        transcript.append(clientPubKeyDER)
        transcript.append(serverPubKeyDER)
        transcript.append(clientNonce)
        transcript.append(serverNonce)
        
        let digest = SHA256.hash(data: transcript)
        let num: UInt32 = digest.withUnsafeBytes { ptr in
            ptr.load(as: UInt32.self).bigEndian
        }
        let code = num % 1_000_000
        return String(format: "%06d", code)
    }
    
    // MARK: - Key Derivation (HKDF-SHA256)
    public static func deriveSharedSecret(
        privateKey: P256.KeyAgreement.PrivateKey,
        peerPublicKey: P256.KeyAgreement.PublicKey
    ) throws -> SharedSecret {
        try privateKey.sharedSecretFromKeyAgreement(with: peerPublicKey)
    }
    
    public static func deriveLinkKey(
        sharedSecret: SharedSecret,
        clientNonce: Data,
        serverNonce: Data
    ) -> SymmetricKey {
        var salt = Data()
        salt.append(clientNonce)
        salt.append(serverNonce)
        return sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: salt,
            sharedInfo: "NoteNote-LinkKey-v1".data(using: .utf8)!,
            outputByteCount: 32
        )
    }
    
    public static func deriveSessionKey(
        sharedSecret: SharedSecret,
        linkKey: SymmetricKey,
        clientNonce: Data,
        serverNonce: Data
    ) -> SymmetricKey {
        var info = Data()
        info.append("NoteNote-SessionKey-v1".data(using: .utf8)!)
        info.append(clientNonce)
        info.append(serverNonce)
        let linkKeyData = linkKey.withUnsafeBytes { Data($0) }
        return sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: linkKeyData,
            sharedInfo: info,
            outputByteCount: 32
        )
    }
    
    // MARK: - HMAC Proofs
    public static func computeHMAC(key: SymmetricKey, message: Data) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: message, using: key))
    }
    
    public static func verifyHMAC(key: SymmetricKey, message: Data, expected: Data) -> Bool {
        let actual = computeHMAC(key: key, message: message)
        return actual == expected
    }
    
    // MARK: - AES-256-GCM with Directional Sequence AAD
    public static func encryptAESGCM(
        key: SymmetricKey,
        plaintext: Data,
        seq: UInt64,
        direction: String
    ) throws -> (iv: Data, ciphertextWithTag: Data) {
        let nonce = AES.GCM.Nonce()
        let aad = "\(direction):\(seq)".data(using: .utf8)!
        let sealedBox = try AES.GCM.seal(plaintext, using: key, nonce: nonce, authenticating: aad)
        
        var combined = Data()
        combined.append(sealedBox.ciphertext)
        combined.append(sealedBox.tag)
        return (iv: Data(nonce), ciphertextWithTag: combined)
    }
    
    public static func decryptAESGCM(
        key: SymmetricKey,
        iv: Data,
        ciphertextWithTag: Data,
        seq: UInt64,
        direction: String
    ) throws -> Data {
        guard ciphertextWithTag.count >= 16 else {
            throw SyncCryptoError.invalidCiphertext
        }
        let ciphertext = ciphertextWithTag.prefix(ciphertextWithTag.count - 16)
        let tag = ciphertextWithTag.suffix(16)
        let nonce = try AES.GCM.Nonce(data: iv)
        let aad = "\(direction):\(seq)".data(using: .utf8)!
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        return try AES.GCM.open(sealedBox, using: key, authenticating: aad)
    }
}
