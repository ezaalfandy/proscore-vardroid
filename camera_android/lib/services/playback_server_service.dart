import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:var_protocol/var_protocol.dart';

/// Service for streaming recorded video playback to the coordinator.
/// Extracts frames from MP4 using FFmpeg and streams as MJPEG.
class PlaybackServerService {
  HttpServer? _server;

  final List<HttpResponse> _clients = [];
  Timer? _frameTimer;
  Timer? _statusTimer;

  // Playback state
  String? _filePath;
  int _durationMs = 0;
  int _positionMs = 0;
  double _speed = 1.0;
  bool _isPlaying = false;
  int _quality = VarProtocol.playbackQualityMedium;
  int _fps = 30;
  int _width = 0;
  int _height = 0;

  bool _isStreaming = false;
  String? _serverUrl;
  String? _tempFrameDir;

  // Frame state
  Uint8List? _latestFrame;
  int _currentFrameIndex = 0;
  bool _processingFrame = false;

  /// Callback for sending status updates to coordinator
  Function(int positionMs, bool isPlaying, double speed)? onStatusUpdate;

  /// Whether playback server is running
  bool get isStreaming => _isStreaming;

  /// The URL to access the MJPEG stream
  String? get serverUrl => _serverUrl;

  /// Video duration in milliseconds
  int get durationMs => _durationMs;

  /// Current position in milliseconds
  int get positionMs => _positionMs;

  /// Whether currently playing
  bool get isPlaying => _isPlaying;

  /// Current playback speed
  double get speed => _speed;

  /// Video dimensions
  int get width => _width;
  int get height => _height;
  int get fps => _fps;

  /// Start playback server for a video file
  Future<String?> startServer({
    required String filePath,
    required String localIp,
    int port = VarProtocol.defaultPlaybackPort,
    int quality = VarProtocol.playbackQualityMedium,
    int positionMs = 0,
    double speed = 1.0,
  }) async {
    // Stop any existing playback
    await stopServer();

    _filePath = filePath;
    _quality = quality;
    _positionMs = positionMs;
    _speed = speed;

    // Verify file exists
    final file = File(filePath);
    if (!await file.exists()) {
      print('Playback file not found: $filePath');
      return null;
    }

    try {
      // Get video info using FFprobe
      final videoInfo = await _getVideoInfo(filePath);
      if (videoInfo == null) {
        print('Failed to get video info');
        return null;
      }

      _durationMs = videoInfo['duration'] as int;
      _width = videoInfo['width'] as int;
      _height = videoInfo['height'] as int;
      _fps = videoInfo['fps'] as int;

      // Create temp directory for frames
      final tempDir = await getTemporaryDirectory();
      _tempFrameDir = p.join(tempDir.path, 'playback_frames');
      final frameDir = Directory(_tempFrameDir!);
      if (await frameDir.exists()) {
        await frameDir.delete(recursive: true);
      }
      await frameDir.create(recursive: true);

      // Start HTTP server
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _serverUrl = 'http://$localIp:$port/playback';
      _isStreaming = true;

      print('Playback server started on $_serverUrl');
      print('  File: $filePath');
      print('  Duration: ${_durationMs}ms, Size: ${_width}x$_height, FPS: $_fps');

      // Handle incoming connections
      _server!.listen(_handleRequest);

      // Extract first frame
      await _extractFrame(_positionMs);

      // Start status update timer (every 500ms)
      _startStatusUpdater();

      return _serverUrl;
    } catch (e) {
      print('Failed to start playback server: $e');
      _isStreaming = false;
      return null;
    }
  }

  /// Stop the playback server
  Future<void> stopServer() async {
    _isStreaming = false;
    _isPlaying = false;

    // Stop timers
    _frameTimer?.cancel();
    _frameTimer = null;
    _statusTimer?.cancel();
    _statusTimer = null;

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

    // Clean up temp directory
    if (_tempFrameDir != null) {
      try {
        final dir = Directory(_tempFrameDir!);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } catch (_) {}
      _tempFrameDir = null;
    }

    _filePath = null;
    _positionMs = 0;

    print('Playback server stopped');
  }

  void _handleRequest(HttpRequest request) async {
    if (request.uri.path == '/playback') {
      // MJPEG stream endpoint
      request.response.headers.set('Content-Type', 'multipart/x-mixed-replace; boundary=frame');
      request.response.headers.set('Cache-Control', 'no-cache');
      request.response.headers.set('Connection', 'keep-alive');
      request.response.headers.set('Access-Control-Allow-Origin', '*');

      _clients.add(request.response);
      print('Playback client connected: ${request.connectionInfo?.remoteAddress}');

      // Send current frame immediately
      _sendFrameToClient(request.response);

      // Keep connection open until client disconnects
      request.response.done.then((_) {
        _clients.remove(request.response);
        print('Playback client disconnected');
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
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    }
  }

  /// Play the video
  Future<void> play() async {
    if (!_isStreaming || _isPlaying) return;

    _isPlaying = true;
    _startFrameTimer();
    print('Playback: playing at ${_speed}x');
  }

  /// Pause the video
  Future<void> pause() async {
    _isPlaying = false;
    _frameTimer?.cancel();
    _frameTimer = null;
    print('Playback: paused at ${_positionMs}ms');
  }

  /// Seek to position
  Future<void> seek(int positionMs) async {
    _positionMs = positionMs.clamp(0, _durationMs);
    await _extractFrame(_positionMs);
    _sendLatestFrame();
    print('Playback: seeked to ${_positionMs}ms');
  }

  /// Step forward by frames
  Future<void> stepForward({int frames = 1}) async {
    if (_isPlaying) await pause();

    final frameMs = (1000 / _fps * frames).round();
    _positionMs = (_positionMs + frameMs).clamp(0, _durationMs);
    await _extractFrame(_positionMs);
    _sendLatestFrame();
    print('Playback: stepped forward $frames frame(s) to ${_positionMs}ms');
  }

  /// Step backward by frames
  Future<void> stepBackward({int frames = 1}) async {
    if (_isPlaying) await pause();

    final frameMs = (1000 / _fps * frames).round();
    _positionMs = (_positionMs - frameMs).clamp(0, _durationMs);
    await _extractFrame(_positionMs);
    _sendLatestFrame();
    print('Playback: stepped backward $frames frame(s) to ${_positionMs}ms');
  }

  /// Set playback speed
  Future<void> setSpeed(double speed) async {
    _speed = speed.clamp(PlaybackSpeed.min, PlaybackSpeed.max);
    if (_isPlaying) {
      _frameTimer?.cancel();
      _startFrameTimer();
    }
    print('Playback: speed set to ${_speed}x');
  }

  void _startFrameTimer() {
    final intervalMs = (1000 / _fps / _speed).round();

    _frameTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) => _advanceFrame(),
    );
  }

