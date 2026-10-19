# NoteNote Local Wi-Fi Sync Protocol Specification (Android Client Implementation Guide)

This document specifies the exact network, discovery, pairing, cryptography, and synchronization protocol used by **NoteNote for Mac** to sync notes with an Android companion app over the same Wi-Fi network.

Feed this document to an AI coding agent or Android developer to implement the Android client.

---

## 1. Architectural Overview

- **Transport**: Standard WebSocket (`ws://<mac-ip>:<port>`).
- **Default Port**: `52849` (configurable in Mac Preferences).
- **Service Discovery**: mDNS / Bonjour using Android's native `NsdManager` (`_notenote-sync._tcp.`). Manual IP and port connection is supported as fallback.
- **Pairing Mode**: Bluetooth-style Secure Simple Pairing (Numeric Comparison) with a 6-digit verification code confirmed on both devices.
- **Subsequent Reconnects**: Fast, passwordless automatic session authentication using a persisted 256-bit `linkKey`.
- **Encryption Suite**:
  - **Key Agreement**: NIST `P-256` (`secp256r1`) ECDH.
  - **Public Key Encoding**: Standard X.509 `SubjectPublicKeyInfo` DER (`publicKey.encoded` in Android `java.security` $\leftrightarrow$ `publicKey.derRepresentation` in Apple `CryptoKit`).
  - **Key Derivation**: RFC 5869 `HKDF-SHA256`.
  - **Message Authentication**: `HMAC-SHA256`.
  - **Symmetric Encryption**: `AES-256-GCM` with a 12-byte random IV, 16-byte authentication tag, and monotonic sequence counter Additional Authenticated Data (`AAD`) preventing replay and reflection attacks.

---

## 2. Service Discovery (mDNS / Bonjour)

The Mac advertises a Bonjour service on the local network:
- **Service Type**: `_notenote-sync._tcp.` (or `_notenote-sync._tcp` without trailing dot).
- **Service Name**: Usually the user's Mac name (e.g., `Pritesh’s MacBook Air`).
- **Port**: Typically `52849`.

### Android `NsdManager` Implementation Example:
```kotlin
import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo

class NoteNoteDiscovery(context: Context, val onDiscovered: (host: String, port: Int, name: String) -> Unit) {
    private val nsdManager = context.getSystemService(Context.NSD_SERVICE) as NsdManager
    private val serviceType = "_notenote-sync._tcp."

    private val discoveryListener = object : NsdManager.DiscoveryListener {
        override fun onDiscoveryStarted(regType: String) {}
        override fun onServiceFound(service: NsdServiceInfo) {
            if (service.serviceType.contains("_notenote-sync")) {
                nsdManager.resolveService(service, object : NsdManager.ResolveListener {
                    override fun onServiceResolved(resolved: NsdServiceInfo) {
                        val host = resolved.host.hostAddress ?: return
                        onDiscovered(host, resolved.port, resolved.serviceName)
                    }
                    override fun onResolveFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {}
                })
            }
        }
        override fun onServiceLost(service: NsdServiceInfo) {}
        override fun onDiscoveryStopped(serviceType: String) {}
        override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {}
        override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {}
    }

    fun start() = nsdManager.discoverServices(serviceType, NsdManager.PROTOCOL_DNS_SD, discoveryListener)
    fun stop() = nsdManager.stopServiceDiscovery(discoveryListener)
}
```

---

## 3. WebSocket Wire Framing

All messages over the WebSocket are UTF-8 JSON text frames with an outer envelope:

```json
{
  "type": "<MESSAGE_TYPE>",
  "payload": "<JSON string of the inner payload>"
}
```

> **Note**: `payload` is an escaped JSON string of the inner structure.

---

## 4. First-Time Pairing (6-Digit Numeric Comparison)

```
Android (Client)                                          Mac (Server)
      |                                                        |
      | 1. PAIR_INIT                                           |
      |------------------------------------------------------->|
      |    (deviceId, deviceName, clientPubKeyDER,             |
      |     clientNonceCommit = SHA256(clientNonce))           |
      |                                                        |
      | 2. PAIR_CHALLENGE                                      |
      |<-------------------------------------------------------|
      |    (serverId, serverName, serverPubKeyDER, serverNonce)|
      |                                                        |
      | 3. PAIR_REVEAL                                         |
      |------------------------------------------------------->|
      |    (clientNonce)                                       |
      |                                                        |
      | [Both compute ECDH shared secret Z & 6-digit code]     |
      | [Both prompt user: "Confirm 123 456?"]                 |
      | [User taps "Confirm" on Android & Mac]                 |
      |                                                        |
      | 4. PAIR_CONFIRM                                        |
      |------------------------------------------------------->|
      |    (clientHmac = HMAC(linkKey, "CLIENT_PAIR_CONFIRM"   |
      |                   + clientNonce + serverNonce))        |
      |                                                        |
      | 5. PAIR_COMPLETE                                       |
      |<-------------------------------------------------------|
      |    (serverHmac = HMAC(linkKey, "SERVER_PAIR_COMPLETE"  |
      |                   + serverNonce + clientNonce))        |
      |                                                        |
      | [Both save linkKey for automatic reconnect]            |
```

