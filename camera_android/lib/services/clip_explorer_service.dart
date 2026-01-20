import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:var_protocol/var_protocol.dart';

import '../models/recording_session.dart';
import 'recording_service.dart';
import 'clip_server_service.dart';
import 'websocket_client_service.dart';

/// Service for handling clip explorer requests from coordinator.
/// Allows coordinator to browse sessions, clips, thumbnails,
/// and perform delete operations on the device.
class ClipExplorerService {
  final RecordingService _recordingService;
  final ClipServerService _clipServerService;
  final WebSocketClientService _wsService;

  String? _deviceId;
  String? _thumbnailCacheDir;
  StreamSubscription? _messageSubscription;

  /// Map of clipId -> thumbnail file path (for serving)
  final Map<String, String> _thumbnailPaths = {};

  ClipExplorerService({
    required RecordingService recordingService,
    required ClipServerService clipServerService,
    required WebSocketClientService wsService,
  })  : _recordingService = recordingService,
        _clipServerService = clipServerService,
        _wsService = wsService;

  /// Initialize the service
  Future<void> init(String deviceId) async {
    _deviceId = deviceId;

    // Set up thumbnail cache directory
    final cacheDir = await getTemporaryDirectory();
    _thumbnailCacheDir = '${cacheDir.path}/var_thumbnails';
    await Directory(_thumbnailCacheDir!).create(recursive: true);

    // Listen to incoming messages from coordinator
    _messageSubscription = _wsService.messageStream.listen(_handleMessage);
  }

  /// Handle incoming messages from coordinator
  void _handleMessage(BaseMessage message) {
    switch (message.type) {
      case VarProtocol.msgListSessions:
        handleListSessions();
        break;
      case VarProtocol.msgListClips:
        final msg = message as ListClipsMessage;
        handleListClips(msg.sessionId!);
        break;
      case VarProtocol.msgGetThumbnail:
        final msg = message as GetThumbnailMessage;
        handleGetThumbnail(msg.sessionId!, msg.clipId, msg.width, msg.height);
        break;
      case VarProtocol.msgDeleteClip:
        final msg = message as DeleteClipMessage;
        handleDeleteClip(msg.sessionId!, msg.clipId);
        break;
      case VarProtocol.msgDeleteSession:
        final msg = message as DeleteSessionMessage;
        handleDeleteSession(msg.sessionId!);
        break;
    }
  }

  /// Handle list sessions request from coordinator
  Future<void> handleListSessions() async {
    if (_deviceId == null) return;

    try {
      final sessions = await _recordingService.getAllSessions();

      final sessionInfoList = sessions.map((session) {
        // Count clips in the session
        int clipCount = session.clips.length;

        // Also check clips directory for any extracted clips
        final clipsDir = Directory(session.clipsPath);
        if (clipsDir.existsSync()) {
          final clipFiles = clipsDir
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.mp4'))
              .toList();
          clipCount = clipFiles.length > clipCount ? clipFiles.length : clipCount;
        }

        return SessionInfo(
          sessionId: session.sessionId,
          eventId: session.eventId,
          matchId: session.matchId,
          startedAt: session.startedAt.millisecondsSinceEpoch,
          stoppedAt: session.stoppedAt?.millisecondsSinceEpoch,
          videoDurationMs: session.videoDurationMs,
          clipCount: clipCount,
          videoPath: session.videoPath,
        );
      }).toList();

      _wsService.sendMessage(SessionsListMessage(
        deviceId: _deviceId!,
        sessions: sessionInfoList,
      ));
    } catch (e) {
      print('Error listing sessions: $e');
      _wsService.sendError(
        code: VarErrorCode.invalidCommand,
        message: 'Failed to list sessions: $e',
      );
    }
  }

