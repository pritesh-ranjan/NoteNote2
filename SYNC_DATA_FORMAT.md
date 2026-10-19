# NoteNote Wi-Fi Sync Wire Format & Payload Specification

Crisp reference of the **exact JSON schemas**, encryption envelopes, and wire messages exchanged between **Android** and **NoteNote for Mac**.

---

## 1. Outer WebSocket Envelope

**Every message** across the WebSocket (both directions) MUST use this outer envelope:

```json
{
  "type": "<MESSAGE_TYPE>",
  "payload": "<ESCAPED_JSON_STRING>"
}
```

> ⚠️ **CRITICAL**: `payload` is an **escaped JSON string**, NOT a nested JSON object.
> - Correct: `"payload": "{\"action\":\"SYNC_ALL\"}"`
> - Incorrect: `"payload": {"action": "SYNC_ALL"}`

---

## 2. Handshake Phase (Cleartext Outer Frames)

### 2.1 First-Time Pairing Handshake

| Step | Sender | `type` | `payload` JSON Object (before escaping) |
|---|---|---|---|
| 1 | **Android** | `PAIR_INIT` | `{"deviceId": "UUID-string", "deviceName": "Pixel 8", "clientPubKeyDER": "<base64-der>", "clientNonceCommit": "<base64-sha256>"}` |
| 2 | **Mac** | `PAIR_CHALLENGE` | `{"serverId": "NoteNote-Mac", "serverName": "Pritesh’s MacBook Air", "serverPubKeyDER": "<base64-der>", "serverNonce": "<base64-32bytes>"}` |
| 3 | **Android** | `PAIR_REVEAL` | `{"clientNonce": "<base64-32bytes>"}` |
| — | *Both* | *Display Code* | Both display 6-digit code derived from transcript. User confirms on both screens. |
| 4 | **Android** | `PAIR_CONFIRM` | `{"clientHmac": "<base64-32bytes>"}` |
| 5 | **Mac** | `PAIR_COMPLETE` | `{"serverHmac": "<base64-32bytes>", "status": "OK"}` |

### 2.2 Reconnect Handshake (Trusted Session)

| Step | Sender | `type` | `payload` JSON Object (before escaping) |
|---|---|---|---|
| 1 | **Android** | `SESSION_INIT` | `{"deviceId": "UUID-string", "clientPubKeyDER": "<base64-der>", "clientNonce": "<base64-32bytes>"}` |
| 2 | **Mac** | `SESSION_CHALLENGE` | `{"serverId": "NoteNote-Mac", "serverPubKeyDER": "<base64-der>", "serverNonce": "<base64-32bytes>"}` |
| 3 | **Android** | `SESSION_AUTH` | `{"clientHmac": "<base64-32bytes>"}` |
| 4 | **Mac** | `SESSION_OK` | `{"serverHmac": "<base64-32bytes>", "status": "OK"}` |

---

## 3. Encrypted Envelope (`ENCRYPTED`)

Once authenticated, **all application messages** use type `"ENCRYPTED"`:

```json
{
  "type": "ENCRYPTED",
  "payload": "{\"seq\":1,\"iv\":\"<base64-12bytes>\",\"ciphertext\":\"<base64-ciphertext-with-tag>\"}"
}
```

### Encryption Parameters:
- **Cipher**: `AES/GCM/NoPadding` with 256-bit `sessionKey`.
- **IV**: 12 random bytes generated per frame.
- **Tag**: 16 bytes appended to ciphertext (standard in Java `Cipher.doFinal()`).
- **Additional Authenticated Data (AAD)**:
  - When **Android encrypts to Mac**: `AAD = "C2S:<seq>"`.
  - When **Mac encrypts to Android**: `AAD = "S2C:<seq>"`.
- **Sequence Counters**:
  - `seq`: Starts at `1` on first encrypted frame, increments monotonically by 1 per frame sent.

---

## 4. Application Payloads (Decrypted Plaintext)

### 4.1 `SyncNoteDTO` Note Object Schema

Every note in the `notes` array uses this schema:

```json
{
  "id": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
  "title": "Meeting Notes",
  "content": "- [x] Discuss architecture\n- [ ] Release companion app",
  "color": "yellow",
  "isPinned": false,
  "isLocked": false,
  "createdAt": "2026-10-19T10:00:00Z",
  "updatedAt": "2026-10-19T10:30:00Z",
  "deletedAt": null
}
```

#### Field Specifications:

| Field | Type | Expected Value / Format | Android Fallback Accepted by Mac |
|---|---|---|---|
| `id` | `String` | Canonical UUID string (e.g. `"A1B2C3D4-E5F6-7890-ABCD-EF1234567890"`) | Integer IDs or non-UUID strings are automatically mapped to deterministic UUIDs. |
| `title` | `String` | Note title string | Also accepts `name`, `header`. Defaults to `""`. |
| `content` | `String` | Note body (supports Markdown) | Also accepts `body`, `text`, `note`. Defaults to `""`. |
| `color` | `String` | `"yellow"`, `"blue"`, `"green"`, `"pink"`, `"purple"`, `"orange"`, `"charcoal"` | Defaults to `"yellow"`. |
| `isPinned` | `Boolean` | `true` or `false` | Also accepts `pinned`, integer (`0`/`1`). Defaults to `false`. |
| `isLocked` | `Boolean` | `true` (Touch ID protected) or `false` | Also accepts `locked`. Defaults to `false`. |
| `createdAt` | `String` | ISO-8601 UTC string (`"2026-10-19T10:00:00Z"`) | Also accepts Unix ms timestamp, Unix seconds, or local format. Defaults to now. |
| `updatedAt` | `String` | ISO-8601 UTC string (`"2026-10-19T10:30:00Z"`) | Same as above. Used for Last-Write-Wins comparison. |
| `deletedAt` | `String?` | ISO-8601 UTC string if soft-deleted, or `null` | Soft deletion marker. |

