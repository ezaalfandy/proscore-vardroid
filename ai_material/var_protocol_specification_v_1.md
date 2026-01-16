# VAR Protocol Specification v1.0

> **Project:** Pencak Silat VAR
>
> **Scope:** Communication protocol between Flutter Android Camera Nodes and Flutter Windows Coordinator
>
> **Transport:** WebSocket (JSON) + HTTP (LAN)
>
> **Mode:** Local / Offline (LAN-first)

---

## 1. Protocol Goals

The VAR protocol is designed to:

- Provide **reliable local communication** between cameras and coordinator
- Support **real-time control**, status reporting, and acknowledgements
- Enable **incident marking** and **fast clip extraction**
- Remain **simple, debuggable, and versioned**

Non-goals:
- Internet routing
- Cloud signaling
- End-to-end encryption (LAN-level security only for v1)

---

## 2. Transport Layers

### 2.1 WebSocket (Primary)

Used for:
- Pairing handshake
- Command & control
- Status updates
- Event acknowledgements

Characteristics:
- Persistent connection
- JSON messages
- Bidirectional

### 2.2 HTTP (Secondary – LAN)

Used for:
- Clip file download
- Optional health checks

Characteristics:
- Stateless
- Large binary transfer

---

## 3. General Message Format

All WebSocket messages **MUST** follow this base structure:

```json
{
  "type": "string",
  "protoVersion": "1.0",
  "deviceId": "string",
  "sessionId": "string | null",
  "payload": {}
}
```

### Required Fields
- `type` – Message type identifier
- `protoVersion` – Protocol version (e.g. `"1.0"`)
- `deviceId` – Unique device identifier
- `payload` – Message-specific content

### Optional Fields
- `sessionId` – Required only when a recording session is active

---

## 4. Connection Lifecycle

### 4.1 Initial Connection

1. Camera connects to Coordinator WebSocket endpoint
2. Camera sends `hello`
3. Coordinator validates pairing state
4. Pairing handshake begins (if required)

---

### 4.2 Hello Message

**Device → Coordinator**

```json
{
  "type": "hello",
  "protoVersion": "1.0",
  "deviceId": "android-uuid",
  "payload": {
    "deviceName": "Samsung A34",
    "platform": "android",
    "appVersion": "0.1.0",
    "capabilities": {
      "maxResolution": "4K",
      "maxFps": 60,
      "segmentRecording": true
    }
  }
}
```

---

## 5. Pairing Protocol

### 5.1 Pair Request

**Device → Coordinator**

Sent when device is not yet trusted.

```json
{
  "type": "pair_request",
  "protoVersion": "1.0",
  "deviceId": "android-uuid",
  "payload": {
    "pairToken": "ABCD12",
    "deviceName": "Cam Phone"
  }
}
```

---

### 5.2 Pair Accept

**Coordinator → Device**

```json
{
  "type": "pair_accept",
  "protoVersion": "1.0",
  "deviceId": "android-uuid",
  "payload": {
    "deviceKey": "persistent-secret",
    "assignedName": "Cam1"
  }
}
```

The device **MUST persist** `deviceKey` securely and reuse it on reconnect.

---

### 5.3 Pair Reject

```json
{
  "type": "pair_reject",
  "protoVersion": "1.0",
  "deviceId": "android-uuid",
  "payload": {
    "reason": "pairing_disabled | invalid_token | expired"
  }
}
```

---

## 6. Authentication on Reconnect

On reconnect, device sends:

```json
{
  "type": "auth",
  "protoVersion": "1.0",
  "deviceId": "android-uuid",
  "payload": {
    "deviceKey": "persistent-secret"
  }
}
```

Coordinator replies with:
- `auth_ok`
- or `auth_failed`

---

## 7. Status Reporting

### 7.1 Status Update

**Device → Coordinator** (periodic, e.g. every 2s)

```json
{
  "type": "status",
  "protoVersion": "1.0",
  "deviceId": "android-uuid",
  "sessionId": "session-001",
  "payload": {
    "battery": 82,
    "temperature": 41.5,
    "freeSpaceMB": 12400,
    "isRecording": true,
    "signalStrength": -55
  }
}
```

---

## 8. Recording Control

