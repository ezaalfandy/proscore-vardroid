import 'dart:async';
import 'dart:ui';

import 'package:var_protocol/var_protocol.dart';

import '../models/playback_state.dart';
import 'device_manager_service.dart';

/// Service for remote video playback from Android camera devices.
/// Controls streaming via WebSocket commands and receives MJPEG stream.
class RemotePlaybackService {
  final DeviceManagerService _deviceManagerService;

  /// Stream controller for playback state changes
  final _stateController = StreamController<PlaybackState>.broadcast();

  /// Stream of playback state updates
  Stream<PlaybackState> get stateStream => _stateController.stream;

  /// Current playback state
  PlaybackState _state = PlaybackState.idle();

  /// Get current playback state
  PlaybackState get currentState => _state;

  /// Current stream URL (MJPEG)
  String? _streamUrl;

  /// Get stream URL for MJPEG view
  String? get streamUrl => _streamUrl;

  /// Current device ID
  String? _deviceId;

  /// Current session ID
  String? _sessionId;

  /// Current file path on device
  String? _filePath;

  /// Status update timer
  Timer? _statusTimer;

  RemotePlaybackService({
    required DeviceManagerService deviceManagerService,
  }) : _deviceManagerService = deviceManagerService;

  /// Start remote playback from a device
  Future<void> startPlayback({
    required String deviceId,
    required String sessionId,
    required String filePath,
    int positionMs = 0,
    double speed = 1.0,
    int quality = 70,
  }) async {
    // Close any existing playback
    await stopPlayback();

    _deviceId = deviceId;
    _sessionId = sessionId;
    _filePath = filePath;

    // Update state to loading
    _updateState(PlaybackState(
      source: PlaybackSource.remote,
      status: PlaybackStatus.loading,
      deviceId: deviceId,
      speed: speed,
    ));

    // Send start playback message to device
    final message = StartPlaybackMessage(
      deviceId: 'coordinator',
      sessionId: sessionId,
      filePath: filePath,
      positionMs: positionMs,
      speed: speed,
      quality: quality,
    );

    _deviceManagerService.sendToDevice(deviceId, message);
    print('Sent start_playback to $deviceId for $filePath');
  }

  /// Handle playback_ready message from device
  void handlePlaybackReady(PlaybackReadyMessage message) {
    if (message.deviceId != _deviceId) return;

    _streamUrl = message.url;

    _updateState(_state.copyWith(
      status: PlaybackStatus.paused,
      streamUrl: message.url,
      duration: Duration(milliseconds: message.durationMs),
      width: message.width,
      height: message.height,
      fps: message.fps,
    ));

    print('Playback ready: ${message.url}');
    print('  Duration: ${message.durationMs}ms, Size: ${message.width}x${message.height}');
  }

  /// Handle playback_status message from device
  void handlePlaybackStatus(PlaybackStatusMessage message) {
    if (message.deviceId != _deviceId) return;

    _updateState(_state.copyWith(
      position: Duration(milliseconds: message.positionMs),
      status: message.isPlaying ? PlaybackStatus.playing : PlaybackStatus.paused,
      speed: message.speed,
    ));
  }

  /// Handle playback_stopped message from device
  void handlePlaybackStopped(PlaybackStoppedMessage message) {
    if (message.deviceId != _deviceId) return;

    _cleanup();
    _updateState(PlaybackState.idle());
    print('Playback stopped for ${message.deviceId}');
  }

  /// Handle playback_error message from device
  void handlePlaybackError(PlaybackErrorMessage message) {
    if (message.deviceId != _deviceId) return;

    _updateState(_state.copyWith(
      status: PlaybackStatus.error,
      errorMessage: '${message.code}: ${message.message}',
    ));

    print('Playback error: ${message.code} - ${message.message}');
  }

  /// Stop remote playback
  Future<void> stopPlayback() async {
    if (_deviceId != null) {
      final message = StopPlaybackMessage(deviceId: 'coordinator');
      _deviceManagerService.sendToDevice(_deviceId!, message);
      print('Sent stop_playback to $_deviceId');
    }

    _cleanup();
    _updateState(PlaybackState.idle());
  }

