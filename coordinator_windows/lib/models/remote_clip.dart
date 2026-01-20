import 'dart:typed_data';

/// Represents a video clip stored on a remote Android device.
class RemoteClip {
  final String deviceId;
  final String sessionId;
  final String clipId;
  final String markId;
  final int durationMs;
  final int sizeBytes;
  final DateTime createdAt;
  final String filePath;

  /// Thumbnail data (loaded separately)
  Uint8List? thumbnailData;

  /// Thumbnail URL (from device)
  String? thumbnailUrl;

  /// Whether thumbnail is loading
  bool isThumbnailLoading;

  /// Whether clip is currently downloading
  bool isDownloading;

  /// Download progress (0.0 to 1.0)
  double downloadProgress;

  /// Local path after download
  String? localPath;

  /// Error message if any operation failed
  String? errorMessage;

  RemoteClip({
    required this.deviceId,
    required this.sessionId,
    required this.clipId,
    required this.markId,
    required this.durationMs,
    required this.sizeBytes,
    required this.createdAt,
    required this.filePath,
    this.thumbnailData,
    this.thumbnailUrl,
    this.isThumbnailLoading = false,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
    this.localPath,
    this.errorMessage,
  });

  /// Create from protocol ClipInfo
  factory RemoteClip.fromClipInfo(
    String deviceId,
    String sessionId,
    dynamic clipInfo,
  ) {
    return RemoteClip(
      deviceId: deviceId,
      sessionId: sessionId,
      clipId: clipInfo.clipId as String,
      markId: clipInfo.markId as String,
      durationMs: clipInfo.durationMs as int,
      sizeBytes: clipInfo.sizeBytes as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(clipInfo.createdAt as int),
      filePath: clipInfo.filePath as String,
    );
  }

  /// Get duration as Duration object
  Duration get duration => Duration(milliseconds: durationMs);

  /// Get formatted duration string
  String get formattedDuration {
    final d = duration;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get formatted file size
  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (sizeBytes < 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Whether clip is downloaded locally
  bool get isDownloaded => localPath != null;

  /// Whether thumbnail is available
  bool get hasThumbnail => thumbnailData != null;

  RemoteClip copyWith({
    String? deviceId,
    String? sessionId,
    String? clipId,
    String? markId,
    int? durationMs,
    int? sizeBytes,
    DateTime? createdAt,
    String? filePath,
    Uint8List? thumbnailData,
    String? thumbnailUrl,
    bool? isThumbnailLoading,
    bool? isDownloading,
    double? downloadProgress,
    String? localPath,
    String? errorMessage,
  }) {
    return RemoteClip(
      deviceId: deviceId ?? this.deviceId,
      sessionId: sessionId ?? this.sessionId,
      clipId: clipId ?? this.clipId,
      markId: markId ?? this.markId,
      durationMs: durationMs ?? this.durationMs,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      createdAt: createdAt ?? this.createdAt,
      filePath: filePath ?? this.filePath,
      thumbnailData: thumbnailData ?? this.thumbnailData,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      isThumbnailLoading: isThumbnailLoading ?? this.isThumbnailLoading,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      localPath: localPath ?? this.localPath,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  String toString() =>
      'RemoteClip(clip: $clipId, mark: $markId, size: $formattedSize)';
}