### 8.1 Start Recording

**Coordinator → Device**

```json
{
  "type": "start_record",
  "protoVersion": "1.0",
  "deviceId": "android-uuid",
  "payload": {
    "sessionId": "session-001",
    "profile": {
      "resolution": "1080p",
      "fps": 30,
      "bitrate": 12000000
    },
    "meta": {
      "eventId": "EVT01",
      "matchId": "MCH12"
    }
  }
}
```

---

### 8.2 Recording Started ACK

```json
{
  "type": "recording_started",
  "protoVersion": "1.0",
  "deviceId": "android-uuid",
  "sessionId": "session-001",
  "payload": {
    "startedAt": 1690000000000
  }
}
```

---

### 8.3 Stop Recording

**Coordinator → Device**

```json
{
  "type": "stop_record",
  "protoVersion": "1.0",
  "deviceId": "android-uuid",
  "payload": {}
}
```

---

## 9. Mark (Incident) Protocol

### 9.1 Create Mark

**Coordinator → Device**

```json
{
  "type": "mark",
  "protoVersion": "1.0",
  "deviceId": "android-uuid",
  "sessionId": "session-001",
  "payload": {
    "markId": "MARK-00012",
    "coordinatorTs": 1690000123456,
    "note": "Possible fall"
  }
}
```

---

### 9.2 Mark Acknowledgement

**Device → Coordinator**

```json
{
  "type": "mark_ack",
  "protoVersion": "1.0",
  "deviceId": "android-uuid",
  "sessionId": "session-001",
  "payload": {
    "markId": "MARK-00012",
    "deviceTs": 1690000123460
  }
}
```

---

## 10. Clip Export Protocol

### 10.1 Request Clip

**Coordinator → Device**

```json
{
  "type": "request_clip",
  "protoVersion": "1.0",
  "deviceId": "android-uuid",
  "sessionId": "session-001",
  "payload": {
    "markId": "MARK-00012",
    "fromMs": -10000,
    "toMs": 5000,
    "quality": "preview"
  }
}
```

---

### 10.2 Clip Ready

**Device → Coordinator**

```json
{
  "type": "clip_ready",
  "protoVersion": "1.0",
  "deviceId": "android-uuid",
  "payload": {
    "clipId": "CLIP-8891",
    "markId": "MARK-00012",
    "url": "http://192.168.1.23:9000/clips/CLIP-8891.mp4",
    "durationMs": 15000,
    "sizeBytes": 32450000
  }
}
```

Coordinator downloads clip via HTTP.

---

## 11. Time Sync Protocol (MVP)

### 11.1 Ping

**Coordinator → Device**

```json
{
  "type": "ping",
  "protoVersion": "1.0",
  "deviceId": "android-uuid",
  "payload": {
    "coordinatorTs": 1690000200000
  }
}
```

### 11.2 Pong

**Device → Coordinator**

```json
{
  "type": "pong",
  "protoVersion": "1.0",
  "deviceId": "android-uuid",
  "payload": {
    "deviceTs": 1690000200003
  }
}
```

---

## 12. Error & Control Messages

### 12.1 Error

```json
{
  "type": "error",
  "protoVersion": "1.0",
  "deviceId": "android-uuid",
  "payload": {
    "code": "LOW_STORAGE",
    "message": "Free space below threshold"
  }
}
```

### 12.2 Force Disconnect

```json
{
  "type": "disconnect",
  "protoVersion": "1.0",
  "deviceId": "android-uuid",
  "payload": {
    "reason": "unpaired"
  }
}
```

---

## 13. State Machines (Summary)

### Device States
- DISCONNECTED
- CONNECTED
- PAIRED
- RECORDING
- EXPORTING_CLIP
- ERROR

### Coordinator View States
- IDLE
- PAIRING_ENABLED
- SESSION_ACTIVE
- REPLAY

---

## 14. Versioning & Compatibility

- Protocol version declared in every message
- Backward incompatible changes require new major version
- Coordinator may reject unsupported versions

---

## 15. Future Extensions

- WebRTC signaling messages
- Signed messages (HMAC)
- Multi-coordinator failover
- Frame-accurate sync

---

**End of Document – VAR Protocol Specification v1.0**

