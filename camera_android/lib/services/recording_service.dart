import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:var_protocol/var_protocol.dart';

import '../models/recording_session.dart';

/// Service for managing full-length (continuous) match recording.
/// - NO chunking
/// - NO clip extraction while recording (marks only)
/// - Clip extraction happens AFTER recording is stopped (file finalized)
class RecordingService {
  CameraController? _cameraController;
  RecordingSession? _currentSession;

  bool _isRecording = false;
  DateTime? _recordingStartTime;

  /// Intended final path for the full recording (we move the camera output here at stop)
  String? _currentVideoPath;

  // Camera settings
  List<CameraDescription> _availableCameras = [];
  CameraDescription? _currentCamera;
  ResolutionPreset _resolution = ResolutionPreset.veryHigh;

  // UI-only (note: camera plugin may not honor FPS unless you configure formats natively)
  int _fps = 30;

  // Camera control settings
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentExposureOffset = 0.0;
  double _minExposureOffset = -4.0;
  double _maxExposureOffset = 4.0;
  FocusMode _focusMode = FocusMode.auto;

  // Default clip window (used for post-stop extraction)
  int _defaultPreRollSeconds = 30;
  int _defaultPostRollSeconds = 5;

  // Getters
  RecordingSession? get currentSession => _currentSession;
  bool get isRecording => _isRecording;
  CameraController? get cameraController => _cameraController;
  bool get isCameraInitialized => _cameraController?.value.isInitialized ?? false;
  List<CameraDescription> get availableVARCameras => _availableCameras;
  CameraDescription? get currentCamera => _currentCamera;
  ResolutionPreset get currentResolution => _resolution;
  int get currentFps => _fps;

  // Camera control getters
  double get currentZoom => _currentZoom;
  double get minZoom => _minZoom;
  double get maxZoom => _maxZoom;
  double get currentExposureOffset => _currentExposureOffset;
  double get minExposureOffset => _minExposureOffset;
  double get maxExposureOffset => _maxExposureOffset;
  FocusMode get focusMode => _focusMode;

  int get defaultPreRollSeconds => _defaultPreRollSeconds;
  int get defaultPostRollSeconds => _defaultPostRollSeconds;

  Duration get recordingDuration => _recordingStartTime != null
      ? DateTime.now().difference(_recordingStartTime!)
      : Duration.zero;

  /// Initialize camera
  Future<bool> initializeCamera({
    ResolutionPreset resolution = ResolutionPreset.veryHigh,
    CameraDescription? camera,
    int fps = 30,
  }) async {
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) return false;

