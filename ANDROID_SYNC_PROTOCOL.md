# NoteNote Wi-Fi Sync Protocol & Android Implementation Guide

Technical specification for implementing the companion Android sync client for **NoteNote for Mac**.

---

## 1. Protocol Architecture & Parameters

- **Transport**: Standard WebSocket (`ws://<mac-ip>:<port>`).
- **Default Port**: `52849` (TCP).
- **Service Discovery**: mDNS / DNS-SD (`_notenote-sync._tcp.`).
- **Key Agreement**: Ephemeral `P-256` (`secp256r1`) ECDH (DER / X.509 `SubjectPublicKeyInfo`).
- **Pairing Authentication**: 6-digit numeric comparison with anti-MITM nonce commitment.
- **Session Authentication**: Fast reconnect using stored 256-bit `linkKey`.
- **Payload Encryption**: `AES-256-GCM` (12-byte IV, 16-byte tag, 64-bit monotonic sequence counter as AAD).
- **Date Format**: ISO-8601 UTC string (`"yyyy-MM-dd'T'HH:mm:ss'Z'"`).

---

## 2. Android Prerequisites & Setup

### Permissions (`AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<!-- Required on Android OEMs to prevent multicast packet drop during mDNS discovery -->
<uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE" />
```

### Local Cleartext WebSocket (`res/xml/network_security_config.xml`)
```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="true" />
</network-security-config>
```

### Dependencies (`build.gradle.kts`)
```kotlin
implementation("com.squareup.okhttp3:okhttp:4.12.0")
implementation("androidx.security:security-crypto:1.1.0-alpha06")
```

---

## 3. Wire Framing

All WebSocket messages are UTF-8 JSON text frames with an outer envelope:
```json
{
  "type": "<MESSAGE_TYPE>",
  "payload": "<JSON string of inner payload>"
}
```
*Note: `payload` is an escaped JSON string.*

---

## 4. Cryptographic Formulas

```
1. Nonce Commitment:
   clientNonceCommit = SHA256(clientNonce)

2. Shared Secret:
   Z = ECDH(clientPrivKey, serverPubKey)

3. 6-Digit Verification Code:
   transcript = "NoteNote-Pair-v1".utf8Bytes + clientPubKeyDER + serverPubKeyDER + clientNonce + serverNonce
   digest = SHA256(transcript)
   code = ((digest[0]<<24) | (digest[1]<<16) | (digest[2]<<8) | digest[3]) % 1,000,000
   sixDigitCode = String.format("%06d", code)

4. Link Key (persisted for fast reconnect):
   linkKey = HKDF-SHA256(ikm: Z, salt: clientNonce + serverNonce, info: "NoteNote-LinkKey-v1", len: 32)

5. Session Key (per-connection encryption):
   sessionKey = HKDF-SHA256(ikm: Z, salt: linkKey, info: "NoteNote-SessionKey-v1" + clientNonce + serverNonce, len: 32)

6. Authentication HMACs:
   clientPairHmac    = HMAC-SHA256(linkKey,    "CLIENT_PAIR_CONFIRM" + clientNonce + serverNonce)
   serverPairHmac    = HMAC-SHA256(linkKey,    "SERVER_PAIR_COMPLETE" + serverNonce + clientNonce)
   clientSessionHmac = HMAC-SHA256(sessionKey, "CLIENT_SESSION_AUTH" + clientNonce + serverNonce)
   serverSessionHmac = HMAC-SHA256(sessionKey, "SERVER_SESSION_OK" + serverNonce + clientNonce)

7. Frame Encryption (AES-256-GCM):
   IV        = 12 random bytes
   AAD       = "C2S:<seq>" (Client to Mac) | "S2C:<seq>" (Mac to Client)
   Ciphertext = AES-GCM(key: sessionKey, iv: IV, aad: AAD, plaintext: data) // includes 16-byte tag
