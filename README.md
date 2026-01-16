# Pencak Silat VAR System

A Video Assistant Review (VAR) system for Pencak Silat competitions, featuring Android camera nodes and a Windows coordinator for multi-angle replay and incident review.

## System Architecture

```
┌─────────────────────┐
│  Android Camera 1   │───┐
├─────────────────────┤   │
│  Android Camera 2   │───┤
├─────────────────────┤   ├──► Wi-Fi Router ──► Windows Coordinator
│  Android Camera 3   │───┤                      (Control Center)
├─────────────────────┤   │
│  Android Camera 4   │───┘
└─────────────────────┘
```

**Key Features:**
- ✅ Offline/LAN-first operation (no internet required)
- ✅ Multi-angle video capture with up to 4 cameras
- ✅ Segmented recording for fast clip extraction
- ✅ Real-time incident marking
- ✅ Automatic clip export around marks
- ✅ Device status monitoring (battery, temperature, storage)

## Project Structure

```
proscore-vardroid/
├── var_protocol/              # Shared protocol package
│   ├── lib/src/
│   │   ├── constants.dart    # Protocol constants
│   │   ├── models/           # Message models
│   │   └── message_parser.dart
│   └── pubspec.yaml
│
├── camera_android/            # Android Camera Node App
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/           # Recording session models
│   │   ├── services/         # Core services
│   │   │   ├── device_storage_service.dart
│   │   │   ├── device_status_service.dart
│   │   │   ├── recording_service.dart
│   │   │   └── websocket_client_service.dart
│   │   ├── providers/        # State management
│   │   │   ├── connection_provider.dart
│   │   │   └── recording_provider.dart
│   │   └── ui/screens/       # UI screens
│   │       ├── home_screen.dart
│   │       ├── camera_preview_screen.dart
│   │       ├── settings_screen.dart
│   │       └── recording_library_screen.dart
│   └── pubspec.yaml
│
├── coordinator_windows/       # Windows Coordinator App
│   └── (To be implemented)
│
└── ai_material/              # Specification documents
    ├── pencak_silat_var_technical_guidance_v_1.md
    ├── var_android_camera_node_technical_guide_v_1.md
    └── var_protocol_specification_v_1.md
```

## Implementation Status

### ✅ Completed Components

#### 1. **VAR Protocol Package** (`var_protocol/`)
- [x] Complete protocol message models
- [x] JSON serialization/deserialization
- [x] Message parser for all message types
- [x] Protocol constants and error codes
- [x] Device-to-Coordinator messages (Hello, PairRequest, Auth, Status, RecordingStarted, MarkAck, ClipReady, etc.)
- [x] Coordinator-to-Device messages (PairAccept, StartRecord, StopRecord, Mark, RequestClip, etc.)

#### 2. **Android Camera Node** (`camera_android/`)

**Core Services:**
- [x] `DeviceStorageService` - Persistent storage for pairing data and settings
- [x] `DeviceStatusService` - Battery, temperature, and storage monitoring
- [x] `RecordingService` - Camera integration with segmented recording
- [x] `WebSocketClientService` - Complete WebSocket client implementation

**State Management:**
- [x] `ConnectionProvider` - Connection lifecycle, pairing, authentication, status heartbeat
- [x] `RecordingProvider` - Recording state management, command handling

**Data Models:**
- [x] `RecordingSession` - Session metadata and management
- [x] `VideoSegment` - Video segment tracking
- [x] `MarkData` - Incident mark storage
- [x] `ClipData` - Exported clip metadata

**User Interface:**
- [x] **Home Screen** - Connection status, pairing dialog, navigation
- [x] **Camera Preview Screen** - Main runtime screen with:
  - Live camera preview
  - Recording status overlay
  - Device status panel (battery, temp, storage)
  - Emergency controls (start/stop, mark, screen lock)
  - Warning indicators
- [x] **Settings Screen** - Video profile, recording settings, device info
- [x] **Recording Library Screen** - Browse and manage recordings

**Features:**
- [x] QR code pairing (UI ready, requires coordinator)
- [x] Manual IP pairing
- [x] Automatic reconnection with device key
- [x] Segmented video recording (2-5 second segments)
- [x] Mark acknowledgment and storage
- [x] Clip export from segments
- [x] Keep screen awake during recording
- [x] Screen lock to prevent accidental touches
- [x] Low storage/battery/overheat warnings
- [x] Status heartbeat to coordinator

### 🚧 Pending Components

#### 3. **Windows Coordinator** (`coordinator_windows/`)
- [ ] WebSocket server implementation
- [ ] Device manager (multi-camera connection handling)
- [ ] Pairing token generation and validation
- [ ] Session manager with SQLite
- [ ] Mark management
- [ ] Clip download and storage
- [ ] UI screens:
  - [ ] Pairing/Lobby screen with QR display
  - [ ] Match Control screen (start/stop all, mark button)
  - [ ] Replay & Review screen (clip playback)

## Getting Started

### Prerequisites

- Flutter SDK (>=3.8.1)
- Android Studio / Xcode (for mobile development)
- Visual Studio 2022 (for Windows development)
- Git

### Installation

1. **Clone the repository:**
```bash
git clone <repository-url>
cd proscore-vardroid
```

