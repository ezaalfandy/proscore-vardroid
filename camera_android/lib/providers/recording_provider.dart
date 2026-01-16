import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:var_protocol/var_protocol.dart';
import '../services/recording_service.dart';
import '../services/websocket_client_service.dart';
import '../models/recording_session.dart';
import 'connection_provider.dart';

/// Provider for managing recording functionality
class RecordingProvider with ChangeNotifier {
  final RecordingService _recordingService = RecordingService();
  final ConnectionProvider _connectionProvider;

  StreamSubscription? _messageSubscription;
  String? _errorMessage;

  RecordingProvider(this._connectionProvider) {
    _init();
  }

  // Getters
  bool get isRecording => _recordingService.isRecording;
  RecordingSession? get currentSession => _recordingService.currentSession;
  bool get isCameraInitialized => _recordingService.isCameraInitialized;
  String? get errorMessage => _errorMessage;

  RecordingService get recordingService => _recordingService;

  void _init() {
    // Listen to messages from coordinator
    _messageSubscription = _connectionProvider.wsService.messageStream.listen(_handleMessage);
  }

  /// Request camera and microphone permissions
  Future<bool> _requestCameraPermissions() async {
    try {
      // Request camera permission
      var cameraStatus = await Permission.camera.request();

      // Request microphone permission
      var micStatus = await Permission.microphone.request();

      // Check if we have what we need (granted or limited both work)
      final cameraOk = cameraStatus.isGranted || cameraStatus.isLimited;
      final micOk = micStatus.isGranted || micStatus.isLimited;

      if (!cameraOk) {
        if (cameraStatus.isPermanentlyDenied) {
          _errorMessage = 'Camera permission permanently denied. Please enable in Settings.';
        } else {
          _errorMessage = 'Camera permission required';
        }
        return false;
      }

      if (!micOk) {
        if (micStatus.isPermanentlyDenied) {
          _errorMessage = 'Microphone permission permanently denied. Please enable in Settings.';
        } else {
          _errorMessage = 'Microphone permission required';
        }
        return false;
      }

      return true;
    } catch (e) {
      // Permission check failed, but camera might still work
      return true; // Let camera initialization try anyway
    }
  }

  /// Initialize camera
  Future<bool> initializeCamera() async {
    try {
      _errorMessage = null;
      notifyListeners();

      // First, try to initialize camera directly
      // This works if permissions were already granted
      var success = await _recordingService.initializeCamera();

      if (success) {
        notifyListeners();
        return true;
      }

      // Camera init failed, try requesting permissions
      final hasPermissions = await _requestCameraPermissions();
      if (!hasPermissions) {
        notifyListeners();
        return false;
      }

      // Try again after requesting permissions
      success = await _recordingService.initializeCamera();

      if (!success) {
        _errorMessage = 'Failed to initialize camera';
      }

      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = 'Camera error: $e';
      notifyListeners();
      return false;
    }
  }

  /// Start recording (called when coordinator sends start command)
  Future<void> _startRecording({
    required String sessionId,
    required String eventId,
    required String matchId,
  }) async {
    try {
      _errorMessage = null;

      final success = await _recordingService.startRecording(
        sessionId: sessionId,
        eventId: eventId,
        matchId: matchId,
      );

      if (success) {
        // Send recording started acknowledgment
        _connectionProvider.sendRecordingStarted(sessionId);
      } else {
        _errorMessage = 'Failed to start recording';
        _connectionProvider.sendError(
          code: VarErrorCode.recordingFailed,
          message: 'Failed to start recording',
        );
      }

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Recording error: $e';
      _connectionProvider.sendError(
        code: VarErrorCode.recordingFailed,
        message: 'Recording error: $e',
      );
      notifyListeners();
    }
  }

  /// Stop recording (called when coordinator sends stop command)
  Future<void> _stopRecording() async {
    try {
      await _recordingService.stopRecording();
      _connectionProvider.sendRecordingStopped();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Stop recording error: $e';
      notifyListeners();
    }
  }

  /// Handle mark from coordinator
  Future<void> _handleMark({
    required String markId,
    required int coordinatorTs,
    String? note,
  }) async {
    try {
      await _recordingService.addMark(
        markId: markId,
        coordinatorTs: coordinatorTs,
        note: note,
      );

      // Send mark acknowledgment
      _connectionProvider.sendMarkAck(markId);

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Mark error: $e';
      notifyListeners();
    }
  }

