import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:var_protocol/var_protocol.dart';

import '../models/remote_session.dart';
import '../models/remote_clip.dart';
import 'device_manager_service.dart';

/// Service for exploring clips on remote Android devices.
/// Handles session/clip listing, thumbnail fetching, downloading, and deletion.
class ClipExplorerService {
  final DeviceManagerService _deviceManagerService;

  /// Sessions indexed by device ID
  final Map<String, List<RemoteSession>> _deviceSessions = {};

  /// Clips indexed by "${deviceId}_${sessionId}"
  final Map<String, List<RemoteClip>> _sessionClips = {};

  /// Thumbnail cache (clipId -> thumbnail data)
  final Map<String, Uint8List> _thumbnailCache = {};

  /// Sessions stream controller
  final _sessionsController =
      StreamController<Map<String, List<RemoteSession>>>.broadcast();

  /// Clips stream controller
  final _clipsController =
      StreamController<Map<String, List<RemoteClip>>>.broadcast();

  /// Stream of sessions by device
  Stream<Map<String, List<RemoteSession>>> get sessionsStream =>
      _sessionsController.stream;

  /// Stream of clips by session
  Stream<Map<String, List<RemoteClip>>> get clipsStream =>
      _clipsController.stream;

  /// Get sessions for a device
  List<RemoteSession> getSessionsForDevice(String deviceId) =>
      List.unmodifiable(_deviceSessions[deviceId] ?? []);

  /// Get all sessions across all devices
  List<RemoteSession> get allSessions {
    final all = <RemoteSession>[];
    for (final sessions in _deviceSessions.values) {
      all.addAll(sessions);
    }
    all.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return all;
  }

  /// Get clips for a session
  List<RemoteClip> getClipsForSession(String deviceId, String sessionId) =>
      List.unmodifiable(_sessionClips['${deviceId}_$sessionId'] ?? []);

  /// Local downloads directory
  late String _downloadsDirectory;

  ClipExplorerService({
    required DeviceManagerService deviceManagerService,
  }) : _deviceManagerService = deviceManagerService;

  /// Initialize the service
  Future<void> init() async {
    // Set up downloads directory
    final appDir = await getApplicationDocumentsDirectory();
    _downloadsDirectory = '${appDir.path}\\VAR_Coordinator\\explorer_downloads';
    await Directory(_downloadsDirectory).create(recursive: true);
  }

  /// Request sessions list from a device
  void requestSessions(String deviceId) {
    final message = ListSessionsMessage(deviceId: 'coordinator');
    _deviceManagerService.sendToDevice(deviceId, message);
  }

  /// Request sessions from all connected devices
  void requestSessionsFromAll() {
    final message = ListSessionsMessage(deviceId: 'coordinator');
    _deviceManagerService.broadcastToAll(message);
  }

  /// Request clips list for a session
  void requestClips(String deviceId, String sessionId) {
    final message = ListClipsMessage(
      deviceId: 'coordinator',
      sessionId: sessionId,
    );
    _deviceManagerService.sendToDevice(deviceId, message);
  }

  /// Request thumbnail for a clip
  void requestThumbnail(
    String deviceId,
    String sessionId,
    String clipId, {
    int? width,
    int? height,
  }) {
    // Mark clip as loading thumbnail
    _updateClipThumbnailLoading(deviceId, sessionId, clipId, true);

    final message = GetThumbnailMessage(
      deviceId: 'coordinator',
      sessionId: sessionId,
      clipId: clipId,
      width: width,
      height: height,
    );
    _deviceManagerService.sendToDevice(deviceId, message);
  }

  /// Delete a clip on the device
  void deleteRemoteClip(String deviceId, String sessionId, String clipId) {
    final message = DeleteClipMessage(
      deviceId: 'coordinator',
      sessionId: sessionId,
      clipId: clipId,
    );
    _deviceManagerService.sendToDevice(deviceId, message);
  }