```

---

## 5. Handshake Sequences

### 5.1 First-Time Pairing (Numeric Comparison)

```
Android (Client)                                                  Mac (Server)
      │                                                                │
      │ 1. PAIR_INIT                                                   │
      ├───────────────────────────────────────────────────────────────>│
      │    {"deviceId": "...", "deviceName": "Pixel 8",                │
      │     "clientPubKeyDER": "<b64>", "clientNonceCommit": "<b64>"}  │
      │                                                                │
      │ 2. PAIR_CHALLENGE                                              │
      │<───────────────────────────────────────────────────────────────┤
      │    {"serverId": "NoteNote-Mac", "serverName": "MacBook",       │
      │     "serverPubKeyDER": "<b64>", "serverNonce": "<b64>"}        │
      │                                                                │
      │ 3. PAIR_REVEAL                                                 │
      ├───────────────────────────────────────────────────────────────>│
      │    {"clientNonce": "<b64>"}                                    │
      │                                                                │
      │ [Both derive 6-digit code. Prompt user to confirm on both]     │
      │                                                                │
      │ 4. PAIR_CONFIRM (after user tap)                               │
      ├───────────────────────────────────────────────────────────────>│
      │    {"clientHmac": "<b64>"}                                     │
      │                                                                │
      │ 5. PAIR_COMPLETE                                               │
      │<───────────────────────────────────────────────────────────────┤
      │    {"serverHmac": "<b64>", "status": "OK"}                     │
      │                                                                │
      │ [Both persist linkKey; initialize seq: outSeq=1, inSeq=1]      │
```

### 5.2 Subsequent Reconnect (Passwordless)

```
Android (Client)                                                  Mac (Server)
      │                                                                │
      │ 1. SESSION_INIT                                                │
      ├───────────────────────────────────────────────────────────────>│
      │    {"deviceId": "...", "clientPubKeyDER": "<b64>",             │
      │     "clientNonce": "<b64>"}                                    │
      │                                                                │
      │ 2. SESSION_CHALLENGE                                           │
      │<───────────────────────────────────────────────────────────────┤
      │    {"serverId": "...", "serverPubKeyDER": "<b64>",             │
      │     "serverNonce": "<b64>"}                                    │
      │                                                                │
      │ [Both derive sessionKey via stored linkKey]                    │
      │                                                                │
      │ 3. SESSION_AUTH                                                │
      ├───────────────────────────────────────────────────────────────>│
      │    {"clientHmac": "<b64>"}                                     │
      │                                                                │
      │ 4. SESSION_OK                                                  │
      │<───────────────────────────────────────────────────────────────┤
      │    {"serverHmac": "<b64>", "status": "OK"}                     │
      │                                                                │
      │ [Authenticated; outSeq=1, inSeq=1; ready for ENCRYPTED frames] │
