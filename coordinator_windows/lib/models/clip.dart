/// Video clip model.
class Clip {
  final String id;
  final String sessionId;
  final String markId;
  final String deviceId;
  final String? sourceUrl;
  final String? localPath;
  final int? durationMs;
  final int? sizeBytes;
  final ClipStatus status;
  final double downloadProgress;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? downloadedAt;

  Clip({
    required this.id,
    required this.sessionId,
    required this.markId,
    required this.deviceId,
    this.sourceUrl,
    this.localPath,
    this.durationMs,
    this.sizeBytes,
    this.status = ClipStatus.pending,
    this.downloadProgress = 0.0,
    this.errorMessage,
    required this.createdAt,
    this.downloadedAt,
  });

  /// Create from database row
  factory Clip.fromMap(Map<String, dynamic> map) {
    return Clip(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      markId: map['mark_id'] as String,
      deviceId: map['device_id'] as String,
      sourceUrl: map['source_url'] as String?,
      localPath: map['local_path'] as String?,
      durationMs: map['duration_ms'] as int?,
      sizeBytes: map['size_bytes'] as int?,
      status: ClipStatus.fromString(map['status'] as String? ?? 'pending'),
      downloadProgress: (map['download_progress'] as num?)?.toDouble() ?? 0.0,
      errorMessage: map['error_message'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      downloadedAt: map['downloaded_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['downloaded_at'] as int)
          : null,
    );
  }

  /// Convert to database row
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'mark_id': markId,
      'device_id': deviceId,
      'source_url': sourceUrl,
      'local_path': localPath,
      'duration_ms': durationMs,
      'size_bytes': sizeBytes,
      'status': status.value,
      'download_progress': downloadProgress,
      'error_message': errorMessage,
      'created_at': createdAt.millisecondsSinceEpoch,
      'downloaded_at': downloadedAt?.millisecondsSinceEpoch,
    };
  }

  Clip copyWith({
    String? id,
    String? sessionId,
    String? markId,
    String? deviceId,
    String? sourceUrl,
    String? localPath,
    int? durationMs,
    int? sizeBytes,
    ClipStatus? status,
    double? downloadProgress,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? downloadedAt,
  }) {
    return Clip(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      markId: markId ?? this.markId,
      deviceId: deviceId ?? this.deviceId,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      localPath: localPath ?? this.localPath,
      durationMs: durationMs ?? this.durationMs,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      status: status ?? this.status,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      downloadedAt: downloadedAt ?? this.downloadedAt,
    );
  }

  /// Get duration as Duration object
  Duration? get duration => durationMs != null ? Duration(milliseconds: durationMs!) : null;

  /// Get formatted file size
  String get formattedSize {
    if (sizeBytes == null) return 'Unknown';
    if (sizeBytes! < 1024) return '$sizeBytes B';
    if (sizeBytes! < 1024 * 1024) return '${(sizeBytes! / 1024).toStringAsFixed(1)} KB';
    if (sizeBytes! < 1024 * 1024 * 1024) {
      return '${(sizeBytes! / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes! / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  String toString() => 'Clip(id: $id, status: $status, progress: $downloadProgress)';
}

enum ClipStatus {
  pending('pending'),
  requested('requested'),
  generating('generating'),
  ready('ready'),
  downloading('downloading'),
  downloaded('downloaded'),
  failed('failed');

  final String value;
  const ClipStatus(this.value);

  static ClipStatus fromString(String value) {
    return ClipStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ClipStatus.pending,
    );
  }
}
