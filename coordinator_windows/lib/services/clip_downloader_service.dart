import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:var_protocol/var_protocol.dart';

import '../models/clip.dart';
import 'database_service.dart';
import 'device_manager_service.dart';
import 'session_manager_service.dart';

/// Service for downloading video clips from camera devices.
class ClipDownloaderService {
  final DatabaseService _databaseService;
  final DeviceManagerService _deviceManagerService;
  final SessionManagerService _sessionManagerService;
  final _uuid = const Uuid();

  /// Directory for storing downloaded clips
  late final String _clipsDirectory;

  /// Stream controller for clips list changes
  final _clipsController = StreamController<List<Clip>>.broadcast();

  /// Stream of clips updates
  Stream<List<Clip>> get clipsStream => _clipsController.stream;

  /// Cached clips for current session
  List<Clip> _currentSessionClips = [];

  /// Get clips for current session
  List<Clip> get currentSessionClips => List.unmodifiable(_currentSessionClips);

  /// Map of clip ID to download progress
  final Map<String, double> _downloadProgress = {};

  /// Currently downloading clips
  final Set<String> _downloading = {};

  ClipDownloaderService({
    required DatabaseService databaseService,
    required DeviceManagerService deviceManagerService,
    required SessionManagerService sessionManagerService,
  })  : _databaseService = databaseService,
        _deviceManagerService = deviceManagerService,
        _sessionManagerService = sessionManagerService;

  /// Initialize the clip downloader service.
  Future<void> init() async {
    // Set up clips directory
    final appDataDir = Platform.environment['LOCALAPPDATA'] ?? '.';
    _clipsDirectory = p.join(appDataDir, 'ProScoreVAR', 'clips');

    final dir = Directory(_clipsDirectory);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    print('Clips directory: $_clipsDirectory');
  }

  /// Request a clip from a specific device for a mark.
  Future<Clip> requestClip({
    required String markId,
    required String deviceId,
    int preRollMs = 10000,
    int postRollMs = 5000,
    String quality = 'original',
  }) async {
    final session = _sessionManagerService.currentSession;
    if (session == null) {
      throw StateError('No active session');
    }

    final clipId = _uuid.v4();
    final now = DateTime.now();

    final clip = Clip(
      id: clipId,
      sessionId: session.id,
      markId: markId,
      deviceId: deviceId,
      status: ClipStatus.requested,
      createdAt: now,
    );

    // Save to database
    await _databaseService.insertClip(clip);

    // Add to cache
    _currentSessionClips.add(clip);
    _clipsController.add(_currentSessionClips);

    // Send request to device
    final requestMessage = RequestClipMessage(
      deviceId: 'coordinator',
      sessionId: session.id,
      markId: markId,
      fromMs: preRollMs,
      toMs: postRollMs,
      quality: quality,
    );

    _deviceManagerService.sendToDevice(deviceId, requestMessage);

    print('Requested clip $clipId from device $deviceId for mark $markId');
    return clip;
  }

  /// Request clips from all recording devices for a mark.
  Future<List<Clip>> requestClipsFromAllDevices({
    required String markId,
    int preRollMs = 10000,
    int postRollMs = 5000,
    String quality = 'original',
  }) async {
    final devices = _deviceManagerService.connectedDevices;
    final clips = <Clip>[];

    for (final device in devices) {
      try {
        final clip = await requestClip(
          markId: markId,
          deviceId: device.device.id,
          preRollMs: preRollMs,
          postRollMs: postRollMs,
          quality: quality,
        );
        clips.add(clip);
      } catch (e) {
        print('Failed to request clip from ${device.device.id}: $e');
      }
    }

    return clips;
  }

  /// Handle clip_ready message from a device.
  Future<void> handleClipReady(ClipReadyMessage message) async {
    print('Clip ready: ${message.clipId} from ${message.deviceId}');
    print('  URL: ${message.url}');
    print('  Duration: ${message.durationMs}ms, Size: ${message.sizeBytes} bytes');

    // Find the clip
    final clip = await _databaseService.getClipById(message.clipId);
    if (clip == null) {
      print('Unknown clip ID: ${message.clipId}');
      return;
    }

    // Update clip with source info
    final updatedClip = clip.copyWith(
      sourceUrl: message.url,
      durationMs: message.durationMs,
      sizeBytes: message.sizeBytes,
      status: ClipStatus.ready,
    );

    await _databaseService.updateClip(updatedClip);

    // Update cache
    _updateClipInCache(updatedClip);

    // Auto-start download
    await downloadClip(message.clipId);
  }