  /// Delete a session on the device
  void deleteRemoteSession(String deviceId, String sessionId) {
    final message = DeleteSessionMessage(
      deviceId: 'coordinator',
      sessionId: sessionId,
    );
    _deviceManagerService.sendToDevice(deviceId, message);
  }

  /// Download a clip from device
  Future<String?> downloadClip(RemoteClip clip) async {
    // First, we need to register the clip for serving on the device
    // and get the download URL. For now, we assume the device will
    // serve clips via its clip server when requested.

    // Update clip state
    _updateClipDownloading(clip.deviceId, clip.sessionId, clip.clipId, true);

    try {
      // Get device's clip server URL
      // The clip URL format is: http://{deviceIp}:9100/clips/{clipId}.mp4
      final device = _deviceManagerService.getConnectedDevice(clip.deviceId);
      if (device == null) {
        throw Exception('Device not connected');
      }

      // Extract device IP from preview URL
      final deviceIp = _extractIpFromUrl(device.previewUrl);
      if (deviceIp == null) {
        throw Exception('Device IP not available - start preview first');
      }

      final clipUrl =
          'http://$deviceIp:${VarProtocol.defaultClipPort}/clips/${clip.clipId}.mp4';

      // Create local file path
      final localPath =
          '$_downloadsDirectory\\${clip.deviceId}\\${clip.sessionId}';
      await Directory(localPath).create(recursive: true);
      final filePath = '$localPath\\${clip.clipId}.mp4';

      // Download the file
      final request = http.Request('GET', Uri.parse(clipUrl));
      final response = await request.send();

      if (response.statusCode != 200) {
        throw Exception('Download failed: ${response.statusCode}');
      }

      final file = File(filePath);
      final sink = file.openWrite();
      final totalBytes = response.contentLength ?? clip.sizeBytes;
      var receivedBytes = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        final progress = totalBytes > 0 ? receivedBytes / totalBytes : 0.0;
        _updateClipProgress(
            clip.deviceId, clip.sessionId, clip.clipId, progress);
      }

      await sink.close();

      // Update clip with local path
      _updateClipLocalPath(clip.deviceId, clip.sessionId, clip.clipId, filePath);
      _updateClipDownloading(clip.deviceId, clip.sessionId, clip.clipId, false);

      return filePath;
    } catch (e) {
      print('Error downloading clip: $e');
      _updateClipError(clip.deviceId, clip.sessionId, clip.clipId, e.toString());
      _updateClipDownloading(clip.deviceId, clip.sessionId, clip.clipId, false);
      return null;
    }
  }

  /// Start remote preview of a clip
  void startRemotePreview(
    String deviceId,
    String sessionId,
    String filePath,
  ) {
    // This uses the existing playback system
    final message = StartPlaybackMessage(
      deviceId: 'coordinator',
      sessionId: sessionId,
      filePath: filePath,
      positionMs: 0,
      speed: 1.0,
      quality: VarProtocol.playbackQualityMedium,
    );
    _deviceManagerService.sendToDevice(deviceId, message);
  }

  /// Stop remote preview
  void stopRemotePreview(String deviceId) {
    final message = StopPlaybackMessage(deviceId: 'coordinator');
    _deviceManagerService.sendToDevice(deviceId, message);
  }

  // ===== Message Handlers =====

  /// Handle sessions list response from device
  void handleSessionsList(String deviceId, SessionsListMessage message) {
    final sessions = message.sessions
        .map((info) => RemoteSession.fromSessionInfo(deviceId, info))
        .toList();

    // Sort by start time (newest first)
    sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));

    _deviceSessions[deviceId] = sessions;
    _sessionsController.add(Map.unmodifiable(_deviceSessions));

    print(
        'Received ${sessions.length} sessions from device $deviceId');
  }

  /// Handle clips list response from device
  void handleClipsList(String deviceId, ClipsListMessage message) {
    final sessionId = message.sessionId!;
    final clips = message.clips
        .map((info) => RemoteClip.fromClipInfo(deviceId, sessionId, info))
        .toList();

    // Sort by creation time (newest first)
    clips.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final key = '${deviceId}_$sessionId';
    _sessionClips[key] = clips;
    _clipsController.add(Map.unmodifiable(_sessionClips));

    print(
        'Received ${clips.length} clips for session $sessionId from device $deviceId');
  }

  /// Handle thumbnail ready response from device
  Future<void> handleThumbnailReady(
    String deviceId,
    ThumbnailReadyMessage message,
  ) async {
    final clipId = message.clipId;
    final url = message.url;

    try {
      // Download thumbnail data
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final thumbnailData = response.bodyBytes;
        _thumbnailCache[clipId] = thumbnailData;

        // Update clip with thumbnail data
        _updateClipThumbnail(deviceId, clipId, thumbnailData, url);
      }
    } catch (e) {
      print('Error downloading thumbnail: $e');
    }

    // Mark as no longer loading
    _updateClipThumbnailLoadingByClipId(deviceId, clipId, false);
  }

  /// Handle delete confirmation from device
  void handleDeleteConfirm(String deviceId, DeleteConfirmMessage message) {
    final targetType = message.targetType;
    final targetId = message.targetId;

    if (targetType == DeleteTargetType.session) {
      // Remove session from local cache
      _deviceSessions[deviceId]?.removeWhere((s) => s.sessionId == targetId);
      _sessionsController.add(Map.unmodifiable(_deviceSessions));

      // Also remove clips for this session
      final keyPrefix = '${deviceId}_$targetId';
      _sessionClips.remove(keyPrefix);
      _clipsController.add(Map.unmodifiable(_sessionClips));

      print('Session $targetId deleted from device $deviceId');
    } else if (targetType == DeleteTargetType.clip) {
      // Remove clip from local cache
      for (final key in _sessionClips.keys) {
        if (key.startsWith(deviceId)) {
          _sessionClips[key]?.removeWhere((c) => c.clipId == targetId);
        }
      }
      _clipsController.add(Map.unmodifiable(_sessionClips));

      // Update session clip count
      for (final session in _deviceSessions[deviceId] ?? []) {
        final key = '${deviceId}_${session.sessionId}';
        final clips = _sessionClips[key];
        if (clips != null) {
          final idx = _deviceSessions[deviceId]!
              .indexWhere((s) => s.sessionId == session.sessionId);
          if (idx >= 0) {
            _deviceSessions[deviceId]![idx] =
                session.copyWith(clipCount: clips.length);
          }
        }
      }
      _sessionsController.add(Map.unmodifiable(_deviceSessions));

      print('Clip $targetId deleted from device $deviceId');
    }
  }

  /// Handle delete failed from device
  void handleDeleteFailed(String deviceId, DeleteFailedMessage message) {
    print(
        'Delete failed on device $deviceId: ${message.targetType} ${message.targetId} - ${message.reason}');
  }

  // ===== Private Helpers =====

  /// Extract IP address from a URL (e.g., http://192.168.1.100:8765/path)
  String? _extractIpFromUrl(String? url) {
    if (url == null) return null;
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (e) {
      return null;
    }
  }

  void _updateClipThumbnailLoading(
    String deviceId,
    String sessionId,
    String clipId,
    bool isLoading,
  ) {
    final key = '${deviceId}_$sessionId';
    final clips = _sessionClips[key];
    if (clips == null) return;

    final idx = clips.indexWhere((c) => c.clipId == clipId);
    if (idx >= 0) {
      clips[idx] = clips[idx].copyWith(isThumbnailLoading: isLoading);
      _clipsController.add(Map.unmodifiable(_sessionClips));
    }
  }

  void _updateClipThumbnailLoadingByClipId(
    String deviceId,
    String clipId,
    bool isLoading,
  ) {
    for (final key in _sessionClips.keys) {
      if (key.startsWith(deviceId)) {
        final clips = _sessionClips[key]!;
        final idx = clips.indexWhere((c) => c.clipId == clipId);
        if (idx >= 0) {
          clips[idx] = clips[idx].copyWith(isThumbnailLoading: isLoading);
          _clipsController.add(Map.unmodifiable(_sessionClips));
          return;
        }
      }
    }
  }

  void _updateClipThumbnail(
    String deviceId,
    String clipId,
    Uint8List thumbnailData,
    String url,
  ) {
    for (final key in _sessionClips.keys) {
      if (key.startsWith(deviceId)) {
        final clips = _sessionClips[key]!;
        final idx = clips.indexWhere((c) => c.clipId == clipId);
        if (idx >= 0) {
          clips[idx] = clips[idx].copyWith(
            thumbnailData: thumbnailData,
            thumbnailUrl: url,
            isThumbnailLoading: false,
          );
          _clipsController.add(Map.unmodifiable(_sessionClips));
          return;
        }
      }
    }
  }

  void _updateClipDownloading(
    String deviceId,
    String sessionId,
    String clipId,
    bool isDownloading,
  ) {
    final key = '${deviceId}_$sessionId';
    final clips = _sessionClips[key];
    if (clips == null) return;

    final idx = clips.indexWhere((c) => c.clipId == clipId);
    if (idx >= 0) {
      clips[idx] = clips[idx].copyWith(
        isDownloading: isDownloading,
        downloadProgress: isDownloading ? 0.0 : clips[idx].downloadProgress,
      );
      _clipsController.add(Map.unmodifiable(_sessionClips));
    }
  }

  void _updateClipProgress(
    String deviceId,
    String sessionId,
    String clipId,
    double progress,
  ) {
    final key = '${deviceId}_$sessionId';
    final clips = _sessionClips[key];
    if (clips == null) return;

    final idx = clips.indexWhere((c) => c.clipId == clipId);
    if (idx >= 0) {
      clips[idx] = clips[idx].copyWith(downloadProgress: progress);
      _clipsController.add(Map.unmodifiable(_sessionClips));
    }
  }

  void _updateClipLocalPath(
    String deviceId,
    String sessionId,
    String clipId,
    String localPath,
  ) {
    final key = '${deviceId}_$sessionId';
    final clips = _sessionClips[key];
    if (clips == null) return;

    final idx = clips.indexWhere((c) => c.clipId == clipId);
    if (idx >= 0) {
      clips[idx] = clips[idx].copyWith(
        localPath: localPath,
        downloadProgress: 1.0,
      );
      _clipsController.add(Map.unmodifiable(_sessionClips));
    }
  }

  void _updateClipError(
    String deviceId,
    String sessionId,
    String clipId,
    String error,
  ) {
    final key = '${deviceId}_$sessionId';
    final clips = _sessionClips[key];
    if (clips == null) return;

    final idx = clips.indexWhere((c) => c.clipId == clipId);
    if (idx >= 0) {
      clips[idx] = clips[idx].copyWith(errorMessage: error);
      _clipsController.add(Map.unmodifiable(_sessionClips));
    }
  }

  /// Clear all cached data
  void clearCache() {
    _deviceSessions.clear();
    _sessionClips.clear();
    _thumbnailCache.clear();
    _sessionsController.add({});
    _clipsController.add({});
  }

  /// Clear cache for a specific device
  void clearDeviceCache(String deviceId) {
    _deviceSessions.remove(deviceId);
    _sessionClips.removeWhere((key, _) => key.startsWith(deviceId));
    _sessionsController.add(Map.unmodifiable(_deviceSessions));
    _clipsController.add(Map.unmodifiable(_sessionClips));
  }

  /// Get cached thumbnail for a clip
  Uint8List? getCachedThumbnail(String clipId) => _thumbnailCache[clipId];

  /// Get downloads directory
  String get downloadsDirectory => _downloadsDirectory;

  /// Dispose resources
  Future<void> dispose() async {
    await _sessionsController.close();
    await _clipsController.close();
  }
}