      if (camera != null) {
        _currentCamera = camera;
      } else {
        _currentCamera = _availableCameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => _availableCameras.first,
        );
      }

      _resolution = resolution;
      _fps = fps;

      await _cameraController?.dispose();
      _cameraController = CameraController(
        _currentCamera!,
        resolution,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();

      // Query camera limits
      await _initializeCameraLimits();

      // Best-effort camera settings
      try {
        await _cameraController!.setFocusMode(FocusMode.auto);
        await _cameraController!.setExposureMode(ExposureMode.auto);
        _focusMode = FocusMode.auto;
      } catch (_) {
        // Some devices don't support these settings
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Switch to a different camera (only allowed when not recording)
  Future<bool> switchCamera(CameraDescription camera) async {
    if (_isRecording) return false;

    try {
      await _cameraController?.dispose();
      _cameraController = null;

      return await initializeCamera(
        camera: camera,
        resolution: _resolution,
        fps: _fps,
      );
    } catch (_) {
      return false;
    }
  }

  /// Toggle between front and back camera
  Future<bool> toggleCamera() async {
    if (_isRecording || _availableCameras.length < 2) return false;

    try {
      final currentDirection = _currentCamera?.lensDirection;
      final targetDirection = currentDirection == CameraLensDirection.back
          ? CameraLensDirection.front
          : CameraLensDirection.back;

      final targetCamera = _availableCameras.firstWhere(
        (c) => c.lensDirection == targetDirection,
        orElse: () => _availableCameras.first,
      );

      return await switchCamera(targetCamera);
    } catch (_) {
      return false;
    }
  }

  /// Dispose camera
  Future<void> disposeCamera() async {
    await stopRecording();
    await _cameraController?.dispose();
    _cameraController = null;
  }

  /// Start continuous recording session (full-length)
  Future<bool> startRecording({
    required String sessionId,
    required String eventId,
    required String matchId,
  }) async {
    if (_isRecording ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return false;
    }

    try {
      // Create session directory structure
      final baseDir = await _getSessionBaseDirectory(eventId, matchId, sessionId);
      final clipsDir = Directory('$baseDir/clips');
      await clipsDir.create(recursive: true);

      // Intended final path for the full match video (we move it here on stop)
      _currentVideoPath = '$baseDir/full_recording.mp4';

      _currentSession = RecordingSession(
        sessionId: sessionId,
        eventId: eventId,
        matchId: matchId,
        startedAt: DateTime.now(),
        basePath: baseDir,
      );

      _recordingStartTime = DateTime.now();
      _isRecording = true;

      await _currentSession!.saveManifest();
      await _currentSession!.saveMarks();

      // Start camera recording (camera plugin chooses temp location)
      await _cameraController!.startVideoRecording();

      return true;
    } catch (_) {
      _isRecording = false;
      _recordingStartTime = null;
      _currentVideoPath = null;
      _currentSession = null;
      return false;
    }
  }

  /// Stop recording session (finalize master file)
  Future<void> stopRecording() async {
    if (!_isRecording) return;

    _isRecording = false;

    try {
      // Stop recording and get file from camera plugin
      if (_cameraController?.value.isRecordingVideo ?? false) {
        final videoFile = await _cameraController!.stopVideoRecording();

        // Move/copy to our intended location
        if (_currentVideoPath != null) {
          final sourceFile = File(videoFile.path);
          final targetFile = File(_currentVideoPath!);
          await targetFile.parent.create(recursive: true);

          try {
            await sourceFile.rename(_currentVideoPath!);
          } catch (_) {
            await sourceFile.copy(_currentVideoPath!);
            await sourceFile.delete();
          }

          // Update session metadata
          if (_currentSession != null) {
            _currentSession!.videoPath = _currentVideoPath;
            _currentSession!.videoDurationMs = recordingDuration.inMilliseconds;
          }
        }
      }

      // Save final manifest/marks
      if (_currentSession != null) {
        _currentSession!.stoppedAt = DateTime.now();
        await _currentSession!.saveManifest();
        await _currentSession!.saveMarks();
      }
    } catch (_) {
      // swallow; you can add logging if needed
    } finally {
      _recordingStartTime = null;
      _currentVideoPath = null;
    }
  }

  /// Add a MARK ONLY (no clip extraction while recording)
  Future<MarkData?> addMark({
    required String markId,
    required int coordinatorTs,
    String? note,
  }) async {
    if (_currentSession == null || !_isRecording || _recordingStartTime == null) {
      return null;
    }

    final markTime = DateTime.now();
    final recordingElapsed = markTime.difference(_recordingStartTime!);

    final mark = MarkData(
      markId: markId,
      coordinatorTs: coordinatorTs,
      deviceTs: markTime.millisecondsSinceEpoch,
      recordingOffsetMs: recordingElapsed.inMilliseconds,
      note: note,
    );

    _currentSession!.marks.add(mark);
    await _currentSession!.saveMarks();
    return mark;
  }

  /// Extract clip from a completed recording (post-recording extraction).
  /// Tries fast stream-copy first; can fallback to re-encode if needed.
  Future<ClipData?> extractClipFromSession({
    required RecordingSession session,
    required String markId,
    int? preRollMs,
    int? postRollMs,
    bool reencodeIfCopyFails = true,
  }) async {
    if (session.videoPath == null) return null;

    try {
      final mark = session.marks.firstWhere(
        (m) => m.markId == markId,
        orElse: () => throw Exception('Mark not found'),
      );

      final pre = preRollMs ?? (_defaultPreRollSeconds * 1000);
      final post = postRollMs ?? (_defaultPostRollSeconds * 1000);

      final markOffsetMs = mark.recordingOffsetMs ?? 0;
      final startMs = (markOffsetMs - pre).clamp(0, markOffsetMs);
      final endMs = markOffsetMs + post;
      final durationMs = endMs - startMs;

      final clipId = const Uuid().v4();
      final clipFileName =
          'clip_${markId}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final clipPath = '${session.clipsPath}/$clipFileName';

      final startSec = startMs / 1000.0;
      final durationSec = durationMs / 1000.0;

      // 1) Fast cut (may fail / be inaccurate at non-keyframes on some videos)
      final copyCmd =
          '-y -ss $startSec -i "${session.videoPath}" -t $durationSec '
          '-c copy -avoid_negative_ts 1 -movflags +faststart "$clipPath"';

      final copySession = await FFmpegKit.execute(copyCmd);
      final copyRc = await copySession.getReturnCode();

      if (ReturnCode.isSuccess(copyRc)) {
        final clipFile = File(clipPath);
        if (await clipFile.exists()) {
          final fileSize = await clipFile.length();
          return ClipData(
            clipId: clipId,
            markId: markId,
            filePath: clipPath,
            durationMs: durationMs,
            sizeBytes: fileSize,
            createdAt: DateTime.now(),
          );
        }
      }

      if (!reencodeIfCopyFails) return null;

      // 2) Reliable cut (re-encode)
      final reencodeCmd =
          '-y -ss $startSec -i "${session.videoPath}" -t $durationSec '
          '-c:v libx264 -preset veryfast -crf 23 '
          '-c:a aac -b:a 128k '
          '-movflags +faststart "$clipPath"';

      final reencodeSession = await FFmpegKit.execute(reencodeCmd);
      final reencodeRc = await reencodeSession.getReturnCode();

      if (ReturnCode.isSuccess(reencodeRc)) {
        final clipFile = File(clipPath);
        if (await clipFile.exists()) {
          final fileSize = await clipFile.length();
          return ClipData(
            clipId: clipId,
            markId: markId,
            filePath: clipPath,
            durationMs: durationMs,
            sizeBytes: fileSize,
            createdAt: DateTime.now(),
          );
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// Export a clip from the current session (only after recording stopped).
  Future<ClipData?> exportClip({
    required String markId,
    int? preRollMs,
    int? postRollMs,
    bool reencodeIfCopyFails = true,
  }) async {
    final session = _currentSession;
    if (session == null || session.videoPath == null || _isRecording) {
      return null;
    }

    return extractClipFromSession(
      session: session,
      markId: markId,
      preRollMs: preRollMs,
      postRollMs: postRollMs,
      reencodeIfCopyFails: reencodeIfCopyFails,
    );
  }

  /// Extract clips for ALL marks in a session (post-stop batch).
  Future<List<ClipData>> extractAllClipsFromSession({
    required RecordingSession session,
    int? preRollMs,
    int? postRollMs,
    bool reencodeIfCopyFails = true,
  }) async {
    final results = <ClipData>[];
    for (final mark in session.marks) {
      final clip = await extractClipFromSession(
        session: session,
        markId: mark.markId,
        preRollMs: preRollMs,
        postRollMs: postRollMs,
        reencodeIfCopyFails: reencodeIfCopyFails,
      );
      if (clip != null) results.add(clip);
    }
    return results;
  }

  /// Configure default clip window used for extraction (post-stop)
  void setDefaultClipWindow({
    int? preRollSeconds,
    int? postRollSeconds,
  }) {
    if (preRollSeconds != null) {
      _defaultPreRollSeconds = preRollSeconds.clamp(1, 180);
    }
    if (postRollSeconds != null) {
      _defaultPostRollSeconds = postRollSeconds.clamp(1, 60);
    }
  }

  /// Get all recording sessions by scanning manifest.json files
  Future<List<RecordingSession>> getAllSessions() async {
    try {
      final baseDir = await _getVarBaseDirectory();
      final sessions = <RecordingSession>[];
      final baseDirEntity = Directory(baseDir);

      if (!await baseDirEntity.exists()) return sessions;

      await for (final eventDir in baseDirEntity.list()) {
        if (eventDir is! Directory) continue;
        if (!eventDir.path.contains('Event_')) continue;

        await for (final matchDir in eventDir.list()) {
          if (matchDir is! Directory) continue;
          if (!matchDir.path.contains('Match_')) continue;

          await for (final camDir in matchDir.list()) {
            if (camDir is! Directory) continue;
            if (!camDir.path.contains('Cam_')) continue;

            final manifestFile = File('${camDir.path}/manifest.json');
            if (!await manifestFile.exists()) continue;

            try {
              final content = await manifestFile.readAsString();
              final json = jsonDecode(content) as Map<String, dynamic>;
              final session = RecordingSession.fromJson(json);
              sessions.add(session);
            } catch (_) {
              // Skip invalid manifest files
            }
          }
        }
      }

      sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      return sessions;
    } catch (_) {
      return [];
    }
  }

  /// Delete a recording session (folder)
  Future<bool> deleteSession(RecordingSession session) async {
    try {
      final sessionDir = Directory(session.basePath);
      if (await sessionDir.exists()) {
        await sessionDir.delete(recursive: true);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Request storage permissions (kept as-is from your code)
  Future<bool> _requestStoragePermission() async {
    if (await Permission.manageExternalStorage.isGranted) return true;

    var status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;

    if (await Permission.storage.isGranted) return true;

    status = await Permission.storage.request();
    return status.isGranted;
  }

  Future<String> _getVarBaseDirectory() async {
    final hasPermission = await _requestStoragePermission();

    if (hasPermission) {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final parts = extDir.path.split('/');
        final androidIndex = parts.indexOf('Android');
        if (androidIndex > 0) {
          final rootPath = parts.sublist(0, androidIndex).join('/');
          return '$rootPath/video-assistant-referee';
        }
      }
    }

    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/video-assistant-referee';
  }

  Future<String> _getSessionBaseDirectory(
    String eventId,
    String matchId,
    String sessionId,
  ) async {
    final baseDir = await _getVarBaseDirectory();
    final deviceId = sessionId.split('-').first;
    return '$baseDir/Event_$eventId/Match_$matchId/Cam_$deviceId';
  }

  /// Change camera resolution (only when not recording)
  Future<bool> changeResolution(ResolutionPreset resolution) async {
    if (_isRecording) return false;

    _resolution = resolution;
    await _cameraController?.dispose();
    _cameraController = null;

    return await initializeCamera(
      resolution: resolution,
      camera: _currentCamera,
      fps: _fps,
    );
  }

  /// Change FPS (UI-only unless you implement native camera format selection)
  Future<bool> changeFps(int fps) async {
    if (_isRecording) return false;

    _fps = fps;
    await _cameraController?.dispose();
    _cameraController = null;

    return await initializeCamera(
      resolution: _resolution,
      camera: _currentCamera,
      fps: fps,
    );
  }

  /// Change resolution and FPS together (only when not recording)
  Future<bool> changeVideoSettings({
    ResolutionPreset? resolution,
    int? fps,
  }) async {
    if (_isRecording) return false;

    final nextResolution = resolution ?? _resolution;
    final nextFps = fps ?? _fps;

    _resolution = nextResolution;
    _fps = nextFps;

    await _cameraController?.dispose();
    _cameraController = null;

    return await initializeCamera(
      resolution: nextResolution,
      camera: _currentCamera,
      fps: nextFps,
    );
  }

  /// Get camera name for display
  String getCameraName(CameraDescription camera) {
    final direction = camera.lensDirection == CameraLensDirection.back
        ? 'Back'
        : camera.lensDirection == CameraLensDirection.front
            ? 'Front'
            : 'External';
    return '$direction Camera';
  }

  /// Get resolution name for display
  String getResolutionName(ResolutionPreset preset) {
    switch (preset) {
      case ResolutionPreset.low:
        return '240p';
      case ResolutionPreset.medium:
        return '480p';
      case ResolutionPreset.high:
        return '720p';
      case ResolutionPreset.veryHigh:
        return '1080p';
      case ResolutionPreset.ultraHigh:
        return '4K';
      case ResolutionPreset.max:
        return 'Max';
      default:
        return 'Unknown';
    }
  }

  /// Initialize camera limits (zoom, exposure)
  Future<void> _initializeCameraLimits() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      _minZoom = await _cameraController!.getMinZoomLevel();
      _maxZoom = await _cameraController!.getMaxZoomLevel();
      _currentZoom = _minZoom;

      _minExposureOffset = await _cameraController!.getMinExposureOffset();
      _maxExposureOffset = await _cameraController!.getMaxExposureOffset();
      _currentExposureOffset = 0.0;
    } catch (_) {
      // Use default values if queries fail
      _minZoom = 1.0;
      _maxZoom = 1.0;
      _currentZoom = 1.0;
      _minExposureOffset = -4.0;
      _maxExposureOffset = 4.0;
      _currentExposureOffset = 0.0;
    }
  }

  /// Set zoom level
  Future<bool> setZoom(double zoom) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return false;
    }

    try {
      final clampedZoom = zoom.clamp(_minZoom, _maxZoom);
      await _cameraController!.setZoomLevel(clampedZoom);
      _currentZoom = clampedZoom;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Set exposure offset (brightness control)
  Future<bool> setExposureOffset(double offset) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return false;
    }

    try {
      final clampedOffset = offset.clamp(_minExposureOffset, _maxExposureOffset);
      await _cameraController!.setExposureOffset(clampedOffset);
      _currentExposureOffset = clampedOffset;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Set focus mode (auto or locked)
  Future<bool> setFocusMode(FocusMode mode) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return false;
    }

    try {
      await _cameraController!.setFocusMode(mode);
      _focusMode = mode;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Set focus point (tap to focus) - coordinates are normalized 0.0 to 1.0
  Future<bool> setFocusPoint(Offset point) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return false;
    }

    try {
      // Set focus and exposure point
      await _cameraController!.setFocusPoint(point);
      await _cameraController!.setExposurePoint(point);
      return true;
    } catch (_) {
      return false;
    }
  }
}