  /// Handle list clips request for a specific session
  Future<void> handleListClips(String sessionId) async {
    if (_deviceId == null) return;

    try {
      final session = await _findSessionById(sessionId);
      if (session == null) {
        _wsService.sendError(
          code: VarErrorCode.fileNotFound,
          message: 'Session not found: $sessionId',
        );
        return;
      }

      final clipInfoList = <ClipInfo>[];

      // Get clips from session data
      for (final clip in session.clips) {
        final clipFile = File(clip.filePath);
        if (await clipFile.exists()) {
          clipInfoList.add(ClipInfo(
            clipId: clip.clipId,
            markId: clip.markId,
            durationMs: clip.durationMs,
            sizeBytes: clip.sizeBytes,
            createdAt: clip.createdAt.millisecondsSinceEpoch,
            filePath: clip.filePath,
          ));
        }
      }

      // Also scan clips directory for any clips not in manifest
      final clipsDir = Directory(session.clipsPath);
      if (await clipsDir.exists()) {
        await for (final entity in clipsDir.list()) {
          if (entity is File && entity.path.endsWith('.mp4')) {
            // Check if already in list
            final alreadyListed = clipInfoList.any(
              (c) => c.filePath == entity.path,
            );
            if (!alreadyListed) {
              final stat = await entity.stat();
              // Extract clip ID from filename: clip_markId_timestamp.mp4
              final fileName = entity.path.split('/').last;
              final clipId = fileName.replaceAll('.mp4', '');
              String markId = 'unknown';

              // Try to extract mark ID from filename
              final match = RegExp(r'clip_([^_]+)_').firstMatch(fileName);
              if (match != null) {
                markId = match.group(1)!;
              }

              clipInfoList.add(ClipInfo(
                clipId: clipId,
                markId: markId,
                durationMs: 0, // Unknown without probing
                sizeBytes: stat.size,
                createdAt: stat.modified.millisecondsSinceEpoch,
                filePath: entity.path,
              ));
            }
          }
        }
      }

      // Sort by creation time (newest first)
      clipInfoList.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _wsService.sendMessage(ClipsListMessage(
        deviceId: _deviceId!,
        sessionId: sessionId,
        clips: clipInfoList,
        videoPath: session.videoPath,
        videoDurationMs: session.videoDurationMs,
      ));
    } catch (e) {
      print('Error listing clips: $e');
      _wsService.sendError(
        sessionId: sessionId,
        code: VarErrorCode.invalidCommand,
        message: 'Failed to list clips: $e',
      );
    }
  }

  /// Handle get thumbnail request
  Future<void> handleGetThumbnail(
    String sessionId,
    String clipId,
    int? width,
    int? height,
  ) async {
    if (_deviceId == null || _thumbnailCacheDir == null) return;

    final thumbWidth = width ?? VarProtocol.defaultThumbnailWidth;
    final thumbHeight = height ?? VarProtocol.defaultThumbnailHeight;

    try {
      // Find the clip file
      String? clipPath;
      final session = await _findSessionById(sessionId);
      if (session != null) {
        // Check in session clips
        final clip = session.clips.where((c) => c.clipId == clipId).firstOrNull;
        if (clip != null) {
          clipPath = clip.filePath;
        }

        // Also check clips directory
        if (clipPath == null) {
          final clipsDir = Directory(session.clipsPath);
          if (await clipsDir.exists()) {
            await for (final entity in clipsDir.list()) {
              if (entity is File && entity.path.contains(clipId)) {
                clipPath = entity.path;
                break;
              }
            }
          }
        }
      }

      if (clipPath == null || !File(clipPath).existsSync()) {
        _wsService.sendError(
          code: VarErrorCode.fileNotFound,
          message: 'Clip not found: $clipId',
        );
        return;
      }

      // Generate thumbnail
      final thumbnailPath =
          '$_thumbnailCacheDir/${clipId}_${thumbWidth}x$thumbHeight.jpg';

      // Check if thumbnail already exists
      if (!File(thumbnailPath).existsSync()) {
        final success = await _generateThumbnail(
          clipPath,
          thumbnailPath,
          thumbWidth,
          thumbHeight,
        );

        if (!success) {
          _wsService.sendError(
            code: VarErrorCode.clipExportFailed,
            message: 'Failed to generate thumbnail for clip: $clipId',
          );
          return;
        }
      }

      // Register thumbnail for serving
      final url = _clipServerService.registerThumbnail(
        clipId: clipId,
        filePath: thumbnailPath,
      );

      if (url == null) {
        _wsService.sendError(
          code: VarErrorCode.clipExportFailed,
          message: 'Failed to register thumbnail for serving',
        );
        return;
      }

      _thumbnailPaths[clipId] = thumbnailPath;

      _wsService.sendMessage(ThumbnailReadyMessage(
        deviceId: _deviceId!,
        clipId: clipId,
        url: url,
        width: thumbWidth,
        height: thumbHeight,
      ));
    } catch (e) {
      print('Error generating thumbnail: $e');
      _wsService.sendError(
        code: VarErrorCode.clipExportFailed,
        message: 'Failed to generate thumbnail: $e',
      );
    }
  }