  /// Download a clip from its source URL.
  Future<void> downloadClip(String clipId) async {
    if (_downloading.contains(clipId)) {
      print('Already downloading clip: $clipId');
      return;
    }

    final clip = await _databaseService.getClipById(clipId);
    if (clip == null) {
      print('Clip not found: $clipId');
      return;
    }

    if (clip.sourceUrl == null) {
      print('Clip has no source URL: $clipId');
      return;
    }

    _downloading.add(clipId);

    // Update status to downloading
    var updatedClip = clip.copyWith(status: ClipStatus.downloading);
    await _databaseService.updateClip(updatedClip);
    _updateClipInCache(updatedClip);

    try {
      // Create session directory if needed
      final sessionDir = Directory(p.join(_clipsDirectory, clip.sessionId));
      if (!await sessionDir.exists()) {
        await sessionDir.create(recursive: true);
      }

      // Determine file extension from URL
      final uri = Uri.parse(clip.sourceUrl!);
      var extension = p.extension(uri.path);
      if (extension.isEmpty) extension = '.mp4';

      final localPath = p.join(
        sessionDir.path,
        '${clip.markId}_${clip.deviceId}$extension',
      );

      // Download with progress tracking
      final client = http.Client();
      try {
        final request = http.Request('GET', uri);
        final response = await client.send(request);

        if (response.statusCode != 200) {
          throw HttpException('HTTP ${response.statusCode}');
        }

        final contentLength = response.contentLength ?? clip.sizeBytes ?? 0;
        var bytesReceived = 0;

        final file = File(localPath);
        final sink = file.openWrite();

        await for (final chunk in response.stream) {
          sink.add(chunk);
          bytesReceived += chunk.length;

          // Update progress
          if (contentLength > 0) {
            final progress = bytesReceived / contentLength;
            _downloadProgress[clipId] = progress;

            // Update clip progress periodically (every 10%)
            final progressPct = (progress * 10).floor() / 10;
            if (progressPct > (updatedClip.downloadProgress * 10).floor() / 10) {
              updatedClip = updatedClip.copyWith(downloadProgress: progress);
              await _databaseService.updateClip(updatedClip);
              _updateClipInCache(updatedClip);
            }
          }
        }

        await sink.close();

        // Mark as downloaded
        updatedClip = updatedClip.copyWith(
          localPath: localPath,
          status: ClipStatus.downloaded,
          downloadProgress: 1.0,
          downloadedAt: DateTime.now(),
        );
        await _databaseService.updateClip(updatedClip);
        _updateClipInCache(updatedClip);

        print('Downloaded clip to: $localPath');
      } finally {
        client.close();
      }
    } catch (e) {
      print('Failed to download clip $clipId: $e');

      // Mark as failed
      updatedClip = updatedClip.copyWith(
        status: ClipStatus.failed,
        errorMessage: e.toString(),
      );
      await _databaseService.updateClip(updatedClip);
      _updateClipInCache(updatedClip);
    } finally {
      _downloading.remove(clipId);
      _downloadProgress.remove(clipId);
    }
  }

  /// Retry downloading a failed clip.
  Future<void> retryDownload(String clipId) async {
    final clip = await _databaseService.getClipById(clipId);
    if (clip == null) return;

    if (clip.status == ClipStatus.failed) {
      // Reset status and retry
      final resetClip = clip.copyWith(
        status: ClipStatus.ready,
        errorMessage: null,
        downloadProgress: 0.0,
      );
      await _databaseService.updateClip(resetClip);
      _updateClipInCache(resetClip);

      await downloadClip(clipId);
    }
  }

  /// Get download progress for a clip.
  double getDownloadProgress(String clipId) {
    return _downloadProgress[clipId] ?? 0.0;
  }

  /// Get clips for a specific session.
  Future<List<Clip>> getClipsForSession(String sessionId) async {
    return await _databaseService.getClipsBySession(sessionId);
  }

  /// Get clips for a specific mark.
  Future<List<Clip>> getClipsForMark(String markId) async {
    return await _databaseService.getClipsByMark(markId);
  }

  /// Load clips for the current session.
  Future<void> loadCurrentSessionClips() async {
    final session = _sessionManagerService.currentSession;
    if (session == null) {
      _currentSessionClips = [];
    } else {
      _currentSessionClips = await _databaseService.getClipsBySession(session.id);
    }
    _clipsController.add(_currentSessionClips);
  }

  /// Clear clips cache.
  void clearClipsCache() {
    _currentSessionClips = [];
    _clipsController.add(_currentSessionClips);
  }

  void _updateClipInCache(Clip clip) {
    final index = _currentSessionClips.indexWhere((c) => c.id == clip.id);
    if (index >= 0) {
      _currentSessionClips[index] = clip;
    } else {
      _currentSessionClips.add(clip);
    }
    _clipsController.add(_currentSessionClips);
  }

  /// Open clip in default application.
  Future<void> openClip(String clipId) async {
    final clip = await _databaseService.getClipById(clipId);
    if (clip?.localPath == null) return;

    final file = File(clip!.localPath!);
    if (await file.exists()) {
      // Use start command on Windows to open with default app
      await Process.run('cmd', ['/c', 'start', '', clip.localPath!]);
    }
  }

  /// Open clips directory in file explorer.
  Future<void> openClipsDirectory() async {
    await Process.run('explorer', [_clipsDirectory]);
  }

  /// Get the clips directory path.
  String get clipsDirectory => _clipsDirectory;

  /// Dispose resources.
  void dispose() {
    _clipsController.close();
  }
}
