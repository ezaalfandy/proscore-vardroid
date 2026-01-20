import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:var_protocol/var_protocol.dart';

/// Service for streaming MJPEG preview to the coordinator
class PreviewServerService {
  HttpServer? _server;
  CameraController? _cameraController;

  final List<HttpResponse> _clients = [];
  Timer? _frameTimer;

  int _quality = VarProtocol.previewQualityLow;
  int _targetFps = VarProtocol.previewFpsLow;
  int _width = 640;
  int _height = 360;

  bool _isStreaming = false;
  String? _serverUrl;

  // Frame rate limiting
  DateTime _lastFrameTime = DateTime.now();
  Uint8List? _latestFrame;
  bool _processingFrame = false;

  /// Whether the preview server is running
  bool get isStreaming => _isStreaming;

  /// The URL to access the MJPEG stream
  String? get serverUrl => _serverUrl;

  /// Current preview settings
  int get quality => _quality;
  int get targetFps => _targetFps;
  int get width => _width;
  int get height => _height;

  /// Number of connected clients
  int get clientCount => _clients.length;

  /// Start the MJPEG preview server
  Future<String?> startServer({
    required CameraController cameraController,
    required String localIp,
    int port = VarProtocol.defaultPreviewPort,
    int quality = VarProtocol.previewQualityLow,
    int fps = VarProtocol.previewFpsLow,
    int width = 640,
    int height = 360,
  }) async {
    if (_isStreaming) {
      await stopServer();
    }

    _cameraController = cameraController;
    _quality = quality;
    _targetFps = fps;
    _width = width;
    _height = height;

    try {
      // Start HTTP server
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _serverUrl = 'http://$localIp:$port/preview';
      _isStreaming = true;

      print('Preview server started on $_serverUrl');

      // Handle incoming connections
      _server!.listen(_handleRequest);

      // Start frame sending timer
      _startFrameSender();

      return _serverUrl;
    } catch (e) {
      print('Failed to start preview server: $e');
      _isStreaming = false;
      return null;
    }
  }

  /// Stop the MJPEG preview server
  Future<void> stopServer() async {
    _isStreaming = false;

    // Stop frame timer
    _frameTimer?.cancel();
    _frameTimer = null;

    // Close all client connections
    for (final client in _clients) {
      try {
        await client.close();
      } catch (_) {}
    }
    _clients.clear();

    // Close server
    await _server?.close();
    _server = null;
    _serverUrl = null;
    _latestFrame = null;

    print('Preview server stopped');
  }

  void _handleRequest(HttpRequest request) async {
    if (request.uri.path == '/preview') {
      // MJPEG stream endpoint
      request.response.headers.set('Content-Type', 'multipart/x-mixed-replace; boundary=frame');
      request.response.headers.set('Cache-Control', 'no-cache');
      request.response.headers.set('Connection', 'keep-alive');
      request.response.headers.set('Access-Control-Allow-Origin', '*');

      _clients.add(request.response);
      print('Preview client connected: ${request.connectionInfo?.remoteAddress}');

      // Keep connection open until client disconnects
      request.response.done.then((_) {
        _clients.remove(request.response);
        print('Preview client disconnected');
      }).catchError((_) {
        _clients.remove(request.response);
      });
    } else if (request.uri.path == '/snapshot') {
      // Single JPEG snapshot endpoint
      request.response.headers.set('Content-Type', 'image/jpeg');
      request.response.headers.set('Cache-Control', 'no-cache');
      request.response.headers.set('Access-Control-Allow-Origin', '*');

      if (_latestFrame != null) {
        request.response.add(_latestFrame!);
      }
      await request.response.close();
    } else {
      // Return 404 for other paths
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    }
  }

