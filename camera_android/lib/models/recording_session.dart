import 'dart:convert';
import 'dart:io';

/// Represents a recording session (continuous recording, no segments)
class RecordingSession {
  final String sessionId;
  final String eventId;
  final String matchId;
  final DateTime startedAt;
  DateTime? stoppedAt;
  final String basePath;
  String? videoPath;        // Path to full recording video
  int? videoDurationMs;     // Duration of recording in milliseconds
  final List<MarkData> marks;
  final List<ClipData> clips;

  // Legacy field for backward compatibility
  final List<VideoSegment> segments;

  RecordingSession({
    required this.sessionId,
    required this.eventId,
    required this.matchId,
    required this.startedAt,
    this.stoppedAt,
    required this.basePath,
    this.videoPath,
    this.videoDurationMs,
    List<MarkData>? marks,
    List<ClipData>? clips,
    List<VideoSegment>? segments,
  })  : marks = marks ?? [],
        clips = clips ?? [],
        segments = segments ?? [];

  bool get isActive => stoppedAt == null;

  Duration get duration {
    if (videoDurationMs != null) {
      return Duration(milliseconds: videoDurationMs!);
    }
    final endTime = stoppedAt ?? DateTime.now();
    return endTime.difference(startedAt);
  }

  String get clipsPath => '$basePath/clips';
  String get marksFilePath => '$basePath/marks.json';
  String get manifestFilePath => '$basePath/manifest.json';

  // Legacy getter for backward compatibility
  String get segmentsPath => '$basePath/segments';

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'eventId': eventId,
      'matchId': matchId,
      'startedAt': startedAt.toIso8601String(),
      'stoppedAt': stoppedAt?.toIso8601String(),
      'basePath': basePath,
      'videoPath': videoPath,
      'videoDurationMs': videoDurationMs,
      'marks': marks.map((m) => m.toJson()).toList(),
      'clips': clips.map((c) => c.toJson()).toList(),
      'segments': segments.map((s) => s.toJson()).toList(),
    };
  }

  factory RecordingSession.fromJson(Map<String, dynamic> json) {
    return RecordingSession(
      sessionId: json['sessionId'] as String,
      eventId: json['eventId'] as String,
      matchId: json['matchId'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      stoppedAt: json['stoppedAt'] != null
          ? DateTime.parse(json['stoppedAt'] as String)
          : null,
      basePath: json['basePath'] as String,
      videoPath: json['videoPath'] as String?,
      videoDurationMs: json['videoDurationMs'] as int?,
      marks: (json['marks'] as List?)
              ?.map((m) => MarkData.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      clips: (json['clips'] as List?)
              ?.map((c) => ClipData.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      segments: (json['segments'] as List?)
              ?.map((s) => VideoSegment.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Save session manifest to disk
  Future<void> saveManifest() async {
    final file = File(manifestFilePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(toJson()));
  }

  /// Save marks to disk
  Future<void> saveMarks() async {
    final file = File(marksFilePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(marks.map((m) => m.toJson()).toList()),
    );
  }
}

/// Represents a video segment (legacy, kept for backward compatibility)
class VideoSegment {
  final int index;
  final String filePath;
  final DateTime startTime;
  DateTime? endTime;
  final int durationMs;

  VideoSegment({
    required this.index,
    required this.filePath,
    required this.startTime,
    this.endTime,
    required this.durationMs,
  });

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'filePath': filePath,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'durationMs': durationMs,
    };
  }

  factory VideoSegment.fromJson(Map<String, dynamic> json) {
    return VideoSegment(
      index: json['index'] as int,
      filePath: json['filePath'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      durationMs: json['durationMs'] as int,
    );
  }
}

/// Represents a mark (incident) in the recording
class MarkData {
  final String markId;
  final int coordinatorTs;    // Timestamp from coordinator
  final int deviceTs;         // Timestamp on device
  final int? recordingOffsetMs; // Offset from recording start in milliseconds
  final String? note;

  MarkData({
    required this.markId,
    required this.coordinatorTs,
    required this.deviceTs,
    this.recordingOffsetMs,
    this.note,
  });

  Map<String, dynamic> toJson() {
    return {
      'markId': markId,
      'coordinatorTs': coordinatorTs,
      'deviceTs': deviceTs,
      if (recordingOffsetMs != null) 'recordingOffsetMs': recordingOffsetMs,
      if (note != null) 'note': note,
    };
  }

  factory MarkData.fromJson(Map<String, dynamic> json) {
    return MarkData(
      markId: json['markId'] as String,
      coordinatorTs: json['coordinatorTs'] as int,
      deviceTs: json['deviceTs'] as int,
      recordingOffsetMs: json['recordingOffsetMs'] as int?,
      note: json['note'] as String?,
    );
  }
}

/// Represents an exported clip
class ClipData {
  final String clipId;
  final String markId;
  final String filePath;
  final int durationMs;
  final int sizeBytes;
  final DateTime createdAt;

  ClipData({
    required this.clipId,
    required this.markId,
    required this.filePath,
    required this.durationMs,
    required this.sizeBytes,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'clipId': clipId,
      'markId': markId,
      'filePath': filePath,
      'durationMs': durationMs,
      'sizeBytes': sizeBytes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ClipData.fromJson(Map<String, dynamic> json) {
    return ClipData(
      clipId: json['clipId'] as String,
      markId: json['markId'] as String,
      filePath: json['filePath'] as String,
      durationMs: json['durationMs'] as int,
      sizeBytes: json['sizeBytes'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