### 4.1 Step 1: `PAIR_INIT` (Android $\rightarrow$ Mac)
- Android generates an ephemeral `P-256` keypair $(sk_C, pk_C)$ and a 32-byte random `clientNonce`.
- Android computes `clientNonceCommit = SHA256(clientNonce)`.
- Android sends:
```json
{
  "type": "PAIR_INIT",
  "payload": "{\"deviceId\":\"<android-uuid>\",\"deviceName\":\"Pixel 8 Pro\",\"clientPubKeyDER\":\"<base64-x509-der>\",\"clientNonceCommit\":\"<base64-sha256>\"}"
}
```

### 4.2 Step 2: `PAIR_CHALLENGE` (Mac $\rightarrow$ Android)
- Mac generates an ephemeral `P-256` keypair $(sk_S, pk_S)$ and a 32-byte random `serverNonce`.
- Mac sends:
```json
{
  "type": "PAIR_CHALLENGE",
  "payload": "{\"serverId\":\"NoteNote-Mac\",\"serverName\":\"Pritesh’s MacBook Air\",\"serverPubKeyDER\":\"<base64-x509-der>\",\"serverNonce\":\"<base64-32bytes>\"}"
}
```

### 4.3 Step 3: `PAIR_REVEAL` (Android $\rightarrow$ Mac)
- Android reveals its `clientNonce`:
```json
{
  "type": "PAIR_REVEAL",
  "payload": "{\"clientNonce\":\"<base64-32bytes>\"}"
}
```
- Mac verifies `SHA256(clientNonce) == clientNonceCommit`. This commitment step strictly prevents a rogue MITM from grinding nonces to force a matching 6-digit code.

### 4.4 Step 4: 6-Digit Code Derivation & User Confirmation
Both sides compute the exact same transcript and 6-digit code:
```
transcript = "NoteNote-Pair-v1".utf8Bytes
           + clientPubKeyDER.rawBytes
           + serverPubKeyDER.rawBytes
           + clientNonce.rawBytes
           + serverNonce.rawBytes

digest = SHA256(transcript)
fourBytesBE = (digest[0] << 24) | (digest[1] << 16) | (digest[2] << 8) | digest[3]
sixDigitCode = String.format("%06d", (fourBytesBE.toLong() and 0xFFFFFFFFL) % 1000000)
```
- Both devices display `sixDigitCode` (e.g. `482 910`).
- The user confirms that the numbers match on both screens.

### 4.5 Key Derivation (`linkKey` and `sessionKey`)
Both sides compute:
1. `sharedSecret Z = ECDH(sk, pk_peer)`
2. `linkKey = HKDF-SHA256(ikm: Z, salt: clientNonce + serverNonce, info: "NoteNote-LinkKey-v1".utf8Bytes, length: 32)`
3. `sessionKey = HKDF-SHA256(ikm: Z, salt: linkKey, info: "NoteNote-SessionKey-v1".utf8Bytes + clientNonce + serverNonce, length: 32)`

### 4.6 Step 5: `PAIR_CONFIRM` (Android $\rightarrow$ Mac)
When the user taps Confirm on Android:
- Android computes:
  ```
  clientHmac = HMAC-SHA256(key: linkKey, data: "CLIENT_PAIR_CONFIRM".utf8Bytes + clientNonce + serverNonce)
  ```
- Android sends:
```json
{
  "type": "PAIR_CONFIRM",
  "payload": "{\"clientHmac\":\"<base64-32bytes>\"}"
}
```

### 4.7 Step 6: `PAIR_COMPLETE` (Mac $\rightarrow$ Android)
When the user confirms on Mac and Mac verifies `clientHmac`:
- Mac computes:
  ```
  serverHmac = HMAC-SHA256(key: linkKey, data: "SERVER_PAIR_COMPLETE".utf8Bytes + serverNonce + clientNonce)
  ```
