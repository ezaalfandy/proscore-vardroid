# VAR Android Camera Node – Technical Guide v1.0

> **Project:** Pencak Silat VAR
>
> **Component:** Flutter Android Camera Node (Phone)
>
> **Role:** Local camera + local recorder + clip exporter
>
> **Operation:** LAN-first / offline

---

## 1. Purpose

This document specifies the **Android Phone (Camera Node)** technical guidance, focusing on:

1) **UI Composition** (what screens exist and what they contain)
2) **Most essential features** required for a production-ready MVP

This document is intended to be used alongside:
- **VAR Protocol Specification v1.0**
- **VAR Technical Guidance v1.0**

---

## 2. Core Responsibilities

The Android Camera Node MUST:

- Pair and connect to the **Windows Coordinator** over LAN
- Record video **locally** in high quality
- Keep recording stable during long matches (battery/heat/storage aware)
- Accept commands from Coordinator:
  - start/stop recording
  - mark events
  - export clip around mark
- Provide clip access via LAN (HTTP URL) for Coordinator download
- Report operational status continuously

Non-responsibilities:
- Multi-camera coordination
- Operator replay UI
- Persistent match/event database (Coordinator owns it)

---

## 3. UI Composition (Screens & Layout)

### 3.1 Screen Map (Minimum)

1. **Welcome / Mode Select**
2. **Pairing & Connection** (QR + Manual)
3. **Camera Preview & Status** (main runtime screen)
4. **Recording Library** (local files)
5. **Settings** (video profile, storage, debugging)

---

### 3.2 Welcome / Mode Select

**Goal:** Make it obvious this phone is a camera node.

**UI content:**
- App title: *"VAR Camera Node"*
- Big primary action: **Connect to Coordinator**
- Secondary: **Library**
- Secondary: **Settings**

**Behavior:**
- If device is already paired before, show:
  - *"Last Coordinator: <ip:port>"* + **Reconnect** button

---

### 3.3 Pairing & Connection Screen

#### A) QR Pairing Tab
- Camera viewfinder for scanning
- After scan:
  - show parsed `host`, `port`
  - show pairing token preview (masked)
- Button: **Connect**

#### B) Manual Pairing Tab
- Input: Coordinator Host/IP
- Input: Port
- Input: Pair Token or PIN
- Button: **Connect**

#### C) Connection Result Section
- Status badges:
  - DISCONNECTED / CONNECTING / CONNECTED / PAIRED
- Error message area (human readable):
  - *"Pairing disabled on Coordinator"*
  - *"Invalid token"*
  - *"Coordinator not reachable"*

**UX rule:**
- Never block the user behind technical jargon.

---

### 3.4 Camera Preview & Status (Main Runtime Screen)

**This is the screen the phone stays on during the whole match.**

#### Layout (Recommended)

**Top bar:**
- Assigned camera slot: **Cam1 / Cam2 / Cam3 / Cam4**
- Connection indicator (dot): green/yellow/red

**Center:**
- Live camera preview (full width)
- Optional overlay text:
  - recording status
  - timer

**Bottom control strip (local emergency controls):**
- Start/Stop recording (enabled only if coordinator allows, but should exist as emergency)
- Mark button (optional local mark)
- Lock screen button (prevents accidental touches)

**Status panel (always visible):**
- Battery %
- Temperature
- Free storage
- Recording state
- Current profile (1080p/30)

**Important UI behaviors:**
- Screen must keep awake (no sleep) while connected or recording
- Provide "**Kiosk mode**" option (guided access) if possible
- Show large warnings:
  - LOW STORAGE
  - OVERHEAT
  - DISCONNECTED

---

### 3.5 Recording Library (Local)

**Purpose:** Allow manual access to recordings if needed.

**UI content:**
- Filter by session/match
- List of recordings:
  - date/time
  - duration
  - size
- Actions:
  - play
  - export/share (manual)
  - delete (guarded)

**Rules:**
- Deleting requires confirmation + coordinator not actively using the session

---

### 3.6 Settings

#### Essential settings
- Video profile presets:
  - 1080p30 (default)
  - 1080p60 (good light only)
  - 720p30 (safe mode)
- Clip export defaults:
  - pre-roll (e.g. 10s)
  - post-roll (e.g. 5s)

#### Network settings
- Coordinator endpoint (last used)
- HTTP clip server port

