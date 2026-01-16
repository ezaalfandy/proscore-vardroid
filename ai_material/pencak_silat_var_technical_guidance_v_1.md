# Pencak Silat VAR System – Technical Guidance v1.0

> **Status:** Draft / MVP-oriented
>
> **Scope:** Local VAR operation using Flutter Android (Camera Nodes) and Flutter Windows (Coordinator)
>
> **Operation Mode:** Offline / LAN-first

---

## 1. Purpose

This document defines the **technical architecture, responsibilities, protocols, and implementation guidance** for building a **Pencak Silat VAR (Video Assistant Review) system**.

The system is designed to:
- Operate **fully offline** on a local network
- Use **Android phones as independent cameras**
- Use a **Windows laptop as the VAR control center**
- Support **multi-angle replay**, marks, and incident clip export

This document is intended to be used as:
- Internal technical reference
- Project knowledge base
- Implementation checklist

---

## 2. Core Design Principles

1. **Local-first reliability**  
   VAR must continue to work even if internet connectivity is lost.

2. **Separation of concerns**  
   - Phones focus on capture + recording
   - Coordinator focuses on control, replay, and logging

3. **Fast iteration (MVP-first)**  
   Live preview and advanced sync are phased, not required for MVP.

4. **Deterministic behavior**  
   No dependency on cloud signaling or NAT traversal during matches.

---

## 3. System Components Overview

### 3.1 Camera Node (Flutter Android)

**Role:** Independent camera + recorder

**Responsibilities:**
- Capture video using device camera
- Record video **locally** in high quality
- Maintain persistent connection to Coordinator
- Receive commands (start/stop/mark/export)
- Export short clips around marks
- Report device status (battery, temp, storage)

**Non-responsibilities:**
- Multi-device coordination
- Video synchronization logic
- Operator UI

---

### 3.2 Coordinator (Flutter Windows)

**Role:** VAR control center

**Responsibilities:**
- Run operator UI
- Manage camera connections (up to 4)
- Control recording lifecycle
- Create and manage marks (incidents)
- Request, receive, and play clips
- Persist session logs locally (SQLite)

**Optional (future):**
- Live preview grid
- Cloud sync (post-match)

---

## 4. Network Topology

- All devices connect to the **same local Wi-Fi (LAN)**
- No internet connection required during operation

```
[ Android Cam 1 ]
[ Android Cam 2 ]  -->  Wi-Fi Router  -->  [ Windows Coordinator ]
[ Android Cam 3 ]
[ Android Cam 4 ]
```

Coordinator listens on:
- `0.0.0.0:<PORT>` (reachable by all LAN clients)

---

## 5. Pairing & Device Onboarding

### 5.1 Pairing Modes

1. **QR Code (Primary)**
2. **Manual IP Entry (Fallback)**

Both methods result in the same pairing handshake.

---

### 5.2 Pairing Session Rules

- Pairing must be explicitly **enabled** by operator
- Pairing session has:
  - Short-lived `pair_token` (e.g. 5 minutes)
  - Optional 6-digit `PIN`
- After successful pairing:
  - Device receives a persistent `device_key`
  - Device reconnects automatically using `device_key`

---

### 5.3 QR Payload Format

Custom scheme (recommended):
```
proscorevar://pair?host=192.168.1.10&port=8765&token=ABCD12
```

Manual entry fields:
- Host / IP
- Port
- Token or PIN

---

## 6. Communication Protocol

### 6.1 Transport

- **WebSocket** for:
  - command/control
  - status updates
  - pairing handshake

- **HTTP (LAN)** for:
  - clip download (recommended)

---

### 6.2 Message Conventions

- JSON only
- All messages include:
  - `type`
  - `deviceId`
  - `sessionId` (if applicable)
  - `protoVersion`

---

### 6.3 Core Message Types

#### Device → Coordinator

- `hello`
- `status`
- `recording_started`
- `recording_stopped`
- `mark_ack`
- `clip_ready`

#### Coordinator → Device

- `pair_accept`
- `start_record`
- `stop_record`
- `mark`
- `request_clip`
- `set_slot`

*(Exact JSON schemas should be defined in a separate Protocol Spec document.)*

---

## 7. Recording Strategy (Critical)

### 7.1 Segmented Recording

**Do NOT record a single long MP4.**

Instead:
- Record into **short segments** (2–5 seconds)
- Enables instant clip extraction

---

### 7.2 Android File Structure

```
/VAR/
  Event_<eventId>/
    Match_<matchId>/
      Cam_<deviceId>/
        segments/
          seg_000001.mp4
          seg_000002.mp4
        marks.json
        clips/
          mark_00012_-10_+5.mp4
```

---

### 7.3 Clip Export Flow

1. Coordinator sends `request_clip`
2. Device determines relevant segments
3. Device stitches segments into clip
4. Device exposes clip via HTTP endpoint
5. Coordinator downloads clip

---

## 8. Time Synchronization (MVP Level)

- Coordinator periodically sends `ping` with timestamp
- Device responds with `pong` + local timestamp
- Offset is estimated and cached

Marks store:
- `coordinatorTs`
- `deviceLocalTs`
- `offsetEstimate`

This is sufficient for multi-angle alignment in MVP.

---

## 9. Coordinator Data Storage

Use **SQLite** for local persistence.

### 9.1 Tables

#### `devices`
- device_id (PK)
- device_key
- name (Cam1..Cam4)
- last_seen
- ip, port

#### `sessions`
- session_id (PK)
- event_id
- match_id
- started_at
- ended_at

#### `marks`
- mark_id (PK)
- session_id
- coordinator_ts
- note

#### `clips`
- clip_id (PK)
- mark_id
- device_id
- local_path
- duration_ms

---

## 10. Coordinator UI Modules

### 10.1 Pairing / Lobby
- Enable/disable pairing
- QR display
- IP:port display
- Connected devices list

### 10.2 Match Control
- Start all / Stop all
- Per-camera status indicators
- Global MARK button
- Notes input

### 10.3 Replay & Review
- Mark timeline
- Clip request per camera
- Video playback
- Incident folder view

---

## 11. Failure Handling

Must handle gracefully:
- Device disconnect during recording
- Device reconnect using `device_key`
- Low storage warning
- Overheat warning
- Clip export failure

Coordinator rules:
- Marks are written immediately to SQLite
- Every command has state: sent / ack / failed

---

## 12. Security (LAN-Level)

- Pairing only when explicitly enabled
- Token expiration
- Persistent `device_key`
- Coordinator can revoke device access

Optional future:
- HMAC-signed messages using device_key

---

## 13. Testing Checklist

### Functional
- Pair via QR
- Pair via manual IP
- Start/stop recording
- Create marks
- Request clips
- Replay clips

### Stress
- 4 cameras, 30+ minutes
- Frequent marks
- Clip requests during recording

### Network
- Temporary Wi-Fi drop
- Device roaming

---

## 14. Suggested Repository Structure

### coordinator_windows/
```
lib/
  ui/
  services/
    ws_server/
    device_manager/
    session_manager/
    clip_downloader/
  data/sqlite/
assets/
```

### camera_android/
```
lib/
  pairing/
  recording/
  segmenter/
  ws_client/
  clip_export/
  status/
```

---

## 15. Future Extensions

- Live WebRTC preview
- Multi-angle synchronized playback
- Cloud sync (post-event)
- AI-assisted incident tagging

---

**End of Document – VAR Technical Guidance v1.0**