- Mac sends:
```json
{
  "type": "PAIR_COMPLETE",
  "payload": "{\"serverHmac\":\"<base64-32bytes>\",\"status\":\"OK\"}"
}
```
- Android verifies `serverHmac`.
- Android securely saves `linkKey` and `deviceId` (e.g., using Android's `EncryptedSharedPreferences`).
- The connection is now authenticated. Subsequent frames are encrypted with `sessionKey`.

---

## 5. Subsequent Wi-Fi Reconnect (Passwordless Session)

When reconnecting to the Mac on the same Wi-Fi, the 6-digit prompt is **skipped**:

```
Android (Client)                                          Mac (Server)
      |                                                        |
      | 1. SESSION_INIT                                        |
      |------------------------------------------------------->|
      |    (deviceId, clientPubKeyDER, clientNonce)            |
      |                                                        |
      | 2. SESSION_CHALLENGE                                   |
      |<-------------------------------------------------------|
      |    (serverId, serverPubKeyDER, serverNonce)            |
      |                                                        |
      | [Both compute ECDH shared secret Z]                    |
      | [Both derive sessionKey using stored linkKey]          |
      |                                                        |
      | 3. SESSION_AUTH                                        |
      |------------------------------------------------------->|
      |    (clientHmac = HMAC(sessionKey,                      |
      |         "CLIENT_SESSION_AUTH" + clientNonce + sNonce)) |
      |                                                        |
      | 4. SESSION_OK                                          |
      |<-------------------------------------------------------|
      |    (serverHmac = HMAC(sessionKey,                      |
      |         "SERVER_SESSION_OK" + sNonce + clientNonce))   |
      |                                                        |
      | [Connection is authenticated; start encrypted sync]    |
```

### 5.1 `SESSION_INIT`
```json
{
  "type": "SESSION_INIT",
  "payload": "{\"deviceId\":\"<android-uuid>\",\"clientPubKeyDER\":\"<base64-x509-der>\",\"clientNonce\":\"<base64-32bytes>\"}"
}
```

### 5.2 `SESSION_CHALLENGE`
```json
{
  "type": "SESSION_CHALLENGE",
  "payload": "{\"serverId\":\"NoteNote-Mac\",\"serverPubKeyDER\":\"<base64-x509-der>\",\"serverNonce\":\"<base64-32bytes>\"}"
}
```

### 5.3 Session Key Derivation
Both sides compute:
1. `sharedSecret Z = ECDH(sk, pk_peer)`
2. `sessionKey = HKDF-SHA256(ikm: Z, salt: linkKey, info: "NoteNote-SessionKey-v1".utf8Bytes + clientNonce + serverNonce, length: 32)`

### 5.4 `SESSION_AUTH`
- `clientHmac = HMAC-SHA256(sessionKey, "CLIENT_SESSION_AUTH".utf8Bytes + clientNonce + serverNonce)`
```json
{
  "type": "SESSION_AUTH",
  "payload": "{\"clientHmac\":\"<base64-32bytes>\"}"
}
```

### 5.5 `SESSION_OK`
- `serverHmac = HMAC-SHA256(sessionKey, "SERVER_SESSION_OK".utf8Bytes + serverNonce + clientNonce)`
```json
{
  "type": "SESSION_OK",
  "payload": "{\"serverHmac\":\"<base64-32bytes>\",\"status\":\"OK\"}"
}
```

---

## 6. Encrypted Application Messages (`ENCRYPTED`)

Once authenticated, both sides maintain monotonic 64-bit sequence counters:
- `outSeq`: starts at `1`, increments by `1` with every encrypted frame sent.
- `inSeq`: starts at `1`, increments by `1` with every encrypted frame received. Replayed or out-of-order frames are rejected.

### Encryption Details:
- **Algorithm**: `AES/GCM/NoPadding` (256-bit key).
- **IV / Nonce**: 12 random bytes generated per frame.
- **AAD (Additional Authenticated Data)**:
  - From Android to Mac: `"C2S:<seq>"`.
  - From Mac to Android: `"S2C:<seq>"`.
- **Ciphertext**: In standard Java/Android, `cipher.doFinal()` appends the 16-byte authentication tag to the end of the ciphertext (`ciphertext + tag`), which matches macOS `CryptoKit` byte-for-byte.

### Encrypted Wire Frame:
```json
{
  "type": "ENCRYPTED",
  "payload": "{\"seq\":1,\"iv\":\"<base64-12bytes>\",\"ciphertext\":\"<base64-ciphertext-with-tag>\"}"
}
```

---

## 7. Sync Payloads & Actions

The decrypted plaintext is UTF-8 JSON.

### 7.1 Data Model (`SyncNoteDTO`)
```json
{
  "id": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
  "title": "Shopping List 🛒",
  "content": "- [x] Milk\n- [ ] Coffee\n- [ ] Apples",
  "color": "yellow",
  "isPinned": false,
  "isLocked": false,
  "createdAt": "2026-10-19T10:00:00Z",
  "updatedAt": "2026-10-19T10:30:00Z",
  "deletedAt": null
}
```
Supported `color` values: `"yellow"`, `"blue"`, `"green"`, `"pink"`, `"purple"`, `"orange"`, `"charcoal"`.

### 7.2 Android Pushing Notes to Mac (`PUSH_NOTES`)
**Request (decrypted)**:
```json
{
  "action": "PUSH_NOTES",
  "notes": [
    {
      "id": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
      "title": "Meeting Notes",
      "content": "Discussed roadmap items.",
      "color": "blue",
      "isPinned": true,
      "isLocked": false,
      "createdAt": "2026-10-19T09:00:00Z",
      "updatedAt": "2026-10-19T09:15:00Z"
    }
  ]
}
```

**Response from Mac (decrypted)**:
```json
{
  "status": "OK",
  "action": "PUSH_NOTES",
  "upsertedCount": 1,
  "serverTime": "2026-10-19T10:31:00Z"
}
```
On Mac, these notes appear in the **Phone Sync** tab of the Notes Dashboard, with a button for the Mac user to pop any note out onto their desktop as a floating sticky.

### 7.3 Android Requesting Notes from Mac (`PULL_NOTES`)
**Request (decrypted)**:
```json
{
  "action": "PULL_NOTES",
  "since": "2026-10-19T00:00:00Z"
}
```
*(Optionally omit `"since"` to pull all notes).*

**Response from Mac (decrypted)**:
```json
{
  "status": "OK",
  "action": "PULL_NOTES",
  "notes": [ ... ],
  "serverTime": "2026-10-19T10:31:05Z"
}
```
The Mac returns all active non-locked desktop sticky notes and phone synced notes.

### 7.4 Bidirectional Sync (`SYNC_ALL`)
Pushes local Android changes and pulls Mac changes in one round-trip:
**Request (decrypted)**:
```json
{
  "action": "SYNC_ALL",
  "notes": [ ... ],
  "since": "2026-10-19T00:00:00Z"
}
```
**Response from Mac (decrypted)**:
```json
{
  "status": "OK",
  "action": "SYNC_ALL",
  "upsertedCount": 2,
  "notes": [ ... ],
  "serverTime": "2026-10-19T10:31:10Z"
}
```

---

## 8. Complete Drop-In Kotlin Cryptography Helper

Here is a tested, standalone Kotlin file implementing all cryptographic operations using standard Android `java.security` and `javax.crypto` with **zero external dependencies**:

```kotlin
package com.notenote.android.sync

import android.util.Base64
import java.nio.ByteBuffer
import java.security.*
import java.security.spec.ECGenParameterSpec
import java.security.spec.X509EncodedKeySpec
import javax.crypto.Cipher
import javax.crypto.KeyAgreement
import javax.crypto.Mac
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

object NoteNoteCrypto {
    private val secureRandom = SecureRandom()

    fun generateRandomBytes(count: Int = 32): ByteArray {
        val bytes = ByteArray(count)
        secureRandom.nextBytes(bytes)
        return bytes
    }

    fun sha256(data: ByteArray): ByteArray {
        return MessageDigest.getInstance("SHA-256").digest(data)
    }

    // 1. P-256 Ephemeral Key Pair Generation
    fun generateP256KeyPair(): KeyPair {
        val kpg = KeyPairGenerator.getInstance("EC")
        kpg.initialize(ECGenParameterSpec("secp256r1"), secureRandom)
        return kpg.generateKeyPair()
    }

    // 2. Import X.509 DER Public Key (matching Apple CryptoKit derRepresentation)
    fun importPublicKeyDER(derBytes: ByteArray): PublicKey {
        val keyFactory = KeyFactory.getInstance("EC")
        return keyFactory.generatePublic(X509EncodedKeySpec(derBytes))
    }

    // 3. ECDH Shared Secret
    fun computeSharedSecret(privateKey: PrivateKey, peerPublicKey: PublicKey): ByteArray {
        val ka = KeyAgreement.getInstance("ECDH")
        ka.init(privateKey)
        ka.doPhase(peerPublicKey, true)
        return ka.generateSecret()
    }

    // 4. 6-Digit Numeric Comparison Code
    fun computeSixDigitCode(
        clientPubKeyDER: ByteArray,
        serverPubKeyDER: ByteArray,
        clientNonce: ByteArray,
        serverNonce: ByteArray
    ): String {
        val prefix = "NoteNote-Pair-v1".toByteArray(Charsets.UTF_8)
        val transcript = prefix + clientPubKeyDER + serverPubKeyDER + clientNonce + serverNonce
        val digest = sha256(transcript)
        val num = ByteBuffer.wrap(digest, 0, 4).int.toLong() and 0xFFFFFFFFL
        val code = num % 1_000_000
        return String.format("%06d", code)
    }

    // 5. RFC 5869 HKDF-SHA256 Key Derivation
    fun hkdfSha256(ikm: ByteArray, salt: ByteArray, info: ByteArray, length: Int = 32): ByteArray {
        // Extract
        val mac = Mac.getInstance("HmacSHA256")
        val prk = if (salt.isEmpty()) {
            mac.init(SecretKeySpec(ByteArray(32), "HmacSHA256"))
            mac.doFinal(ikm)
        } else {
            mac.init(SecretKeySpec(salt, "HmacSHA256"))
            mac.doFinal(ikm)
        }

        // Expand
        mac.init(SecretKeySpec(prk, "HmacSHA256"))
        var t = ByteArray(0)
        val okm = ByteArray(length)
        var offset = 0
        var i = 1

        while (offset < length) {
            mac.update(t)
            mac.update(info)
            mac.update(i.toByte())
            t = mac.doFinal()
            val chunk = Math.min(t.size, length - offset)
            System.arraycopy(t, 0, okm, offset, chunk)
            offset += chunk
            i++
        }
        return okm
    }

    fun deriveLinkKey(sharedSecret: ByteArray, clientNonce: ByteArray, serverNonce: ByteArray): ByteArray {
        return hkdfSha256(
            ikm = sharedSecret,
            salt = clientNonce + serverNonce,
            info = "NoteNote-LinkKey-v1".toByteArray(Charsets.UTF_8),
            length = 32
        )
    }

    fun deriveSessionKey(sharedSecret: ByteArray, linkKey: ByteArray, clientNonce: ByteArray, serverNonce: ByteArray): ByteArray {
        val info = "NoteNote-SessionKey-v1".toByteArray(Charsets.UTF_8) + clientNonce + serverNonce
        return hkdfSha256(
            ikm = sharedSecret,
            salt = linkKey,
            info = info,
            length = 32
        )
    }

    // 6. HMAC-SHA256
    fun hmacSha256(key: ByteArray, message: ByteArray): ByteArray {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(key, "HmacSHA256"))
        return mac.doFinal(message)
    }

    // 7. AES-256-GCM with Directional Sequence AAD
    fun encryptAESGCM(key: ByteArray, plaintext: ByteArray, seq: Long, direction: String): Pair<ByteArray, ByteArray> {
        val iv = generateRandomBytes(12)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, iv))
        cipher.updateAAD("$direction:$seq".toByteArray(Charsets.UTF_8))
        val ciphertextWithTag = cipher.doFinal(plaintext)
        return Pair(iv, ciphertextWithTag)
    }

    fun decryptAESGCM(key: ByteArray, iv: ByteArray, ciphertextWithTag: ByteArray, seq: Long, direction: String): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, iv))
        cipher.updateAAD("$direction:$seq".toByteArray(Charsets.UTF_8))
        return cipher.doFinal(ciphertextWithTag)
    }

    // Base64 Helpers
    fun b64Encode(bytes: ByteArray): String = Base64.encodeToString(bytes, Base64.NO_WRAP)
    fun b64Decode(str: String): ByteArray = Base64.decode(str, Base64.DEFAULT)
}
```

---

## 9. Summary of Security Properties

1. **Local Link Isolation**: `NWParameters.acceptLocalOnly = true` on Mac blocks all non-local routed traffic.
2. **Forward Secrecy**: Every connection negotiates a fresh ephemeral `P-256` keypair $(sk, pk)$; compromising a past `sessionKey` does not compromise future sessions.
3. **Commitment Anti-MITM**: Committing to `SHA256(clientNonce)` in `PAIR_INIT` before `serverNonce` is revealed mathematically prevents an active attacker from grinding nonces to force a matching 6-digit code.
4. **Replay & Reflection Protection**: Every encrypted frame authenticates an explicit direction (`C2S:` or `S2C:`) and a strictly increasing sequence counter inside the GCM authentication tag.
5. **Fail-Closed Privacy**: Sticky notes protected by Touch ID (`isLocked == true`) are filtered out at the Mac store layer and are never transmitted over the network.