2. **Install dependencies:**

For Android Camera Node:
```bash
cd camera_android
flutter pub get
```

For Windows Coordinator:
```bash
cd coordinator_windows
flutter pub get
```

For Protocol Package:
```bash
cd var_protocol
flutter pub get
```

### Running the Android Camera Node

1. **Connect an Android device or start an emulator**

2. **Run the app:**
```bash
cd camera_android
flutter run
```

3. **Grant permissions:**
   - Camera permission
   - Microphone permission
   - Storage permission

### Using the Android Camera Node

1. **Home Screen:**
   - Tap "Connect to Coordinator" button
   - Enter coordinator IP address and port (e.g., `192.168.1.10:8765`)
   - Enter pairing token (if required)
   - Or scan QR code from coordinator (when available)

2. **Camera Preview:**
   - Once connected, tap "Open Camera"
   - View live camera preview
   - Monitor device status (battery, temp, storage)
   - Use emergency controls if needed
   - Recording is controlled by the coordinator

3. **Settings:**
   - Configure video resolution (720p, 1080p, 4K)
   - Set frame rate (30 fps, 60 fps)
   - Adjust segment duration (2s, 3s, 5s)
   - Configure clip pre-roll and post-roll

4. **Library:**
   - View all recorded sessions
   - See session details and marks
   - (Playback and delete to be implemented)

## Configuration

### Video Recording Settings

Default settings (can be changed in app):
- **Resolution:** 1080p
- **Frame Rate:** 30 fps
- **Bitrate:** 12 Mbps
- **Segment Duration:** 3 seconds

### Network Settings

- **Default Port:** 8765
- **Protocol:** WebSocket (ws://)
- **Status Heartbeat:** Every 2 seconds

### Storage Structure

Recordings are saved locally on the device:
```
/VAR/
  Event_<eventId>/
    Match_<matchId>/
      Cam_<deviceId>/
        segments/
          seg_000001.mp4
          seg_000002.mp4
          ...
        clips/
          mark_<markId>_-10000_+5000.mp4
        marks.json
        manifest.json
```

## Protocol Overview

### Connection Flow

1. **Camera → Coordinator:** `hello` (device info and capabilities)
2. **Camera → Coordinator:** `pair_request` (with token) or `auth` (with device key)
3. **Coordinator → Camera:** `pair_accept` (new pairing) or `auth_ok` (reconnection)
4. **Camera → Coordinator:** `status` (periodic heartbeat every 2s)

### Recording Flow

1. **Coordinator → Camera:** `start_record` (session details and profile)
2. **Camera → Coordinator:** `recording_started` (acknowledgment)
3. **Camera:** Records video in segments
4. **Coordinator → Camera:** `mark` (create incident mark)
5. **Camera → Coordinator:** `mark_ack` (acknowledgment)
6. **Coordinator → Camera:** `stop_record`
7. **Camera → Coordinator:** `recording_stopped`

### Clip Export Flow

1. **Coordinator → Camera:** `request_clip` (mark ID, time window)
2. **Camera:** Extracts and stitches segments
3. **Camera → Coordinator:** `clip_ready` (HTTP URL for download)
4. **Coordinator:** Downloads clip via HTTP

## Technical Details

### Segmented Recording

Video is recorded in short segments (2-5 seconds) instead of one long file:
- **Benefits:** Fast clip extraction, reduced corruption risk
- **Implementation:** Uses Flutter camera plugin with periodic segment rotation
- **Stitching:** Clips are created by copying/stitching relevant segments

### Time Synchronization

Simple time sync for MVP:
- Coordinator sends `ping` with timestamp
- Camera responds with `pong` + local timestamp
- Offset is calculated and stored with marks
- Sufficient for multi-angle alignment

### Device Status Monitoring

Real-time monitoring:
- **Battery:** Level % and charging state
- **Temperature:** CPU/battery temperature
- **Storage:** Free space in MB
- **Warnings:** Low battery, low storage, overheating

## Next Steps

To complete the VAR system:

1. **Implement Windows Coordinator:**
   - WebSocket server with device management
   - SQLite database for sessions and marks
   - QR code generation for pairing
   - UI for match control and replay

2. **Enhance Clip Export:**
   - Implement proper video stitching (FFmpeg)
   - HTTP server on camera node for clip serving
   - Automatic clip download on coordinator

3. **Testing:**
   - End-to-end pairing flow
   - Multi-camera coordination
   - Long-duration recording stability
   - Network resilience

4. **Future Enhancements:**
   - Live preview streaming (WebRTC)
   - Frame-accurate synchronization
   - AI-assisted incident detection
   - Cloud backup (post-match)

## Troubleshooting

### Camera Not Initializing
- Check camera permissions
- Restart the app
- Try a different resolution in Settings

### Connection Failed
- Verify coordinator IP and port
- Ensure both devices are on same Wi-Fi network
- Check firewall settings
- Verify coordinator is running and accepting connections

### Recording Issues
- Check available storage space
- Reduce video resolution/bitrate
- Monitor device temperature
- Ensure app has wake lock permission

## License

[Your License Here]

## Contributors

[Your Name/Team]

## Support

For issues and questions, please refer to the specification documents in `ai_material/` or contact the development team.