  void _startFrameSender() {
    final intervalMs = (1000 / _targetFps).round();

    _frameTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) => _sendLatestFrame(),
    );
  }

  /// Process a camera image and update the latest frame
  /// This should be called from the camera image stream callback
  Future<void> processImageFrame(CameraImage cameraImage) async {
    if (!_isStreaming || _processingFrame) return;

    // Rate limit frame processing
    final now = DateTime.now();
    final minInterval = Duration(milliseconds: (1000 / _targetFps).round());
    if (now.difference(_lastFrameTime) < minInterval) {
      return;
    }

    _processingFrame = true;
    _lastFrameTime = now;

    try {
      // Convert camera image to JPEG
      final Uint8List? jpegBytes = await _convertCameraImage(cameraImage);
      if (jpegBytes != null) {
        _latestFrame = jpegBytes;
      }
    } catch (e) {
      print('Frame processing error: $e');
    } finally {
      _processingFrame = false;
    }
  }

  /// Capture a frame from the camera controller
  Future<void> captureFrame() async {
    if (!_isStreaming || _processingFrame || _cameraController == null) return;
    if (!_cameraController!.value.isInitialized) return;

    // Rate limit frame processing
    final now = DateTime.now();
    final minInterval = Duration(milliseconds: (1000 / _targetFps).round());
    if (now.difference(_lastFrameTime) < minInterval) {
      return;
    }

    _processingFrame = true;
    _lastFrameTime = now;

    try {
      // Capture image from camera
      final XFile imageFile = await _cameraController!.takePicture();
      final Uint8List imageBytes = await imageFile.readAsBytes();

      // Decode and resize image
      final img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage != null) {
        // Resize to preview dimensions
        final img.Image resizedImage = img.copyResize(
          originalImage,
          width: _width,
          height: _height,
          interpolation: img.Interpolation.linear,
        );

        // Encode as JPEG with specified quality
        _latestFrame = Uint8List.fromList(
          img.encodeJpg(resizedImage, quality: _quality),
        );
      }

      // Clean up temporary file
      try {
        await File(imageFile.path).delete();
      } catch (_) {}
    } catch (e) {
      print('Frame capture error: $e');
    } finally {
      _processingFrame = false;
    }
  }

  Future<Uint8List?> _convertCameraImage(CameraImage cameraImage) async {
    try {
      // YUV420 to RGB conversion
      final int uvRowStride = cameraImage.planes[1].bytesPerRow;
      final int uvPixelStride = cameraImage.planes[1].bytesPerPixel ?? 1;

      final image = img.Image(
        width: cameraImage.width,
        height: cameraImage.height,
      );

      for (int y = 0; y < cameraImage.height; y++) {
        for (int x = 0; x < cameraImage.width; x++) {
          final int uvIndex = uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);
          final int index = y * cameraImage.planes[0].bytesPerRow + x;

          final yVal = cameraImage.planes[0].bytes[index];
          final uVal = cameraImage.planes[1].bytes[uvIndex];
          final vVal = cameraImage.planes[2].bytes[uvIndex];

          // YUV to RGB conversion
          int r = (yVal + 1.370705 * (vVal - 128)).round().clamp(0, 255);
          int g = (yVal - 0.698001 * (vVal - 128) - 0.337633 * (uVal - 128)).round().clamp(0, 255);
          int b = (yVal + 1.732446 * (uVal - 128)).round().clamp(0, 255);

          image.setPixelRgb(x, y, r, g, b);
        }
      }

      // Resize to target dimensions
      final resized = img.copyResize(
        image,
        width: _width,
        height: _height,
        interpolation: img.Interpolation.linear,
      );

      // Encode as JPEG
      return Uint8List.fromList(img.encodeJpg(resized, quality: _quality));
    } catch (e) {
      print('Image conversion error: $e');
      return null;
    }
  }

  Future<void> _sendLatestFrame() async {
    if (!_isStreaming || _clients.isEmpty || _latestFrame == null) {
      return;
    }

    final jpegBytes = _latestFrame!;
    final header = '--frame\r\n'
        'Content-Type: image/jpeg\r\n'
        'Content-Length: ${jpegBytes.length}\r\n\r\n';

    final List<HttpResponse> disconnectedClients = [];

    for (final client in _clients) {
      try {
        client.add(header.codeUnits);
        client.add(jpegBytes);
        client.add('\r\n'.codeUnits);
        await client.flush();
      } catch (e) {
        // Client disconnected
        disconnectedClients.add(client);
      }
    }

    // Remove disconnected clients
    for (final client in disconnectedClients) {
      _clients.remove(client);
      try {
        await client.close();
      } catch (_) {}
    }
  }

  /// Update preview settings
  void updateSettings({
    int? quality,
    int? fps,
    int? width,
    int? height,
  }) {
    if (quality != null) _quality = quality;
    if (fps != null) _targetFps = fps;
    if (width != null) _width = width;
    if (height != null) _height = height;

    // Restart frame timer with new FPS
    if (_isStreaming && fps != null) {
      _frameTimer?.cancel();
      _startFrameSender();
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stopServer();
  }
}