  /// Play the video
  Future<void> play() async {
    if (_deviceId == null) return;

    final message = PlaybackControlMessage(
      deviceId: 'coordinator',
      action: PlaybackAction.play,
    );

    _deviceManagerService.sendToDevice(_deviceId!, message);
  }

  /// Pause the video
  Future<void> pause() async {
    if (_deviceId == null) return;

    final message = PlaybackControlMessage(
      deviceId: 'coordinator',
      action: PlaybackAction.pause,
    );

    _deviceManagerService.sendToDevice(_deviceId!, message);
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_state.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    if (_deviceId == null) return;

    // Clamp to valid range
    if (position < Duration.zero) {
      position = Duration.zero;
    } else if (_state.duration > Duration.zero && position > _state.duration) {
      position = _state.duration;
    }

    final message = PlaybackSeekMessage(
      deviceId: 'coordinator',
      positionMs: position.inMilliseconds,
    );

    _deviceManagerService.sendToDevice(_deviceId!, message);

    // Optimistically update local state
    _updateState(_state.copyWith(position: position));
  }

  /// Seek relative to current position
  Future<void> seekRelative(Duration delta) async {
    await seek(_state.position + delta);
  }

  /// Step forward by one frame
  Future<void> stepForward({int frames = 1}) async {
    if (_deviceId == null) return;

    final message = PlaybackControlMessage(
      deviceId: 'coordinator',
      action: PlaybackAction.stepForward,
      stepFrames: frames,
    );

    _deviceManagerService.sendToDevice(_deviceId!, message);
  }

  /// Step backward by one frame
  Future<void> stepBackward({int frames = 1}) async {
    if (_deviceId == null) return;

    final message = PlaybackControlMessage(
      deviceId: 'coordinator',
      action: PlaybackAction.stepBackward,
      stepFrames: frames,
    );

    _deviceManagerService.sendToDevice(_deviceId!, message);
  }

  /// Set playback speed
  Future<void> setSpeed(double speed) async {
    if (_deviceId == null) return;

    // Clamp speed to valid range
    speed = speed.clamp(PlaybackSpeed.min, PlaybackSpeed.max);

    final message = PlaybackControlMessage(
      deviceId: 'coordinator',
      action: PlaybackAction.setSpeed,
      speed: speed,
    );

    _deviceManagerService.sendToDevice(_deviceId!, message);

    // Optimistically update local state
    _updateState(_state.copyWith(speed: speed));
  }

  /// Increase playback speed to next preset
  Future<void> speedUp() async {
    final newSpeed = PlaybackSpeed.faster(_state.speed);
    await setSpeed(newSpeed);
  }

  /// Decrease playback speed to previous preset
  Future<void> slowDown() async {
    final newSpeed = PlaybackSpeed.slower(_state.speed);
    await setSpeed(newSpeed);
  }

  /// Set zoom level (handled locally, not sent to device)
  void setZoom(double zoom) {
    zoom = zoom.clamp(PlaybackZoom.min, PlaybackZoom.max);
    _updateState(_state.copyWith(zoom: zoom));
  }

  /// Zoom in
  void zoomIn() {
    setZoom(_state.zoom + PlaybackZoom.step);
  }

  /// Zoom out
  void zoomOut() {
    setZoom(_state.zoom - PlaybackZoom.step);
  }

  /// Set pan offset (handled locally)
  void setPan(Offset offset) {
    _updateState(_state.copyWith(panOffset: offset));
  }

  /// Pan relative to current position
  void panRelative(Offset delta) {
    setPan(_state.panOffset + delta);
  }

  /// Reset zoom and pan to defaults
  void resetZoomPan() {
    _updateState(_state.copyWith(
      zoom: PlaybackZoom.initial,
      panOffset: Offset.zero,
    ));
  }

  void _cleanup() {
    _statusTimer?.cancel();
    _statusTimer = null;
    _streamUrl = null;
    _deviceId = null;
    _sessionId = null;
    _filePath = null;
  }

  void _updateState(PlaybackState newState) {
    _state = newState;
    _stateController.add(_state);
  }

  /// Dispose resources
  void dispose() {
    stopPlayback();
    _stateController.close();
  }
}
