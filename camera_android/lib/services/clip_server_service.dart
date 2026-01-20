import 'dart:async';
import 'dart:io';

import 'package:var_protocol/var_protocol.dart';

/// Service for serving video clip files and thumbnails over HTTP to the coordinator.
/// Unlike PlaybackServerService which streams MJPEG frames, this serves
/// the actual MP4 files for download and JPEG thumbnails for preview.
class ClipServerService {
  HttpServer? _server;
  bool _isRunning = false;
  String? _serverBaseUrl;

  /// Map of clip ID to file path
  final Map<String, String> _clips = {};

  /// Map of clip ID to thumbnail file path
  final Map<String, String> _thumbnails = {};

  /// Whether the server is running
  bool get isRunning => _isRunning;

  /// The base URL for clip downloads (e.g., http://192.168.1.5:9100)
  String? get serverBaseUrl => _serverBaseUrl;

  /// Start the clip server
  Future<bool> startServer({
    required String localIp,
    int port = VarProtocol.defaultClipPort,
  }) async {
    if (_isRunning) return true;

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _serverBaseUrl = 'http://$localIp:$port';
      _isRunning = true;

      print('Clip server started on $_serverBaseUrl');

      _server!.listen(_handleRequest);
      return true;
    } catch (e) {
      print('Failed to start clip server: $e');
      _isRunning = false;
      return false;
    }
  }

  /// Stop the clip server
  Future<void> stopServer() async {
    _isRunning = false;
    await _server?.close();
    _server = null;
    _serverBaseUrl = null;
    _clips.clear();
    _thumbnails.clear();
    print('Clip server stopped');
  }

  /// Register a clip to be served
  /// Returns the URL to download the clip
  String? registerClip({
    required String clipId,
    required String filePath,
  }) {
    if (!_isRunning || _serverBaseUrl == null) {
      print('Clip server not running, cannot register clip');
      return null;
    }

    final file = File(filePath);
    if (!file.existsSync()) {
      print('Clip file does not exist: $filePath');
      return null;
    }

    _clips[clipId] = filePath;
    final url = '$_serverBaseUrl/clips/$clipId.mp4';
    print('Registered clip $clipId -> $filePath');
    print('  URL: $url');
    return url;
  }

  /// Unregister a clip (optional cleanup)
  void unregisterClip(String clipId) {
    _clips.remove(clipId);
    print('Unregistered clip $clipId');
  }

  /// Get all registered clip IDs
  List<String> get registeredClipIds => _clips.keys.toList();

  /// Register a thumbnail to be served
  /// Returns the URL to download the thumbnail
  String? registerThumbnail({
    required String clipId,
    required String filePath,
  }) {
    if (!_isRunning || _serverBaseUrl == null) {
      print('Clip server not running, cannot register thumbnail');
      return null;
    }

    final file = File(filePath);
    if (!file.existsSync()) {
      print('Thumbnail file does not exist: $filePath');
      return null;
    }

    _thumbnails[clipId] = filePath;
    final url = '$_serverBaseUrl/thumbnails/$clipId.jpg';
    print('Registered thumbnail $clipId -> $filePath');
    print('  URL: $url');
    return url;
  }

  /// Unregister a thumbnail (optional cleanup)
  void unregisterThumbnail(String clipId) {
    _thumbnails.remove(clipId);
    print('Unregistered thumbnail $clipId');
  }

  /// Get all registered thumbnail IDs
  List<String> get registeredThumbnailIds => _thumbnails.keys.toList();

  void _handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    print('Clip server request: ${request.method} $path');

    // Enable CORS
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
    request.response.headers.set('Access-Control-Allow-Headers', '*');

    // Handle preflight
    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    // Route: GET /clips/{clipId}.mp4
    if (request.method == 'GET' && path.startsWith('/clips/')) {
      await _handleClipDownload(request);
      return;
    }

    // Route: GET /thumbnails/{clipId}.jpg
    if (request.method == 'GET' && path.startsWith('/thumbnails/')) {
      await _handleThumbnailDownload(request);
      return;
    }

    // Route: GET /status - health check
    if (request.method == 'GET' && path == '/status') {
      request.response.headers.contentType = ContentType.json;
      request.response.write('{"status":"ok","clips":${_clips.length},"thumbnails":${_thumbnails.length}}');
      await request.response.close();
      return;
    }

    // 404 for unknown routes
    request.response.statusCode = HttpStatus.notFound;
    request.response.write('Not found');
    await request.response.close();
  }

  Future<void> _handleClipDownload(HttpRequest request) async {
    final path = request.uri.path;

    // Extract clip ID from /clips/{clipId}.mp4
    final match = RegExp(r'/clips/([^/]+)\.mp4').firstMatch(path);
    if (match == null) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write('Invalid clip path');
      await request.response.close();
      return;
    }

    final clipId = match.group(1)!;
    final filePath = _clips[clipId];

    if (filePath == null) {
      print('Clip not found: $clipId');
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('Clip not found');
      await request.response.close();
      return;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      print('Clip file no longer exists: $filePath');
      _clips.remove(clipId);
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('Clip file not found');
      await request.response.close();
      return;
    }

    try {
      final fileLength = await file.length();
      print('Serving clip $clipId: $filePath ($fileLength bytes)');

      // Check for range request (partial content)
      final rangeHeader = request.headers.value('Range');
      if (rangeHeader != null) {
        await _handleRangeRequest(request, file, fileLength, rangeHeader);
      } else {
        await _handleFullDownload(request, file, fileLength);
      }
    } catch (e) {
      print('Error serving clip: $e');
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('Error serving clip');
      await request.response.close();
    }
  }

  Future<void> _handleFullDownload(
    HttpRequest request,
    File file,
    int fileLength,
  ) async {
    request.response.headers.contentType = ContentType('video', 'mp4');
    request.response.headers.contentLength = fileLength;
    request.response.headers.set('Accept-Ranges', 'bytes');

    // Stream the file
    await file.openRead().pipe(request.response);
  }

  Future<void> _handleThumbnailDownload(HttpRequest request) async {
    final path = request.uri.path;

    // Extract clip ID from /thumbnails/{clipId}.jpg
    final match = RegExp(r'/thumbnails/([^/]+)\.jpg').firstMatch(path);
    if (match == null) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write('Invalid thumbnail path');
      await request.response.close();
      return;
    }

    final clipId = match.group(1)!;
    final filePath = _thumbnails[clipId];

    if (filePath == null) {
      print('Thumbnail not found: $clipId');
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('Thumbnail not found');
      await request.response.close();
      return;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      print('Thumbnail file no longer exists: $filePath');
      _thumbnails.remove(clipId);
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('Thumbnail file not found');
      await request.response.close();
      return;
    }

    try {
      final fileLength = await file.length();
      print('Serving thumbnail $clipId: $filePath ($fileLength bytes)');

      request.response.headers.contentType = ContentType('image', 'jpeg');
      request.response.headers.contentLength = fileLength;

      // Stream the file
      await file.openRead().pipe(request.response);
    } catch (e) {
      print('Error serving thumbnail: $e');
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('Error serving thumbnail');
      await request.response.close();
    }
  }

  Future<void> _handleRangeRequest(
    HttpRequest request,
    File file,
    int fileLength,
    String rangeHeader,
  ) async {
    // Parse Range header: "bytes=0-1023" or "bytes=1024-"
    final match = RegExp(r'bytes=(\d*)-(\d*)').firstMatch(rangeHeader);
    if (match == null) {
      request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      await request.response.close();
      return;
    }

    final startStr = match.group(1);
    final endStr = match.group(2);

    int start = 0;
    int end = fileLength - 1;

    if (startStr != null && startStr.isNotEmpty) {
      start = int.parse(startStr);
    }
    if (endStr != null && endStr.isNotEmpty) {
      end = int.parse(endStr);
    }

    // Validate range
    if (start > end || start >= fileLength) {
      request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      request.response.headers.set('Content-Range', 'bytes */$fileLength');
      await request.response.close();
      return;
    }

    // Clamp end to file length
    if (end >= fileLength) {
      end = fileLength - 1;
    }

    final contentLength = end - start + 1;

    request.response.statusCode = HttpStatus.partialContent;
    request.response.headers.contentType = ContentType('video', 'mp4');
    request.response.headers.contentLength = contentLength;
    request.response.headers.set('Accept-Ranges', 'bytes');
    request.response.headers.set('Content-Range', 'bytes $start-$end/$fileLength');

    // Stream the requested range
    final fileStream = file.openRead(start, end + 1);
    await fileStream.pipe(request.response);
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stopServer();
  }
}