```

---

## 6. Encrypted Application Messages

Envelope type: `"ENCRYPTED"`:
```json
{
  "type": "ENCRYPTED",
  "payload": "{\"seq\":1,\"iv\":\"<b64-12B>\",\"ciphertext\":\"<b64-ciphertext-with-tag>\"}"
}
```

- `outSeq` increments by 1 with each sent frame.
- `inSeq` increments by 1 with each received frame (reject if `seq != inSeq`).

### 6.1 `SyncNoteDTO` Data Model
```json
{
  "id": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
  "title": "Shopping List",
  "content": "- [x] Coffee\n- [ ] Milk",
  "color": "yellow",
  "isPinned": false,
  "isLocked": false,
  "createdAt": "2026-10-19T10:00:00Z",
  "updatedAt": "2026-10-19T10:30:00Z",
  "deletedAt": null
}
```
*Colors: `"yellow"`, `"blue"`, `"green"`, `"pink"`, `"purple"`, `"orange"`, `"charcoal"`.*

### 6.2 Application Actions (Decrypted Plaintext)

- **Push Notes (Android $\rightarrow$ Mac)**:
  `{"action": "PUSH_NOTES", "notes": [ ... ]}`
  Response: `{"status": "OK", "action": "PUSH_NOTES", "upsertedCount": 1, "serverTime": "..."}`
  *(Notes appear in the Mac's "Phone Sync" dashboard tab).*

- **Pull Notes (Android $\leftarrow$ Mac)**:
  `{"action": "PULL_NOTES", "since": "2026-10-19T00:00:00Z"}`
  Response: `{"status": "OK", "action": "PULL_NOTES", "notes": [ ... ], "serverTime": "..."}`

- **Full Sync (Bidirectional)**:
  `{"action": "SYNC_ALL", "notes": [ ... ], "since": "2026-10-19T00:00:00Z"}`
  Response: `{"status": "OK", "action": "SYNC_ALL", "upsertedCount": 1, "notes": [ ... ], "serverTime": "..."}`

- **Conflict Resolution**: Last-Write-Wins based on `updatedAt`. If `deletedAt != null`, mark as deleted.

---

## 7. Reference Implementation (Kotlin)

### 7.1 `NoteNoteCrypto.kt`
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
    private val random = SecureRandom()

    fun randomBytes(n: Int = 32) = ByteArray(n).also { random.nextBytes(it) }
    fun sha256(b: ByteArray): ByteArray = MessageDigest.getInstance("SHA-256").digest(b)

    fun generateP256KeyPair(): KeyPair = KeyPairGenerator.getInstance("EC").run {
        initialize(ECGenParameterSpec("secp256r1"), random)
        generateKeyPair()
    }

    fun importPublicKeyDER(der: ByteArray): PublicKey =
        KeyFactory.getInstance("EC").generatePublic(X509EncodedKeySpec(der))

    fun computeSharedSecret(priv: PrivateKey, peerPub: PublicKey): ByteArray =
        KeyAgreement.getInstance("ECDH").run {
            init(priv); doPhase(peerPub, true); generateSecret()
        }

    fun computeSixDigitCode(pkC: ByteArray, pkS: ByteArray, nonceC: ByteArray, nonceS: ByteArray): String {
        val transcript = "NoteNote-Pair-v1".toByteArray() + pkC + pkS + nonceC + nonceS
        val digest = sha256(transcript)
        val num = ByteBuffer.wrap(digest, 0, 4).int.toLong() and 0xFFFFFFFFL
        return String.format("%06d", num % 1_000_000)
    }

    fun hkdfSha256(ikm: ByteArray, salt: ByteArray, info: ByteArray, len: Int = 32): ByteArray {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(if (salt.isEmpty()) ByteArray(32) else salt, "HmacSHA256"))
        val prk = mac.doFinal(ikm)
        mac.init(SecretKeySpec(prk, "HmacSHA256"))
        var t = ByteArray(0); val okm = ByteArray(len); var offset = 0; var i = 1
        while (offset < len) {
            mac.update(t); mac.update(info); mac.update(i.toByte())
            t = mac.doFinal()
            val chunk = Math.min(t.size, len - offset)
            System.arraycopy(t, 0, okm, offset, chunk)
            offset += chunk; i++
        }
        return okm
    }

    fun deriveLinkKey(secret: ByteArray, cNonce: ByteArray, sNonce: ByteArray): ByteArray =
        hkdfSha256(secret, cNonce + sNonce, "NoteNote-LinkKey-v1".toByteArray(), 32)

    fun deriveSessionKey(secret: ByteArray, linkKey: ByteArray, cNonce: ByteArray, sNonce: ByteArray): ByteArray =
        hkdfSha256(secret, linkKey, "NoteNote-SessionKey-v1".toByteArray() + cNonce + sNonce, 32)

    fun hmacSha256(key: ByteArray, data: ByteArray): ByteArray =
        Mac.getInstance("HmacSHA256").run {
            init(SecretKeySpec(key, "HmacSHA256"))
            doFinal(data)
        }

    fun encryptAESGCM(key: ByteArray, plaintext: ByteArray, seq: Long, dir: String): Pair<ByteArray, ByteArray> {
        val iv = randomBytes(12)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, iv))
        cipher.updateAAD("$dir:$seq".toByteArray())
        return Pair(iv, cipher.doFinal(plaintext))
    }

    fun decryptAESGCM(key: ByteArray, iv: ByteArray, ciphertext: ByteArray, seq: Long, dir: String): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, iv))
        cipher.updateAAD("$dir:$seq".toByteArray())
        return cipher.doFinal(ciphertext)
    }

    fun b64(b: ByteArray): String = Base64.encodeToString(b, Base64.NO_WRAP)
    fun unb64(s: String): ByteArray = Base64.decode(s, Base64.DEFAULT)
}
```

