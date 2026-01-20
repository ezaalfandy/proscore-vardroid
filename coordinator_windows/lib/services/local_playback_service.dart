import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/playback_state.dart';

/// Service for local video playback using media_kit.
/// Provides slow-motion, zoom, pan, and frame-stepping capabilities.
class LocalPlaybackService {
  Player? _player;
  VideoController? _videoController;

  /// Stream controller for playback state changes
  final _stateController = StreamController<PlaybackState>.broadcast();

  /// Stream of playback state updates
  Stream<PlaybackState> get stateStream => _stateController.stream;

  /// Current playback state
  PlaybackState _state = PlaybackState.idle();

  /// Get current playback state
  PlaybackState get currentState => _state;

  /// Get video controller for display
  VideoController? get videoController => _videoController;

  /// Current zoom level
  double _zoom = 1.0;

  /// Current pan offset
  Offset _panOffset = Offset.zero;

  /// Subscriptions for player events
  final List<StreamSubscription> _subscriptions = [];

  /// Whether the player is initialized
  bool get isInitialized => _player != null;

  /// Initialize media_kit (call once at app startup)
  static void ensureInitialized() {
    MediaKit.ensureInitialized();
  }

  /// Open a local video file for playback
  Future<void> open(String filePath) async {
    // Verify file exists
    final file = File(filePath);
    if (!await file.exists()) {
      _updateState(_state.copyWith(
        status: PlaybackStatus.error,
        errorMessage: 'File not found: $filePath',
      ));
      return;
    }

    // Close any existing player
    await close();

    // Update state to loading
    _updateState(PlaybackState.localFile(filePath: filePath));

    try {
      // Create new player
      _player = Player();
      _videoController = VideoController(_player!);

      // Set up event listeners
      _setupListeners();

      // Open media
      await _player!.open(Media(filePath));

      // Pause initially for controlled playback
      await _player!.pause();

    } catch (e) {
      _updateState(_state.copyWith(
        status: PlaybackStatus.error,
        errorMessage: 'Failed to open file: $e',
      ));
    }
  }

  /// Set up player event listeners
  void _setupListeners() {
    final player = _player;
    if (player == null) return;

    // Position updates
    _subscriptions.add(
      player.stream.position.listen((position) {
        _updateState(_state.copyWith(position: position));
      }),
    );

    // Duration updates
    _subscriptions.add(
      player.stream.duration.listen((duration) {
        _updateState(_state.copyWith(duration: duration));
      }),
    );

    // Playing state
    _subscriptions.add(
      player.stream.playing.listen((playing) {
        _updateState(_state.copyWith(
          status: playing ? PlaybackStatus.playing : PlaybackStatus.paused,
        ));
      }),
    );

    // Buffering state
    _subscriptions.add(
      player.stream.buffering.listen((buffering) {
        if (buffering && _state.status != PlaybackStatus.loading) {
          _updateState(_state.copyWith(status: PlaybackStatus.buffering));
        }
      }),
    );

    // Video size
    _subscriptions.add(
      player.stream.width.listen((width) {
        if (width != null) {
          _updateState(_state.copyWith(width: width));
        }
      }),
    );

    _subscriptions.add(
      player.stream.height.listen((height) {
        if (height != null) {
          _updateState(_state.copyWith(height: height));
        }
      }),
    );

    // Error handling
    _subscriptions.add(
      player.stream.error.listen((error) {
        _updateState(_state.copyWith(
          status: PlaybackStatus.error,
          errorMessage: error,
        ));
      }),
    );

    // Completed (end of file)
    _subscriptions.add(
      player.stream.completed.listen((completed) {
        if (completed) {
          _updateState(_state.copyWith(status: PlaybackStatus.paused));
        }
      }),
    );
  }

  /// Play the video
  Future<void> play() async {
    await _player?.play();
  }

  /// Pause the video
  Future<void> pause() async {
    await _player?.pause();
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
    // Clamp to valid range
    if (position < Duration.zero) {
      position = Duration.zero;
    } else if (_state.duration > Duration.zero && position > _state.duration) {
      position = _state.duration;
    }

    await _player?.seek(position);
  }

  /// Seek relative to current position
  Future<void> seekRelative(Duration delta) async {
    await seek(_state.position + delta);
  }

  /// Step forward by one frame
  Future<void> stepForward({int frames = 1}) async {
    // Pause if playing
    if (_state.isPlaying) {
      await pause();
    }

    // Calculate frame duration (default 30fps if unknown)
    final fps = _state.fps > 0 ? _state.fps : 30;
    final frameDuration = Duration(milliseconds: (1000 / fps * frames).round());

    await seekRelative(frameDuration);
  }

  /// Step backward by one frame
  Future<void> stepBackward({int frames = 1}) async {
    // Pause if playing
    if (_state.isPlaying) {
      await pause();
    }

    // Calculate frame duration (default 30fps if unknown)
    final fps = _state.fps > 0 ? _state.fps : 30;
    final frameDuration = Duration(milliseconds: (1000 / fps * frames).round());

    await seekRelative(-frameDuration);
  }

  /// Set playback speed
  Future<void> setSpeed(double speed) async {
    // Clamp speed to valid range
    speed = speed.clamp(PlaybackSpeed.min, PlaybackSpeed.max);

    await _player?.setRate(speed);
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

  /// Set zoom level
  void setZoom(double zoom) {
    _zoom = zoom.clamp(PlaybackZoom.min, PlaybackZoom.max);
    _updateState(_state.copyWith(zoom: _zoom));
  }

  /// Zoom in
  void zoomIn() {
    setZoom(_zoom + PlaybackZoom.step);
  }

  /// Zoom out
  void zoomOut() {
    setZoom(_zoom - PlaybackZoom.step);
  }

  /// Set pan offset
  void setPan(Offset offset) {
    _panOffset = offset;
    _updateState(_state.copyWith(panOffset: _panOffset));
  }

  /// Pan relative to current position
  void panRelative(Offset delta) {
    setPan(_panOffset + delta);
  }

  /// Reset zoom and pan to defaults
  void resetZoomPan() {
    _zoom = PlaybackZoom.initial;
    _panOffset = Offset.zero;
    _updateState(_state.copyWith(
      zoom: _zoom,
      panOffset: _panOffset,
    ));
  }

  /// Jump to start
  Future<void> jumpToStart() async {
    await seek(Duration.zero);
  }

  /// Jump to end
  Future<void> jumpToEnd() async {
    if (_state.duration > Duration.zero) {
      await seek(_state.duration - const Duration(milliseconds: 100));
    }
  }

  /// Close the player and release resources
  Future<void> close() async {
    // Cancel all subscriptions
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    // Dispose player
    await _player?.dispose();
    _player = null;
    _videoController = null;

    // Reset state
    _zoom = 1.0;
    _panOffset = Offset.zero;
    _updateState(PlaybackState.idle());
  }

  void _updateState(PlaybackState newState) {
    _state = newState;
    _stateController.add(_state);
  }

  /// Dispose resources
  void dispose() {
    close();
    _stateController.close();
  }
}