  /// Handle delete clip request
  Future<void> handleDeleteClip(String sessionId, String clipId) async {
    if (_deviceId == null) return;

    try {
      final session = await _findSessionById(sessionId);
      if (session == null) {
        _sendDeleteFailed(DeleteTargetType.clip, clipId, 'Session not found');
        return;
      }

      // Find and delete the clip file
      bool deleted = false;

      // Check in session clips list
      final clipIndex = session.clips.indexWhere((c) => c.clipId == clipId);
      if (clipIndex >= 0) {
        final clip = session.clips[clipIndex];
        final clipFile = File(clip.filePath);
        if (await clipFile.exists()) {
          await clipFile.delete();
          deleted = true;
        }
        session.clips.removeAt(clipIndex);
        await session.saveManifest();
      }

      // Also search clips directory
      final clipsDir = Directory(session.clipsPath);
      if (await clipsDir.exists()) {
        await for (final entity in clipsDir.list()) {
          if (entity is File && entity.path.contains(clipId)) {
            await entity.delete();
            deleted = true;
          }
        }
      }

      // Delete thumbnail if exists
      final thumbnailPath = _thumbnailPaths[clipId];
      if (thumbnailPath != null) {
        final thumbFile = File(thumbnailPath);
        if (await thumbFile.exists()) {
          await thumbFile.delete();
        }
        _thumbnailPaths.remove(clipId);
        _clipServerService.unregisterThumbnail(clipId);
      }

      if (deleted) {
        _sendDeleteConfirm(DeleteTargetType.clip, clipId);
      } else {
        _sendDeleteFailed(DeleteTargetType.clip, clipId, 'Clip file not found');
      }
    } catch (e) {
      print('Error deleting clip: $e');
      _sendDeleteFailed(DeleteTargetType.clip, clipId, 'Delete failed: $e');
    }
  }

  /// Handle delete session request
  Future<void> handleDeleteSession(String sessionId) async {
    if (_deviceId == null) return;

    try {
      final session = await _findSessionById(sessionId);
      if (session == null) {
        _sendDeleteFailed(
          DeleteTargetType.session,
          sessionId,
          'Session not found',
        );
        return;
      }

      // Delete thumbnails for clips in this session
      for (final clip in session.clips) {
        final thumbnailPath = _thumbnailPaths[clip.clipId];
        if (thumbnailPath != null) {
          final thumbFile = File(thumbnailPath);
          if (await thumbFile.exists()) {
            await thumbFile.delete();
          }
          _thumbnailPaths.remove(clip.clipId);
          _clipServerService.unregisterThumbnail(clip.clipId);
        }
      }

      // Delete session folder
      final success = await _recordingService.deleteSession(session);

      if (success) {
        _sendDeleteConfirm(DeleteTargetType.session, sessionId);
      } else {
        _sendDeleteFailed(
          DeleteTargetType.session,
          sessionId,
          'Failed to delete session folder',
        );
      }
    } catch (e) {
      print('Error deleting session: $e');
      _sendDeleteFailed(
        DeleteTargetType.session,
        sessionId,
        'Delete failed: $e',
      );
    }
  }

  /// Generate thumbnail from video using FFmpeg
  Future<bool> _generateThumbnail(
    String videoPath,
    String outputPath,
    int width,
    int height,
  ) async {
    try {
      // Extract frame at 1 second (or first frame if video is shorter)
      final cmd =
          '-y -ss 1 -i "$videoPath" -vframes 1 -vf "scale=$width:$height:force_original_aspect_ratio=decrease,pad=$width:$height:(ow-iw)/2:(oh-ih)/2" -q:v 2 "$outputPath"';

      final session = await FFmpegKit.execute(cmd);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        return File(outputPath).existsSync();
      }

      // Fallback: try extracting first frame
      final fallbackCmd =
          '-y -i "$videoPath" -vframes 1 -vf "scale=$width:$height:force_original_aspect_ratio=decrease,pad=$width:$height:(ow-iw)/2:(oh-ih)/2" -q:v 2 "$outputPath"';

      final fallbackSession = await FFmpegKit.execute(fallbackCmd);
      final fallbackRc = await fallbackSession.getReturnCode();

      return ReturnCode.isSuccess(fallbackRc) && File(outputPath).existsSync();
    } catch (e) {
      print('Thumbnail generation error: $e');
      return false;
    }
  }

  /// Find session by ID from all sessions
  Future<RecordingSession?> _findSessionById(String sessionId) async {
    final sessions = await _recordingService.getAllSessions();
    return sessions.where((s) => s.sessionId == sessionId).firstOrNull;
  }

  void _sendDeleteConfirm(String targetType, String targetId) {
    if (_deviceId == null) return;

    _wsService.sendMessage(DeleteConfirmMessage(
      deviceId: _deviceId!,
      targetType: targetType,
      targetId: targetId,
    ));
  }

  void _sendDeleteFailed(String targetType, String targetId, String reason) {
    if (_deviceId == null) return;

    _wsService.sendMessage(DeleteFailedMessage(
      deviceId: _deviceId!,
      targetType: targetType,
      targetId: targetId,
      reason: reason,
    ));
  }

  /// Clear thumbnail cache
  Future<void> clearThumbnailCache() async {
    if (_thumbnailCacheDir == null) return;

    try {
      final cacheDir = Directory(_thumbnailCacheDir!);
      if (await cacheDir.exists()) {
        await for (final entity in cacheDir.list()) {
          if (entity is File) {
            await entity.delete();
          }
        }
      }
      _thumbnailPaths.clear();
    } catch (e) {
      print('Error clearing thumbnail cache: $e');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _messageSubscription?.cancel();
    _messageSubscription = null;
    await clearThumbnailCache();
  }
}