### 7.2 `NsdDiscoveryHelper.kt`
```kotlin
package com.notenote.android.sync

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.net.wifi.WifiManager

class NsdDiscoveryHelper(context: Context, private val onServerFound: (host: String, port: Int, name: String) -> Unit) {
    private val nsd = context.getSystemService(Context.NSD_SERVICE) as NsdManager
    private val wifi = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
    private var lock: WifiManager.MulticastLock? = null

    private val listener = object : NsdManager.DiscoveryListener {
        override fun onDiscoveryStarted(reg: String) {}
        override fun onServiceFound(s: NsdServiceInfo) {
            if (s.serviceType.contains("_notenote-sync")) {
                nsd.resolveService(s, object : NsdManager.ResolveListener {
                    override fun onServiceResolved(res: NsdServiceInfo) {
                        res.host?.hostAddress?.let { onServerFound(it, res.port, res.serviceName) }
                    }
                    override fun onResolveFailed(s: NsdServiceInfo, code: Int) {}
                })
            }
        }
        override fun onServiceLost(s: NsdServiceInfo) {}
        override fun onDiscoveryStopped(s: String) {}
        override fun onStartDiscoveryFailed(s: String, c: Int) { stop() }
        override fun onStopDiscoveryFailed(s: String, c: Int) {}
    }

    fun start() {
        lock = wifi.createMulticastLock("NoteNoteLock").apply { setReferenceCounted(true); acquire() }
        nsd.discoverServices("_notenote-sync._tcp.", NsdManager.PROTOCOL_DNS_SD, listener)
    }

    fun stop() {
        try { nsd.stopServiceDiscovery(listener) } catch (_: Exception) {}
        lock?.let { if (it.isHeld) it.release() }
        lock = null
    }
}
```