  void _startStatusUpdater() {
    _statusTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) {
        onStatusUpdate?.call(_positionMs, _isPlaying, _speed);
      },
    );
  }

  Future<void> _advanceFrame() async {
    if (!_isStreaming || !_isPlaying) return;

    // Calculate time advancement
    final frameMs = (1000 / _fps).round();
    _positionMs += frameMs;

    // Check for end of video
    if (_positionMs >= _durationMs) {
      _positionMs = _durationMs;
      await pause();
      return;
    }

    // Extract and send frame
    await _extractFrame(_positionMs);
    _sendLatestFrame();
  }

  Future<void> _extractFrame(int positionMs) async {
    if (!_isStreaming || _filePath == null || _processingFrame) return;

    _processingFrame = true;

    try {
      // Calculate timestamp for FFmpeg
      final seconds = positionMs / 1000.0;
      final timestamp = '${seconds.toStringAsFixed(3)}';

      // Output frame path
      final framePath = p.join(_tempFrameDir!, 'frame.jpg');

      // Extract frame using FFmpeg
      // -ss: seek position (before -i for faster seeking)
      // -i: input file
      // -vframes 1: extract 1 frame
      // -q:v 2: JPEG quality (2-31, lower is better)
      // -y: overwrite output
      final command = '-ss $timestamp -i "$_filePath" -vframes 1 -q:v ${_qualityToFfmpeg()} -y "$framePath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        // Read the extracted frame
        final frameFile = File(framePath);
        if (await frameFile.exists()) {
          final bytes = await frameFile.readAsBytes();

          // Optionally resize if needed
          if (_width > 1280 || _height > 720) {
            final decoded = img.decodeImage(bytes);
            if (decoded != null) {
              final resized = img.copyResize(
                decoded,
                width: _width > _height ? 1280 : -1,
                height: _height >= _width ? 720 : -1,
                interpolation: img.Interpolation.linear,
              );
              _latestFrame = Uint8List.fromList(
                img.encodeJpg(resized, quality: _quality),
              );
            }
          } else {
            _latestFrame = bytes;
          }
        }
      } else {
        print('FFmpeg frame extraction failed: ${await session.getOutput()}');
      }
    } catch (e) {
      print('Frame extraction error: $e');
    } finally {
      _processingFrame = false;
    }
  }

  int _qualityToFfmpeg() {
    // FFmpeg quality scale: 2-31 (lower is better)
    // Map 0-100 to 31-2
    return (31 - (_quality / 100 * 29)).round().clamp(2, 31);
  }

  void _sendLatestFrame() {
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
        // Don't await flush to avoid blocking
        client.flush();
      } catch (e) {
        disconnectedClients.add(client);
      }
    }

    // Remove disconnected clients
    for (final client in disconnectedClients) {
      _clients.remove(client);
      try {
        client.close();
      } catch (_) {}
    }
  }

  void _sendFrameToClient(HttpResponse client) {
    if (_latestFrame == null) return;

    final jpegBytes = _latestFrame!;
    final header = '--frame\r\n'
        'Content-Type: image/jpeg\r\n'
        'Content-Length: ${jpegBytes.length}\r\n\r\n';

    try {
      client.add(header.codeUnits);
      client.add(jpegBytes);
      client.add('\r\n'.codeUnits);
      client.flush();
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _getVideoInfo(String filePath) async {
    try {
      final session = await FFprobeKit.getMediaInformation(filePath);
      final info = session.getMediaInformation();

      if (info == null) return null;

      final durationStr = info.getDuration();
      final streams = info.getStreams();

      // Find video stream
      Map<String, dynamic>? videoStream;
      for (final stream in streams ?? []) {
        if (stream.getType() == 'video') {
          videoStream = stream.getAllProperties();
          break;
        }
      }

      if (videoStream == null) return null;

      // Parse FPS from r_frame_rate (e.g., "30/1" or "30000/1001")
      int fps = 30;
      final frameRate = videoStream['r_frame_rate'] as String?;
      if (frameRate != null && frameRate.contains('/')) {
        final parts = frameRate.split('/');
        if (parts.length == 2) {
          final num = int.tryParse(parts[0]) ?? 30;
          final den = int.tryParse(parts[1]) ?? 1;
          fps = den > 0 ? (num / den).round() : 30;
        }
      }

      return {
        'duration': durationStr != null ? (double.parse(durationStr) * 1000).round() : 0,
        'width': videoStream['width'] as int? ?? 1920,
        'height': videoStream['height'] as int? ?? 1080,
        'fps': fps,
      };
    } catch (e) {
      print('Failed to get video info: $e');
      return null;
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stopServer();
  }
}
