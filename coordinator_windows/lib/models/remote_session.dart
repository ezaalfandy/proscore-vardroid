/// Represents a recording session stored on a remote Android device.
class RemoteSession {
  final String deviceId;
  final String sessionId;
  final String? eventId;
  final String? matchId;
  final DateTime startedAt;
  final DateTime? stoppedAt;
  final int? videoDurationMs;
  final int clipCount;
  final String? videoPath;

  RemoteSession({
    required this.deviceId,
    required this.sessionId,
    this.eventId,
    this.matchId,
    required this.startedAt,
    this.stoppedAt,
    this.videoDurationMs,
    required this.clipCount,
    this.videoPath,
  });

  /// Create from protocol SessionInfo
  factory RemoteSession.fromSessionInfo(
    String deviceId,
    dynamic sessionInfo,
  ) {
    return RemoteSession(
      deviceId: deviceId,
      sessionId: sessionInfo.sessionId as String,
      eventId: sessionInfo.eventId as String?,
      matchId: sessionInfo.matchId as String?,
      startedAt: DateTime.fromMillisecondsSinceEpoch(sessionInfo.startedAt as int),
      stoppedAt: sessionInfo.stoppedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(sessionInfo.stoppedAt as int)
          : null,
      videoDurationMs: sessionInfo.videoDurationMs as int?,
      clipCount: sessionInfo.clipCount as int,
      videoPath: sessionInfo.videoPath as String?,
    );
  }

  /// Get duration as Duration object
  Duration? get duration => videoDurationMs != null
      ? Duration(milliseconds: videoDurationMs!)
      : null;

  /// Get formatted duration string
  String get formattedDuration {
    final d = duration;
    if (d == null) return '--:--';
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get display name for the session
  String get displayName {
    if (matchId != null && matchId!.isNotEmpty) {
      return matchId!;
    }
    return 'Session ${sessionId.substring(0, 8)}';
  }

  /// Get event display name
  String get eventDisplayName {
    if (eventId != null && eventId!.isNotEmpty) {
      return eventId!;
    }
    return 'Unknown Event';
  }

  RemoteSession copyWith({
    String? deviceId,
    String? sessionId,
    String? eventId,
    String? matchId,
    DateTime? startedAt,
    DateTime? stoppedAt,
    int? videoDurationMs,
    int? clipCount,
    String? videoPath,
  }) {
    return RemoteSession(
      deviceId: deviceId ?? this.deviceId,
      sessionId: sessionId ?? this.sessionId,
      eventId: eventId ?? this.eventId,
      matchId: matchId ?? this.matchId,
      startedAt: startedAt ?? this.startedAt,
      stoppedAt: stoppedAt ?? this.stoppedAt,
      videoDurationMs: videoDurationMs ?? this.videoDurationMs,
      clipCount: clipCount ?? this.clipCount,
      videoPath: videoPath ?? this.videoPath,
    );
  }

  @override
  String toString() =>
      'RemoteSession(device: $deviceId, session: $sessionId, clips: $clipCount)';
}