---

## 5. Messages Expected BY Mac (Android $\rightarrow$ Mac)

### 5.1 Push Notes (`PUSH_NOTES`)
Android sends local notes to Mac:

```json
{
  "action": "PUSH_NOTES",
  "notes": [
    {
      "id": "B01F346E-5C6D-4573-A3B9-216EE827365A",
      "title": "Grocery List",
      "content": "- Apples\n- Almond Milk\n- Sourdough Bread",
      "color": "green",
      "isPinned": false,
      "isLocked": false,
      "createdAt": "2026-10-19T12:00:00Z",
      "updatedAt": "2026-10-19T13:40:00Z",
      "deletedAt": null
    }
  ]
}
```

### 5.2 Pull Notes (`PULL_NOTES`)
Android requests notes from Mac:

```json
{
  "action": "PULL_NOTES",
  "since": "2026-10-19T00:00:00Z"
}
```
*(Optionally omit `"since"` to pull all active desktop notes).*

### 5.3 Bidirectional Sync (`SYNC_ALL`)
Android pushes its local notes and requests Mac notes in one round-trip:

```json
{
  "action": "SYNC_ALL",
  "notes": [ ... ],
  "since": "2026-10-19T00:00:00Z"
}
```

### 5.4 Keepalive Ping (`PING`)
```json
{
  "action": "PING"
}
```

---

## 6. Messages Sent BY Mac (Mac $\rightarrow$ Android)

### 6.1 Response to `PUSH_NOTES`
Mac confirms receipt of pushed notes:

```json
{
  "status": "OK",
  "action": "PUSH_NOTES",
  "upsertedCount": 1,
  "serverTime": "2026-10-19T14:15:00Z"
}
```

### 6.2 Response to `PULL_NOTES`
Mac returns all active, non-locked desktop sticky notes and synced notes:

```json
{
  "status": "OK",
  "action": "PULL_NOTES",
  "notes": [
    {
      "id": "76B7C3E1-263B-49E8-9993-B0530A29BF91",
      "title": "Project Roadmap",
      "content": "Desktop sticky content from Mac",
      "color": "yellow",
      "isPinned": true,
      "isLocked": false,
      "createdAt": "2026-10-19T09:00:00Z",
      "updatedAt": "2026-10-19T14:10:00Z",
      "deletedAt": null
    }
  ],
  "serverTime": "2026-10-19T14:15:05Z"
}
```

### 6.3 Response to `SYNC_ALL` (or Server "Sync Now" Trigger)
Mac returns upsert count of incoming notes AND returns Mac notes:

```json
{
  "status": "OK",
  "action": "SYNC_ALL",
  "upsertedCount": 2,
  "notes": [
    {
      "id": "76B7C3E1-263B-49E8-9993-B0530A29BF91",
      "title": "Project Roadmap",
      "content": "Desktop sticky content from Mac",
      "color": "yellow",
      "isPinned": true,
      "isLocked": false,
      "createdAt": "2026-10-19T09:00:00Z",
      "updatedAt": "2026-10-19T14:10:00Z",
      "deletedAt": null
    }
  ],
  "serverTime": "2026-10-19T14:15:10Z"
}
```

> **Note**: When the user clicks the **"Sync Now"** button on Mac, the Mac pushes this exact `SYNC_ALL` response to the connected Android device so the phone immediately receives all current Mac notes.

### 6.4 Response to `PING`
```json
{
  "status": "OK",
  "action": "PONG",
  "serverTime": "2026-10-19T14:15:12Z"
}
```

---

## 7. Android Implementation Verification Checklist

Ensure your Android code checks all 5 items:

1. **Outer WebSocket JSON**: Double-check that `ws.send(...)` sends `{"type":"ENCRYPTED","payload":"{...}"}` where `payload` is an escaped JSON string.
2. **AAD Matching**:
   - When **encrypting** outgoing messages to Mac, update AAD with `"C2S:<seq>"`.
   - When **decrypting** incoming responses from Mac, update AAD with `"S2C:<seq>"`.
3. **Sequence Counter**:
   - Start `outSeq = 1` for the first encrypted frame sent.
   - Start `inSeq = 1` for the first encrypted frame received.
   - Increment each counter by 1 on every frame.
4. **Dates in Notes**:
   - Send `updatedAt` and `createdAt` as ISO-8601 UTC string (e.g. `SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply { timeZone = TimeZone.getTimeZone("UTC") }.format(Date())`).
5. **Handling Server `SYNC_ALL`**:
   - In your WebSocket listener `onMessage`, when decrypted action is `SYNC_ALL`, extract `optJSONArray("notes")` and upsert into your local database.