### 7.3 `NoteNoteSyncClient.kt`
```kotlin
package com.notenote.android.sync

import android.os.Build
import okhttp3.*
import org.json.JSONArray
import org.json.JSONObject
import java.security.KeyPair
import java.security.PublicKey

class NoteNoteSyncClient(
    private val deviceId: String,
    private val getStoredLinkKey: (serverId: String) -> String?,
    private val saveLinkKey: (serverId: String, linkKeyB64: String) -> Unit,
    private val promptUserConfirm: (code: String, macName: String, onConfirm: () -> Unit) -> Unit,
    private val onNotesReceived: (List<JSONObject>) -> Unit
) {
    private val client = OkHttpClient()
    private var ws: WebSocket? = null
    private var kp: KeyPair? = null
    private var clientNonce: ByteArray? = null
    private var serverPub: PublicKey? = null
    private var serverNonce: ByteArray? = null
    private var serverId = "NoteNote-Mac"
    private var serverName = "Mac"
    private var linkKey: ByteArray? = null
    private var sessionKey: ByteArray? = null
    private var outSeq: Long = 1
    private var inSeq: Long = 1

    fun connect(host: String, port: Int = 52849) {
        val req = Request.Builder().url("ws://$host:$port").build()
        ws = client.newWebSocket(req, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                val stored = getStoredLinkKey(serverId)
                if (stored != null) startSession(webSocket, NoteNoteCrypto.unb64(stored))
                else startPairing(webSocket)
            }
            override fun onMessage(webSocket: WebSocket, text: String) = handleWire(webSocket, text)
        })
    }

    private fun startPairing(ws: WebSocket) {
        kp = NoteNoteCrypto.generateP256KeyPair()
        clientNonce = NoteNoteCrypto.randomBytes(32)
        val commit = NoteNoteCrypto.sha256(clientNonce!!)
        send(ws, "PAIR_INIT", JSONObject().apply {
            put("deviceId", deviceId)
            put("deviceName", "${Build.MANUFACTURER} ${Build.MODEL}")
            put("clientPubKeyDER", NoteNoteCrypto.b64(kp!!.public.encoded))
            put("clientNonceCommit", NoteNoteCrypto.b64(commit))
        })
    }

    private fun startSession(ws: WebSocket, storedKey: ByteArray) {
        linkKey = storedKey
        kp = NoteNoteCrypto.generateP256KeyPair()
        clientNonce = NoteNoteCrypto.randomBytes(32)
        send(ws, "SESSION_INIT", JSONObject().apply {
            put("deviceId", deviceId)
            put("clientPubKeyDER", NoteNoteCrypto.b64(kp!!.public.encoded))
            put("clientNonce", NoteNoteCrypto.b64(clientNonce!!))
        })
    }

    private fun handleWire(ws: WebSocket, json: String) {
        val wire = JSONObject(json)
        val type = wire.getString("type")
        val payload = JSONObject(wire.getString("payload"))

        when (type) {
            "PAIR_CHALLENGE" -> {
                serverId = payload.getString("serverId")
                serverName = payload.getString("serverName")
                serverPub = NoteNoteCrypto.importPublicKeyDER(NoteNoteCrypto.unb64(payload.getString("serverPubKeyDER")))
                serverNonce = NoteNoteCrypto.unb64(payload.getString("serverNonce"))

                send(ws, "PAIR_REVEAL", JSONObject().put("clientNonce", NoteNoteCrypto.b64(clientNonce!!)))

                val code = NoteNoteCrypto.computeSixDigitCode(kp!!.public.encoded, serverPub!!.encoded, clientNonce!!, serverNonce!!)
                val z = NoteNoteCrypto.computeSharedSecret(kp!!.private, serverPub!!)
                linkKey = NoteNoteCrypto.deriveLinkKey(z, clientNonce!!, serverNonce!!)
                sessionKey = NoteNoteCrypto.deriveSessionKey(z, linkKey!!, clientNonce!!, serverNonce!!)

                promptUserConfirm(code, serverName) {
                    val hmac = NoteNoteCrypto.hmacSha256(linkKey!!, "CLIENT_PAIR_CONFIRM".toByteArray() + clientNonce!! + serverNonce!!)
                    send(ws, "PAIR_CONFIRM", JSONObject().put("clientHmac", NoteNoteCrypto.b64(hmac)))
                }
            }
            "PAIR_COMPLETE" -> {
                saveLinkKey(serverId, NoteNoteCrypto.b64(linkKey!!))
                outSeq = 1; inSeq = 1
            }
            "SESSION_CHALLENGE" -> {
                serverPub = NoteNoteCrypto.importPublicKeyDER(NoteNoteCrypto.unb64(payload.getString("serverPubKeyDER")))
                serverNonce = NoteNoteCrypto.unb64(payload.getString("serverNonce"))
                val z = NoteNoteCrypto.computeSharedSecret(kp!!.private, serverPub!!)
                sessionKey = NoteNoteCrypto.deriveSessionKey(z, linkKey!!, clientNonce!!, serverNonce!!)
                val hmac = NoteNoteCrypto.hmacSha256(sessionKey!!, "CLIENT_SESSION_AUTH".toByteArray() + clientNonce!! + serverNonce!!)
                send(ws, "SESSION_AUTH", JSONObject().put("clientHmac", NoteNoteCrypto.b64(hmac)))
            }
            "SESSION_OK" -> {
                outSeq = 1; inSeq = 1
            }
            "ENCRYPTED" -> {
                val seq = payload.getLong("seq")
                if (seq != inSeq++) return
                val iv = NoteNoteCrypto.unb64(payload.getString("iv"))
                val ct = NoteNoteCrypto.unb64(payload.getString("ciphertext"))
                val plain = NoteNoteCrypto.decryptAESGCM(sessionKey!!, iv, ct, seq, "S2C")
                val res = JSONObject(String(plain))
                res.optJSONArray("notes")?.let { arr ->
                    onNotesReceived(List(arr.length()) { arr.getJSONObject(it) })
                }
            }
        }
    }

    fun syncAll(notes: List<JSONObject>, since: String? = null) {
        val req = JSONObject().apply {
            put("action", "SYNC_ALL")
            put("notes", JSONArray(notes))
            if (since != null) put("since", since)
        }
        sendEncrypted(req)
    }

    private fun sendEncrypted(json: JSONObject) {
        val currentSeq = outSeq++
        val (iv, ct) = NoteNoteCrypto.encryptAESGCM(sessionKey!!, json.toString().toByteArray(), currentSeq, "C2S")
        send(ws!!, "ENCRYPTED", JSONObject().apply {
            put("seq", currentSeq)
            put("iv", NoteNoteCrypto.b64(iv))
            put("ciphertext", NoteNoteCrypto.b64(ct))
        })
    }

    private fun send(ws: WebSocket, type: String, payload: JSONObject) {
        ws.send(JSONObject().put("type", type).put("payload", payload.toString()).toString())
    }
}
```

---

## 8. Verification Workflow

1. **Mac**: Open **Preferences** $\rightarrow$ **General** $\rightarrow$ toggle **Enable Local Wi-Fi Sync** to **ON**. Note port (default `52849`).
2. **Android**: Start discovery. `NsdDiscoveryHelper` discovers `_notenote-sync._tcp.`.
3. **Connect & Pair**: Connect to Mac. Both screens display the identical 6-digit confirmation code. Tap "Confirm" on both.
4. **Sync**:
   - Pushing notes to Mac shows them in the Dashboard **Phone Sync** tab (with option to "Open as Sticky").
   - Pulling notes loads non-locked Mac desktop notes to Android.
   - Subsequent reconnects bypass the 6-digit prompt using the saved `linkKey`.