#### Storage settings
- Base directory
- Auto-clean rules (optional)

#### Debug
- show deviceId
- protocol logs
- network ping

---

## 4. Most Essential Features (MVP Requirements)

### 4.1 Pairing + Persistent Trust

**Must-haves:**
- QR pairing and manual pairing
- Persist `deviceKey` after `pair_accept`
- Reconnect with `auth` using stored deviceKey

**Edge cases:**
- deviceKey revoked → fall back to re-pair

---

### 4.2 Stable Local Recording

**Must-haves:**
- High-quality local recording
- Continuous recording for 30-60 minutes without crashes
- Single full-length file per session (no chunking)
- Single files commonly last 5+ minutes (or more)

**Recommended default profile:**
- 1080p @ 30fps, ~8-16 Mbps

**Operational requirements:**
- Keep CPU use stable
- Avoid over-aggressive bitrate

---

### 4.3 Command Handling (Coordinator Control)

Camera must reliably respond to:
- `start_record`
- `stop_record`
- `mark`
- `request_clip`

**Rule:** each command should result in an ACK or ERROR message.

---

### 4.4 Mark Logging

When receiving `mark`:
- store mark with both:
  - coordinator timestamp
  - local timestamp
- persist locally (e.g. `marks.json`) inside match folder

**Rationale:** provides audit trail if coordinator loses connection.

---

### 4.5 Clip Export Around Mark

**Must-haves:**
- export clip from the full recording file
- clips can be generated only after recording is stopped and finalized
- return `clip_ready` with HTTP URL
- support at least `preview` quality (fast)

**Default clip window:**
- -10s to +5s

---

### 4.6 Local HTTP Clip Server

**Must-haves:**
- Serve exported clips over LAN
- Simple endpoint design:
  - `GET /clips/<clipId>.mp4`

**Security (LAN level):**
- bind only to local network
- optionally require short-lived token as query parameter

---

### 4.7 Status Heartbeat

**Must-haves:**
- send `status` every ~2 seconds
- include:
  - battery
  - temperature
  - freeSpaceMB
  - isRecording
  - signalStrength (if available)

Coordinator uses this for warnings and decisions.

---

### 4.8 Safety Guards (Production Reality)

#### A) Low storage
- define threshold (e.g. < 2GB)
- warn coordinator and show red alert
- block new session start if too low

#### B) Thermal
- monitor device temp (or thermal status)
- warn at elevated thresholds
- suggest lower profile or pause

#### C) Accidental touches
- provide screen lock / kiosk mode

#### D) Power stability
- show *"Plug charger"* reminder

---

## 5. Recording Implementation Guidance (Practical)

### 5.1 Recording Strategy (Current)

Record as:
- a single full-length `.mp4` per session (no chunking)

Implications:
- clip extraction happens after recording stop
- full recordings commonly exceed 5 minutes
- clip extraction uses FFmpeg trimming (stream copy or re-encode)

---

### 5.2 File & Folder Naming

Use consistent naming:
- `full_recording.mp4`

Match folder includes:
- `clips/`
- `marks.json`
- `manifest.json` (optional)

---

## 6. Connection & Reconnect Rules

- Auto-reconnect with exponential backoff
- If coordinator changes IP:
  - allow manual update
- If auth fails:
  - show prompt to re-pair

---

## 7. UX Rules for Tournament Use

- Default to **fullscreen preview** and keep screen awake
- Keep UI text large and readable
- Any error must be actionable:
  - *"Reconnect"*
  - *"Re-pair"*
  - *"Free storage"*

---

## 8. Acceptance Checklist (Android MVP)

- [ ] QR pairing works
- [ ] Manual IP pairing works
- [ ] Reconnect without re-pair works
- [ ] Start/stop recording via coordinator
- [ ] Mark ACK is stored locally
- [ ] Clip export returns valid HTTP URL
- [ ] Coordinator can download and play clip
- [ ] Status heartbeat is stable for 30 minutes
- [ ] Low storage warning triggers
- [ ] App stays awake during recording

---

## 9. Future Enhancements (Android)

- Live low-latency preview stream (WebRTC)
- Background recording resilience
- Automatic upload of incident clips to coordinator
- Adaptive bitrate / profile switching on thermal warning

---

**End of Document – VAR Android Camera Node Technical Guide v1.0**
