import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/playback_state.dart';
import '../services/local_playback_service.dart';
import '../services/remote_playback_service.dart';

/// Provider for playback state - manages both local and remote playback.
class PlaybackProvider extends ChangeNotifier {
  final LocalPlaybackService _localPlaybackService;
  final RemotePlaybackService _remotePlaybackService;

  StreamSubscription? _localStateSubscription;
  StreamSubscription? _remoteStateSubscription;

  PlaybackState _state = PlaybackState.idle();

  PlaybackProvider({
    required LocalPlaybackService localPlaybackService,
    required RemotePlaybackService remotePlaybackService,
  })  : _localPlaybackService = localPlaybackService,
        _remotePlaybackService = remotePlaybackService {
    _init();
  }

  void _init() {
    // Listen to local playback state
    _localStateSubscription =
        _localPlaybackService.stateStream.listen((state) {
      if (state.source == PlaybackSource.local || _state.source == PlaybackSource.local) {
        _state = state;
        notifyListeners();
      }
    });

    // Listen to remote playback state
    _remoteStateSubscription =
        _remotePlaybackService.stateStream.listen((state) {
      if (state.source == PlaybackSource.remote || _state.source == PlaybackSource.remote) {
        _state = state;
        notifyListeners();
      }
    });
  }

  /// Current playback state
  PlaybackState get state => _state;

  /// Whether playback is active (not idle)
  bool get isPlaybackActive => _state.isActive;

  /// Whether currently playing
  bool get isPlaying => _state.isPlaying;

  /// Whether currently paused
  bool get isPaused => _state.isPaused;

  /// Whether loading or buffering
  bool get isBuffering => _state.isBuffering;

  /// Whether local playback
  bool get isLocal => _state.isLocal;

  /// Whether remote streaming
  bool get isRemote => _state.isRemote;

  /// Video controller for local playback (media_kit)
  VideoController? get videoController => _localPlaybackService.videoController;

  /// Stream URL for remote playback (MJPEG)
  String? get streamUrl => _remotePlaybackService.streamUrl;

  // ==================== Playback Control ====================

  /// Open a local video file for playback
  Future<void> openLocalFile(String filePath) async {
    // Stop any existing playback
    await close();
    await _localPlaybackService.open(filePath);
  }

  /// Start remote playback from a device
  Future<void> startRemotePlayback({
    required String deviceId,
    required String sessionId,
    required String filePath,
    int positionMs = 0,
    double speed = 1.0,
    int quality = 70,
  }) async {
    // Stop any existing playback
    await close();
    await _remotePlaybackService.startPlayback(
      deviceId: deviceId,
      sessionId: sessionId,
      filePath: filePath,
      positionMs: positionMs,
      speed: speed,
      quality: quality,
    );
  }

  /// Play
  Future<void> play() async {
    if (_state.isLocal) {
      await _localPlaybackService.play();
    } else if (_state.isRemote) {
      await _remotePlaybackService.play();
    }
  }

  /// Pause
  Future<void> pause() async {
    if (_state.isLocal) {
      await _localPlaybackService.pause();
    } else if (_state.isRemote) {
      await _remotePlaybackService.pause();
    }
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_state.isLocal) {
      await _localPlaybackService.togglePlayPause();
    } else if (_state.isRemote) {
      await _remotePlaybackService.togglePlayPause();
    }
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    if (_state.isLocal) {
      await _localPlaybackService.seek(position);
    } else if (_state.isRemote) {
      await _remotePlaybackService.seek(position);
    }
  }

  /// Seek relative to current position
  Future<void> seekRelative(Duration delta) async {
    if (_state.isLocal) {
      await _localPlaybackService.seekRelative(delta);
    } else if (_state.isRemote) {
      await _remotePlaybackService.seekRelative(delta);
    }
  }

  /// Step forward by frames
  Future<void> stepForward({int frames = 1}) async {
    if (_state.isLocal) {
      await _localPlaybackService.stepForward(frames: frames);
    } else if (_state.isRemote) {
      await _remotePlaybackService.stepForward(frames: frames);
    }
  }

  /// Step backward by frames
  Future<void> stepBackward({int frames = 1}) async {
    if (_state.isLocal) {
      await _localPlaybackService.stepBackward(frames: frames);
    } else if (_state.isRemote) {
      await _remotePlaybackService.stepBackward(frames: frames);
    }
  }

  /// Set playback speed
  Future<void> setSpeed(double speed) async {
    if (_state.isLocal) {
      await _localPlaybackService.setSpeed(speed);
    } else if (_state.isRemote) {
      await _remotePlaybackService.setSpeed(speed);
    }
  }

  /// Speed up to next preset
  Future<void> speedUp() async {
    if (_state.isLocal) {
      await _localPlaybackService.speedUp();
    } else if (_state.isRemote) {
      await _remotePlaybackService.speedUp();
    }
  }

  /// Slow down to previous preset
  Future<void> slowDown() async {
    if (_state.isLocal) {
      await _localPlaybackService.slowDown();
    } else if (_state.isRemote) {
      await _remotePlaybackService.slowDown();
    }
  }

  // ==================== Zoom & Pan ====================

  /// Set zoom level
  void setZoom(double zoom) {
    if (_state.isLocal) {
      _localPlaybackService.setZoom(zoom);
    } else if (_state.isRemote) {
      _remotePlaybackService.setZoom(zoom);
    }
  }

  /// Zoom in
  void zoomIn() {
    if (_state.isLocal) {
      _localPlaybackService.zoomIn();
    } else if (_state.isRemote) {
      _remotePlaybackService.zoomIn();
    }
  }

  /// Zoom out
  void zoomOut() {
    if (_state.isLocal) {
      _localPlaybackService.zoomOut();
    } else if (_state.isRemote) {
      _remotePlaybackService.zoomOut();
    }
  }

  /// Set pan offset
  void setPan(Offset offset) {
    if (_state.isLocal) {
      _localPlaybackService.setPan(offset);
    } else if (_state.isRemote) {
      _remotePlaybackService.setPan(offset);
    }
  }

  /// Pan relative to current position
  void panRelative(Offset delta) {
    if (_state.isLocal) {
      _localPlaybackService.panRelative(delta);
    } else if (_state.isRemote) {
      _remotePlaybackService.panRelative(delta);
    }
  }

  /// Reset zoom and pan
  void resetZoomPan() {
    if (_state.isLocal) {
      _localPlaybackService.resetZoomPan();
    } else if (_state.isRemote) {
      _remotePlaybackService.resetZoomPan();
    }
  }

  // ==================== Close ====================

  /// Close playback and release resources
  Future<void> close() async {
    if (_state.isLocal) {
      await _localPlaybackService.close();
    } else if (_state.isRemote) {
      await _remotePlaybackService.stopPlayback();
    }
    _state = PlaybackState.idle();
    notifyListeners();
  }

  // ==================== Service Access ====================

  /// Get local playback service (for message handling)
  LocalPlaybackService get localService => _localPlaybackService;

  /// Get remote playback service (for message handling)
  RemotePlaybackService get remoteService => _remotePlaybackService;

  @override
  void dispose() {
    _localStateSubscription?.cancel();
    _remoteStateSubscription?.cancel();
    super.dispose();
  }
}