  /// Handle clip request from coordinator
  Future<void> _handleClipRequest({
    required String markId,
    required int fromMs,
    required int toMs,
  }) async {
    try {
      final preRollMs = -fromMs; // fromMs is negative
      final postRollMs = toMs;

      final clip = await _recordingService.exportClip(
        markId: markId,
        preRollMs: preRollMs,
        postRollMs: postRollMs,
      );

      if (clip != null) {
        // Generate HTTP URL for clip
        // Note: This requires implementing the HTTP server
        // For now, we'll use a placeholder
        final clipUrl = 'http://localhost:9000/clips/${clip.clipId}.mp4';

        _connectionProvider.sendClipReady(
          clipId: clip.clipId,
          markId: markId,
          url: clipUrl,
          durationMs: clip.durationMs,
          sizeBytes: clip.sizeBytes,
        );
      } else {
        _connectionProvider.sendError(
          code: VarErrorCode.clipExportFailed,
          message: 'Failed to export clip for mark $markId',
        );
      }

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Clip export error: $e';
      _connectionProvider.sendError(
        code: VarErrorCode.clipExportFailed,
        message: 'Clip export error: $e',
      );
      notifyListeners();
    }
  }

  void _handleMessage(BaseMessage message) {
    switch (message.type) {
      case VarProtocol.msgStartRecord:
        final msg = message as StartRecordMessage;
        _startRecording(
          sessionId: msg.sessionId!,
          eventId: msg.meta.eventId,
          matchId: msg.meta.matchId,
        );
        break;

      case VarProtocol.msgStopRecord:
        _stopRecording();
        break;

      case VarProtocol.msgMark:
        final msg = message as MarkMessage;
        _handleMark(
          markId: msg.markId,
          coordinatorTs: msg.coordinatorTs,
          note: msg.note,
        );
        break;

      case VarProtocol.msgRequestClip:
        final msg = message as RequestClipMessage;
        _handleClipRequest(
          markId: msg.markId,
          fromMs: msg.fromMs,
          toMs: msg.toMs,
        );
        break;

      default:
        break;
    }
  }

  /// Manual emergency start recording (for testing or standalone use)
  /// Can record even when disconnected from coordinator
  Future<bool> emergencyStartRecording() async {
    // Create a temporary session ID
    final sessionId = 'emergency-${DateTime.now().millisecondsSinceEpoch}';

    return await _recordingService.startRecording(
      sessionId: sessionId,
      eventId: 'TEST',
      matchId: 'EMERGENCY',
    );
  }

  /// Manual emergency stop recording
  Future<void> emergencyStopRecording() async {
    await _recordingService.stopRecording();
    notifyListeners();
  }

  /// Switch between front and back camera
  Future<bool> toggleCamera() async {
    final success = await _recordingService.toggleCamera();
    notifyListeners();
    return success;
  }

  /// Switch to specific camera
  Future<bool> switchCamera(CameraDescription camera) async {
    final success = await _recordingService.switchCamera(camera);
    notifyListeners();
    return success;
  }

  /// Change video resolution
  Future<bool> changeResolution(ResolutionPreset resolution) async {
    final success = await _recordingService.changeResolution(resolution);
    notifyListeners();
    return success;
  }

  /// Change FPS
  Future<bool> changeFps(int fps) async {
    final success = await _recordingService.changeFps(fps);
    notifyListeners();
    return success;
  }

  /// Change both resolution and FPS
  Future<bool> changeVideoSettings({
    ResolutionPreset? resolution,
    int? fps,
  }) async {
    final success = await _recordingService.changeVideoSettings(
      resolution: resolution,
      fps: fps,
    );
    notifyListeners();
    return success;
  }

  /// Set zoom level
  Future<bool> setZoom(double zoom) async {
    final success = await _recordingService.setZoom(zoom);
    notifyListeners();
    return success;
  }

  /// Set exposure offset (brightness control)
  Future<bool> setExposureOffset(double offset) async {
    final success = await _recordingService.setExposureOffset(offset);
    notifyListeners();
    return success;
  }

  /// Set focus mode (auto or locked)
  Future<bool> setFocusMode(FocusMode mode) async {
    final success = await _recordingService.setFocusMode(mode);
    notifyListeners();
    return success;
  }

  /// Set focus point (tap to focus) - coordinates are normalized 0.0 to 1.0
  Future<bool> setFocusPoint(Offset point) async {
    final success = await _recordingService.setFocusPoint(point);
    notifyListeners();
    return success;
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _recordingService.disposeCamera();
    super.dispose();
  }
}
