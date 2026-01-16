import 'dart:io';
import 'package:video_player/video_player.dart';

/// Service for managing video playback with slow motion and zoom
class PlaybackService {
  VideoPlayerController? _controller;
  double _playbackSpeed = 1.0;
  double _zoomLevel = 1.0;
  double _panX = 0.0;
  double _panY = 0.0;

  // Speed presets
  static const List<double> speedPresets = [0.1, 0.25, 0.5, 0.75, 1.0, 1.5, 2.0];

  // Getters
  VideoPlayerController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  bool get isPlaying => _controller?.value.isPlaying ?? false;
  Duration get position => _controller?.value.position ?? Duration.zero;
  Duration get duration => _controller?.value.duration ?? Duration.zero;
  double get playbackSpeed => _playbackSpeed;
  double get zoomLevel => _zoomLevel;
  double get panX => _panX;
  double get panY => _panY;

  /// Initialize video player with a file path
  Future<bool> initialize(String filePath) async {
    try {
      await dispose();

      final file = File(filePath);
      if (!await file.exists()) {
        return false;
      }

      _controller = VideoPlayerController.file(file);
      await _controller!.initialize();
      await _controller!.setLooping(false);

      _playbackSpeed = 1.0;
      _zoomLevel = 1.0;
      _panX = 0.0;
      _panY = 0.0;

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Play video
  Future<void> play() async {
    await _controller?.play();
  }

  /// Pause video
  Future<void> pause() async {
    await _controller?.pause();
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  /// Seek to position
  Future<void> seekTo(Duration position) async {
    await _controller?.seekTo(position);
  }

  /// Seek relative (forward/backward by duration)
  Future<void> seekRelative(Duration offset) async {
    if (_controller == null) return;

    final newPosition = position + offset;
    final clampedPosition = Duration(
      milliseconds: newPosition.inMilliseconds.clamp(0, duration.inMilliseconds),
    );
    await seekTo(clampedPosition);
  }

  /// Step forward by frames (approximate)
  Future<void> stepForward({int frames = 1}) async {
    // Assuming 30fps, each frame is ~33ms
    await seekRelative(Duration(milliseconds: 33 * frames));
  }

  /// Step backward by frames (approximate)
  Future<void> stepBackward({int frames = 1}) async {
    await seekRelative(Duration(milliseconds: -33 * frames));
  }

  /// Set playback speed
  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed.clamp(0.1, 2.0);
    await _controller?.setPlaybackSpeed(_playbackSpeed);
  }

  /// Cycle to next speed preset
  Future<void> cycleSpeed() async {
    final currentIndex = speedPresets.indexOf(_playbackSpeed);
    final nextIndex = (currentIndex + 1) % speedPresets.length;
    await setPlaybackSpeed(speedPresets[nextIndex]);
  }

  /// Set zoom level (1.0 = normal, 2.0 = 2x zoom, etc.)
  void setZoom(double zoom) {
    _zoomLevel = zoom.clamp(1.0, 5.0);
  }

  /// Set pan offset (normalized -1.0 to 1.0)
  void setPan(double x, double y) {
    // Limit pan based on zoom level
    final maxPan = (_zoomLevel - 1.0) / _zoomLevel;
    _panX = x.clamp(-maxPan, maxPan);
    _panY = y.clamp(-maxPan, maxPan);
  }

  /// Reset zoom and pan
  void resetZoomAndPan() {
    _zoomLevel = 1.0;
    _panX = 0.0;
    _panY = 0.0;
  }

  /// Get speed label for display
  String getSpeedLabel() {
    if (_playbackSpeed == 1.0) return '1x';
    if (_playbackSpeed < 1.0) return '${_playbackSpeed}x (Slow)';
    return '${_playbackSpeed}x (Fast)';
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}
