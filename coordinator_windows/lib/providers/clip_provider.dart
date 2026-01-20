import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/clip.dart';
import '../services/clip_downloader_service.dart';

/// Provider for clips state.
class ClipProvider extends ChangeNotifier {
  final ClipDownloaderService _clipDownloaderService;

  StreamSubscription? _clipsSubscription;

  List<Clip> _clips = [];

  ClipProvider({
    required ClipDownloaderService clipDownloaderService,
  }) : _clipDownloaderService = clipDownloaderService {
    _init();
  }

  void _init() {
    // Listen to clips changes
    _clipsSubscription = _clipDownloaderService.clipsStream.listen((clips) {
      _clips = clips;
      notifyListeners();
    });

    // Load initial state
    _clips = _clipDownloaderService.currentSessionClips;
  }

  /// List of clips for current session
  List<Clip> get clips => List.unmodifiable(_clips);

  /// Number of clips
  int get clipCount => _clips.length;

  /// Number of downloaded clips
  int get downloadedCount =>
      _clips.where((c) => c.status == ClipStatus.downloaded).length;

  /// Number of pending/downloading clips
  int get pendingCount => _clips
      .where((c) =>
          c.status == ClipStatus.pending ||
          c.status == ClipStatus.requested ||
          c.status == ClipStatus.generating ||
          c.status == ClipStatus.ready ||
          c.status == ClipStatus.downloading)
      .length;

  /// Request clips from all devices for a mark.
  Future<List<Clip>> requestClipsForMark(
    String markId, {
    int preRollMs = 10000,
    int postRollMs = 5000,
  }) async {
    return await _clipDownloaderService.requestClipsFromAllDevices(
      markId: markId,
      preRollMs: preRollMs,
      postRollMs: postRollMs,
    );
  }

  /// Request a clip from a specific device.
  Future<Clip> requestClip({
    required String markId,
    required String deviceId,
    int preRollMs = 10000,
    int postRollMs = 5000,
  }) async {
    return await _clipDownloaderService.requestClip(
      markId: markId,
      deviceId: deviceId,
      preRollMs: preRollMs,
      postRollMs: postRollMs,
    );
  }

  /// Retry downloading a failed clip.
  Future<void> retryDownload(String clipId) async {
    await _clipDownloaderService.retryDownload(clipId);
  }

  /// Get download progress for a clip.
  double getDownloadProgress(String clipId) {
    return _clipDownloaderService.getDownloadProgress(clipId);
  }

  /// Load clips for the current session.
  Future<void> loadClips() async {
    await _clipDownloaderService.loadCurrentSessionClips();
  }

  /// Clear clips cache.
  void clearClips() {
    _clipDownloaderService.clearClipsCache();
  }

  /// Get clips for a specific mark.
  Future<List<Clip>> getClipsForMark(String markId) async {
    return await _clipDownloaderService.getClipsForMark(markId);
  }

  /// Get clip by ID from current clips.
  Clip? getClip(String clipId) {
    try {
      return _clips.firstWhere((c) => c.id == clipId);
    } catch (e) {
      return null;
    }
  }

  /// Open a clip in default application.
  Future<void> openClip(String clipId) async {
    await _clipDownloaderService.openClip(clipId);
  }

  /// Open clips directory.
  Future<void> openClipsDirectory() async {
    await _clipDownloaderService.openClipsDirectory();
  }

  /// Get clips directory path.
  String get clipsDirectory => _clipDownloaderService.clipsDirectory;

  @override
  void dispose() {
    _clipsSubscription?.cancel();
    super.dispose();
  }
}
