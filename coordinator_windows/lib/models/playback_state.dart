import 'dart:ui';

/// Playback source - local file or remote stream
enum PlaybackSource {
  local('local'),
  remote('remote');

  final String value;
  const PlaybackSource(this.value);

  static PlaybackSource fromString(String value) {
    return PlaybackSource.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PlaybackSource.local,
    );
  }
}

/// Playback status
enum PlaybackStatus {
  idle('idle'),
  loading('loading'),
  playing('playing'),
  paused('paused'),
  buffering('buffering'),
  error('error');

  final String value;
  const PlaybackStatus(this.value);

  static PlaybackStatus fromString(String value) {
    return PlaybackStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PlaybackStatus.idle,
    );
  }
}

/// Preset playback speeds for slow-motion
class PlaybackSpeed {
  static const double min = 0.1;
  static const double max = 2.0;
  static const double normal = 1.0;

  static const List<double> presets = [
    0.1,  // Super slow-mo
    0.25, // Quarter speed
    0.5,  // Half speed
    1.0,  // Normal
    1.5,  // Fast
    2.0,  // Double speed
  ];

  /// Get the next slower speed preset
  static double slower(double current) {
    for (int i = presets.length - 1; i >= 0; i--) {
      if (presets[i] < current - 0.01) {
        return presets[i];
      }
    }
    return presets.first;
  }

  /// Get the next faster speed preset
  static double faster(double current) {
    for (final speed in presets) {
      if (speed > current + 0.01) {
        return speed;
      }
    }
    return presets.last;
  }
}

/// Zoom level constraints
class PlaybackZoom {
  static const double min = 1.0;
  static const double max = 5.0;
  static const double step = 0.25;
  static const double initial = 1.0;
}

/// Playback state model
class PlaybackState {
  final PlaybackSource source;
  final PlaybackStatus status;
  final String? filePath;
  final String? streamUrl;
  final String? deviceId;
  final Duration position;
  final Duration duration;
  final double speed;
  final double zoom;
  final Offset panOffset;
  final int width;
  final int height;
  final int fps;
  final String? errorMessage;

  const PlaybackState({
    this.source = PlaybackSource.local,
    this.status = PlaybackStatus.idle,
    this.filePath,
    this.streamUrl,
    this.deviceId,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.speed = 1.0,
    this.zoom = 1.0,
    this.panOffset = Offset.zero,
    this.width = 0,
    this.height = 0,
    this.fps = 30,
    this.errorMessage,
  });

  /// Create initial idle state
  factory PlaybackState.idle() => const PlaybackState();

  /// Create state for local playback
  factory PlaybackState.localFile({
    required String filePath,
    Duration? duration,
    int width = 0,
    int height = 0,
  }) {
    return PlaybackState(
      source: PlaybackSource.local,
      status: PlaybackStatus.loading,
      filePath: filePath,
      duration: duration ?? Duration.zero,
      width: width,
      height: height,
    );
  }

  /// Create state for remote playback
  factory PlaybackState.remoteStream({
    required String deviceId,
    required String streamUrl,
    Duration? duration,
    int width = 0,
    int height = 0,
    int fps = 30,
  }) {
    return PlaybackState(
      source: PlaybackSource.remote,
      status: PlaybackStatus.loading,
      deviceId: deviceId,
      streamUrl: streamUrl,
      duration: duration ?? Duration.zero,
      width: width,
      height: height,
      fps: fps,
    );
  }

  PlaybackState copyWith({
    PlaybackSource? source,
    PlaybackStatus? status,
    String? filePath,
    String? streamUrl,
    String? deviceId,
    Duration? position,
    Duration? duration,
    double? speed,
    double? zoom,
    Offset? panOffset,
    int? width,
    int? height,
    int? fps,
    String? errorMessage,
  }) {
    return PlaybackState(
      source: source ?? this.source,
      status: status ?? this.status,
      filePath: filePath ?? this.filePath,
      streamUrl: streamUrl ?? this.streamUrl,
      deviceId: deviceId ?? this.deviceId,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      speed: speed ?? this.speed,
      zoom: zoom ?? this.zoom,
      panOffset: panOffset ?? this.panOffset,
      width: width ?? this.width,
      height: height ?? this.height,
      fps: fps ?? this.fps,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// Check if playback is active (not idle)
  bool get isActive => status != PlaybackStatus.idle;

  /// Check if currently playing
  bool get isPlaying => status == PlaybackStatus.playing;

  /// Check if paused
  bool get isPaused => status == PlaybackStatus.paused;

  /// Check if loading or buffering
  bool get isBuffering =>
      status == PlaybackStatus.loading || status == PlaybackStatus.buffering;

  /// Check if there's an error
  bool get hasError => status == PlaybackStatus.error;

  /// Check if local playback
  bool get isLocal => source == PlaybackSource.local;

  /// Check if remote streaming
  bool get isRemote => source == PlaybackSource.remote;

  /// Get progress as fraction (0.0 to 1.0)
  double get progress {
    if (duration.inMilliseconds == 0) return 0.0;
    return position.inMilliseconds / duration.inMilliseconds;
  }

  /// Get remaining time
  Duration get remaining => duration - position;

  /// Format position as timecode (MM:SS.mmm)
  String get formattedPosition => _formatDuration(position);

  /// Format duration as timecode (MM:SS.mmm)
  String get formattedDuration => _formatDuration(duration);

  /// Format remaining as timecode (MM:SS.mmm)
  String get formattedRemaining => _formatDuration(remaining);

  /// Get formatted speed string
  String get formattedSpeed {
    if (speed == 1.0) return '1x';
    if (speed == 0.25) return '0.25x';
    if (speed == 0.5) return '0.5x';
    if (speed == 0.1) return '0.1x';
    return '${speed}x';
  }

  /// Get formatted zoom string
  String get formattedZoom => '${zoom.toStringAsFixed(1)}x';

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    final millis = d.inMilliseconds % 1000;
    return '${minutes.toString().padLeft(2, '0')}:'
           '${seconds.toString().padLeft(2, '0')}.'
           '${(millis ~/ 10).toString().padLeft(2, '0')}';
  }

  /// Calculate frame time based on FPS
  Duration get frameTime => Duration(milliseconds: (1000 / fps).round());

  /// Get current frame number
  int get currentFrame => (position.inMilliseconds * fps / 1000).round();

  /// Get total frames
  int get totalFrames => (duration.inMilliseconds * fps / 1000).round();

  @override
  String toString() => 'PlaybackState(source: $source, status: $status, '
      'position: $formattedPosition, speed: $formattedSpeed)';
}
