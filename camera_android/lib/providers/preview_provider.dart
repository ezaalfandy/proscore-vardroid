import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:var_protocol/var_protocol.dart';

import '../services/network_service.dart';
import '../services/preview_server_service.dart';
import '../services/websocket_client_service.dart';

/// Provider for managing preview streaming state
class PreviewProvider with ChangeNotifier {
  final PreviewServerService _previewServer = PreviewServerService();
  final NetworkService _networkService = NetworkService();
  WebSocketClientService? _wsService;
  StreamSubscription<BaseMessage>? _messageSubscription;

  CameraController? _cameraController;
  String? _localIp;

  bool _isStreaming = false;
  String? _previewUrl;
  int _width = 640;
  int _height = 360;
  int _quality = VarProtocol.previewQualityLow;
  int _fps = VarProtocol.previewFpsLow;

  Timer? _captureTimer;
  bool _useImageStream = false;

  /// Whether preview is currently streaming
  bool get isStreaming => _isStreaming;

  /// The preview URL
  String? get previewUrl => _previewUrl;

  /// Current preview settings
  int get width => _width;
  int get height => _height;
  int get quality => _quality;
  int get fps => _fps;

  /// Number of connected clients
  int get clientCount => _previewServer.clientCount;

  /// Initialize the preview provider
  void init({
    required WebSocketClientService wsService,
    required String localIp,
  }) {
    _wsService = wsService;
    _localIp = localIp;
    print('PreviewProvider init: localIp=$_localIp');
    _attachMessageListener();
  }

  /// Set the camera controller for capturing frames
  void setCameraController(CameraController? controller) {
    if (_cameraController == controller) return;
    _cameraController = controller;
    if (controller != null) {
      print('PreviewProvider camera controller set');
    }
  }

  /// Attach connection updates and preview commands.
  void attachConnection(WebSocketClientService wsService) {
    if (_wsService == wsService) return;
    _wsService = wsService;
    _attachMessageListener();
  }

  void _attachMessageListener() {
    _messageSubscription?.cancel();
    _messageSubscription = _wsService?.messageStream.listen(_handleMessage);
    print('PreviewProvider message listener attached');
  }

  void _handleMessage(BaseMessage message) {
    switch (message.type) {
      case VarProtocol.msgStartPreview:
        print('PreviewProvider received start_preview');
        handleStartPreview(message as StartPreviewMessage);
        break;
      case VarProtocol.msgStopPreview:
        print('PreviewProvider received stop_preview');
        handleStopPreview(message as StopPreviewMessage);
        break;
      default:
        break;
    }
  }

  Future<bool> _ensureLocalIp() async {
    if (_localIp != null) return true;
    _localIp = await _networkService.getLocalIp();
    print('PreviewProvider resolved localIp=$_localIp');
    return _localIp != null;
  }

  /// Start preview streaming
  Future<bool> startPreview({
    int? quality,
    int? fps,
    int? width,
    int? height,
  }) async {
    if (_isStreaming || _cameraController == null) {
      print('startPreview ignored: streaming=$_isStreaming controller=$_cameraController');
      return false;
    }

    if (!await _ensureLocalIp()) {
      print('startPreview failed: no local IP');
      return false;
    }

    // Update settings if provided
    if (quality != null) _quality = quality;
    if (fps != null) _fps = fps;
    if (width != null) _width = width;
    if (height != null) _height = height;

    try {
      print('startPreview starting server: ${_width}x$_height @${_fps}fps q=$_quality');
      final url = await _previewServer.startServer(
        cameraController: _cameraController!,
        localIp: _localIp!,
        port: VarProtocol.defaultPreviewPort,
        quality: _quality,
        fps: _fps,
        width: _width,
        height: _height,
      );

      if (url == null) {
        print('startPreview failed: server url is null');
        return false;
      }

      _previewUrl = url;
      _isStreaming = true;

      // Start image stream if possible; otherwise fall back to capture timer.
      _useImageStream = await _startImageStream();
      print('startPreview imageStream=${_useImageStream ? 'on' : 'off'}');
      if (!_useImageStream) {
        _startFrameCapture();
      }

      // Notify coordinator that preview is available
      _wsService?.sendPreviewAvailable(
        url: url,
        width: _width,
        height: _height,
        fps: _fps,
      );
      print('startPreview available url=$url');

      notifyListeners();
      return true;
    } catch (e) {
      print('Failed to start preview: $e');
      return false;
    }
  }

  /// Stop preview streaming
  Future<void> stopPreview() async {
    if (!_isStreaming) return;
    print('stopPreview');

    // Stop frame capture
    _captureTimer?.cancel();
    _captureTimer = null;
    await _stopImageStream();

    // Stop server
    await _previewServer.stopServer();

    _isStreaming = false;
    _previewUrl = null;

    // Notify coordinator that preview stopped
    _wsService?.sendPreviewStopped();

    notifyListeners();
  }

  void _startFrameCapture() {
    final intervalMs = (1000 / _fps).round();

    _captureTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) => _captureFrame(),
    );
  }

  Future<void> _captureFrame() async {
    if (!_isStreaming) return;
    await _previewServer.captureFrame();
  }

  Future<bool> _startImageStream() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      print('startImageStream skipped: controller not ready');
      return false;
    }

    if (controller.value.isStreamingImages) {
      return true;
    }

    if (controller.value.isRecordingVideo) {
      print('startImageStream skipped: recording video');
      return false;
    }

    try {
      await controller.startImageStream((image) {
        _previewServer.processImageFrame(image);
      });
      print('startImageStream started');
      return true;
    } catch (_) {
      print('startImageStream failed');
      return false;
    }
  }

  Future<void> _stopImageStream() async {
    if (!_useImageStream) return;
    final controller = _cameraController;
    _useImageStream = false;
    if (controller != null && controller.value.isStreamingImages) {
      try {
        await controller.stopImageStream();
      } catch (_) {}
    }
  }

  /// Handle start preview command from coordinator
  Future<void> handleStartPreview(StartPreviewMessage message) async {
    await startPreview(
      quality: message.quality,
      fps: message.fps,
      width: message.width,
      height: message.height,
    );
  }

  /// Handle stop preview command from coordinator
  Future<void> handleStopPreview(StopPreviewMessage message) async {
    await stopPreview();
  }

  /// Update preview settings
  void updateSettings({
    int? quality,
    int? fps,
    int? width,
    int? height,
  }) {
    if (quality != null) _quality = quality;
    if (fps != null) _fps = fps;
    if (width != null) _width = width;
    if (height != null) _height = height;

    if (_isStreaming) {
      _previewServer.updateSettings(
        quality: quality,
        fps: fps,
        width: width,
        height: height,
      );

      // Restart capture timer if fps changed
      if (!_useImageStream && fps != null) {
        _captureTimer?.cancel();
        _startFrameCapture();
      }
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _captureTimer?.cancel();
    _previewServer.dispose();
    _messageSubscription?.cancel();
    super.dispose();
  }
}
