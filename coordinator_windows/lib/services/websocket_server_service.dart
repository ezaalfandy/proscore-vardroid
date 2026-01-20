import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:var_protocol/var_protocol.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'device_manager_service.dart';
import 'session_manager_service.dart';
import 'mark_service.dart';
import 'clip_downloader_service.dart';
import 'clip_explorer_service.dart';
import 'network_service.dart';

/// WebSocket server service for handling device connections.
class WebSocketServerService {
  final DeviceManagerService _deviceManagerService;
  final SessionManagerService _sessionManagerService;
  final MarkService _markService;
  final ClipDownloaderService _clipDownloaderService;
  final ClipExplorerService? _clipExplorerService;
  final NetworkService _networkService;

  HttpServer? _server;
  final int port;

  /// Stream controller for server state changes
  final _stateController = StreamController<ServerState>.broadcast();

  /// Stream of server state changes
  Stream<ServerState> get stateStream => _stateController.stream;

  ServerState _state = ServerState.stopped;

  /// Current server state
  ServerState get state => _state;

  /// Server address (e.g., "ws://192.168.1.100:8765/ws")
  String? _serverAddress;
  String? get serverAddress => _serverAddress;

  /// Map to track WebSocket connections by device ID
  final Map<WebSocketChannel, String?> _connectionDeviceIds = {};

  WebSocketServerService({
    required DeviceManagerService deviceManagerService,
    required SessionManagerService sessionManagerService,
    required MarkService markService,
    required ClipDownloaderService clipDownloaderService,
    ClipExplorerService? clipExplorerService,
    required NetworkService networkService,
    this.port = 8765,
  })  : _deviceManagerService = deviceManagerService,
        _sessionManagerService = sessionManagerService,
        _markService = markService,
        _clipDownloaderService = clipDownloaderService,
        _clipExplorerService = clipExplorerService,
        _networkService = networkService;

  /// Start the WebSocket server.
  Future<void> start() async {
    if (_state == ServerState.running) {
      print('Server already running');
      return;
    }

    _updateState(ServerState.starting);

    try {
      // Create WebSocket handler
      final wsHandler = webSocketHandler((WebSocketChannel webSocket) {
        _handleConnection(webSocket);
      });

      // Create shelf handler with routing
      final handler = const Pipeline()
          .addMiddleware(logRequests())
          .addHandler((Request request) {
        if (request.url.path == 'ws' || request.url.path == '') {
          return wsHandler(request);
        }
        return Response.notFound('Not Found');
      });

      // Start HTTP server
      _server = await shelf_io.serve(
        handler,
        InternetAddress.anyIPv4,
        port,
      );

      // Get server address
      final localIp = await _networkService.getPrimaryLocalIp();
      _serverAddress = 'ws://${localIp ?? 'localhost'}:$port/ws';

      _updateState(ServerState.running);
      print('WebSocket server running on $_serverAddress');
    } catch (e) {
      print('Failed to start server: $e');
      _updateState(ServerState.error);
      rethrow;
    }
  }

  /// Stop the WebSocket server.
  Future<void> stop() async {
    if (_state == ServerState.stopped) {
      return;
    }

    _updateState(ServerState.stopping);

    try {
      // Close all connections
      for (final ws in _connectionDeviceIds.keys.toList()) {
        try {
          ws.sink.close();
        } catch (e) {
          // Ignore close errors
        }
      }
      _connectionDeviceIds.clear();

      // Stop server
      await _server?.close();
      _server = null;
      _serverAddress = null;

      _updateState(ServerState.stopped);
      print('WebSocket server stopped');
    } catch (e) {
      print('Error stopping server: $e');
      _updateState(ServerState.error);
    }
  }

  /// Handle a new WebSocket connection.
  void _handleConnection(WebSocketChannel webSocket) {
    print('New WebSocket connection');
    _connectionDeviceIds[webSocket] = null;

    // Create a send function for this connection
    void sendMessage(BaseMessage message) {
      try {
        webSocket.sink.add(message.toJsonString());
      } catch (e) {
        print('Error sending message: $e');
      }
    }

    // Listen for messages
    webSocket.stream.listen(
      (data) {
        _handleMessage(data.toString(), webSocket, sendMessage);
      },
      onError: (error) {
        print('WebSocket error: $error');
        _handleDisconnection(webSocket);
      },
      onDone: () {
        print('WebSocket connection closed');
        _handleDisconnection(webSocket);
      },
    );
  }

  /// Handle an incoming message.
  void _handleMessage(
    String data,
    WebSocketChannel webSocket,
    void Function(BaseMessage) sendMessage,
  ) {
    try {
      final message = MessageParser.parse(data);
      if (message == null) {
        print('Failed to parse message: $data');
        return;
      }

      // Track device ID for this connection
      if (message.deviceId != 'coordinator') {
        _connectionDeviceIds[webSocket] = message.deviceId;
      }

      // Route message to appropriate handler
      switch (message.type) {
        case VarProtocol.msgHello:
          _deviceManagerService.handleHello(
            message as HelloMessage,
            webSocket,
            sendMessage,
          );
          break;

        case VarProtocol.msgPairRequest:
          _deviceManagerService.handlePairRequest(
            message as PairRequestMessage,
            webSocket,
            sendMessage,
          );
          break;

        case VarProtocol.msgAuth:
          _deviceManagerService.handleAuth(
            message as AuthMessage,
            webSocket,
            sendMessage,
          );
          break;

        case VarProtocol.msgStatus:
          _deviceManagerService.handleStatus(message as StatusMessage);
          break;

        case VarProtocol.msgRecordingStarted:
          _sessionManagerService.handleRecordingStarted(
            message as RecordingStartedMessage,
          );
          break;

        case VarProtocol.msgRecordingStopped:
          _sessionManagerService.handleRecordingStopped(
            message as RecordingStoppedMessage,
          );
          break;

        case VarProtocol.msgMarkAck:
          _markService.handleMarkAck(message as MarkAckMessage);
          break;

        case VarProtocol.msgClipReady:
          _clipDownloaderService.handleClipReady(message as ClipReadyMessage);
          break;

        case VarProtocol.msgPong:
          _handlePong(message as PongMessage);
          break;

        case VarProtocol.msgError:
          _handleError(message as ErrorMessage);
          break;

        case VarProtocol.msgPreviewAvailable:
          _handlePreviewAvailable(message as PreviewAvailableMessage);
          break;

        case VarProtocol.msgPreviewStopped:
          _handlePreviewStopped(message as PreviewStoppedMessage);
          break;

        case VarProtocol.msgPlaybackReady:
          _handlePlaybackReady(message as PlaybackReadyMessage);
          break;

        case VarProtocol.msgPlaybackStatus:
          _handlePlaybackStatus(message as PlaybackStatusMessage);
          break;

        case VarProtocol.msgPlaybackStopped:
          _handlePlaybackStopped(message as PlaybackStoppedMessage);
          break;

        case VarProtocol.msgPlaybackError:
          _handlePlaybackError(message as PlaybackErrorMessage);
          break;

        // Clip Explorer messages (Device to Coordinator)
        case VarProtocol.msgSessionsList:
          _handleSessionsList(message as SessionsListMessage);
          break;

        case VarProtocol.msgClipsList:
          _handleClipsList(message as ClipsListMessage);
          break;

        case VarProtocol.msgThumbnailReady:
          _handleThumbnailReady(message as ThumbnailReadyMessage);
          break;

        case VarProtocol.msgDeleteConfirm:
          _handleDeleteConfirm(message as DeleteConfirmMessage);
          break;

        case VarProtocol.msgDeleteFailed:
          _handleDeleteFailed(message as DeleteFailedMessage);
          break;

        default:
          print('Unhandled message type: ${message.type}');
      }
    } catch (e) {
      print('Error handling message: $e');
    }
  }

  /// Handle WebSocket disconnection.
  void _handleDisconnection(WebSocketChannel webSocket) {
    final deviceId = _connectionDeviceIds.remove(webSocket);
    if (deviceId != null) {
      _deviceManagerService.handleDisconnect(deviceId);
    }
  }

  /// Handle pong response (time sync).
  void _handlePong(PongMessage message) {
    // Pong message only contains deviceTs, calculate RTT from when ping was sent
    print('Pong from ${message.deviceId}: device_ts=${message.deviceTs}');
  }

  /// Handle error message from device.
  void _handleError(ErrorMessage message) {
    print('Error from ${message.deviceId}: [${message.code}] ${message.message}');
  }

  /// Handle preview available message from device.
  void _handlePreviewAvailable(PreviewAvailableMessage message) {
    print('Preview available from ${message.deviceId}: ${message.url} (${message.width}x${message.height}@${message.fps}fps)');
    _deviceManagerService.updateDevicePreview(
      message.deviceId,
      url: message.url,
      width: message.width,
      height: message.height,
      fps: message.fps,
    );
  }

  /// Handle preview stopped message from device.
  void _handlePreviewStopped(PreviewStoppedMessage message) {
    print('Preview stopped from ${message.deviceId}');
    _deviceManagerService.updateDevicePreview(message.deviceId, url: null);
  }

  // Playback message callbacks (set by PlaybackProvider)
  Function(PlaybackReadyMessage)? onPlaybackReady;
  Function(PlaybackStatusMessage)? onPlaybackStatus;
  Function(PlaybackStoppedMessage)? onPlaybackStopped;
  Function(PlaybackErrorMessage)? onPlaybackError;

  /// Handle playback ready message from device.
  void _handlePlaybackReady(PlaybackReadyMessage message) {
    print('Playback ready from ${message.deviceId}: ${message.url} (${message.width}x${message.height})');
    onPlaybackReady?.call(message);
  }

  /// Handle playback status message from device.
  void _handlePlaybackStatus(PlaybackStatusMessage message) {
    onPlaybackStatus?.call(message);
  }

  /// Handle playback stopped message from device.
  void _handlePlaybackStopped(PlaybackStoppedMessage message) {
    print('Playback stopped from ${message.deviceId}');
    onPlaybackStopped?.call(message);
  }

  /// Handle playback error message from device.
  void _handlePlaybackError(PlaybackErrorMessage message) {
    print('Playback error from ${message.deviceId}: [${message.code}] ${message.message}');
    onPlaybackError?.call(message);
  }

  // ===== Clip Explorer Message Handlers =====

  /// Handle sessions list from device.
  void _handleSessionsList(SessionsListMessage message) {
    print('Sessions list from ${message.deviceId}: ${message.sessions.length} sessions');
    _clipExplorerService?.handleSessionsList(message.deviceId, message);
  }

  /// Handle clips list from device.
  void _handleClipsList(ClipsListMessage message) {
    print('Clips list from ${message.deviceId}: ${message.clips.length} clips');
    _clipExplorerService?.handleClipsList(message.deviceId, message);
  }

  /// Handle thumbnail ready from device.
  void _handleThumbnailReady(ThumbnailReadyMessage message) {
    print('Thumbnail ready from ${message.deviceId}: ${message.clipId}');
    _clipExplorerService?.handleThumbnailReady(message.deviceId, message);
  }

  /// Handle delete confirmation from device.
  void _handleDeleteConfirm(DeleteConfirmMessage message) {
    print('Delete confirmed from ${message.deviceId}: ${message.targetType} ${message.targetId}');
    _clipExplorerService?.handleDeleteConfirm(message.deviceId, message);
  }

  /// Handle delete failed from device.
  void _handleDeleteFailed(DeleteFailedMessage message) {
    print('Delete failed from ${message.deviceId}: ${message.targetType} ${message.targetId} - ${message.reason}');
    _clipExplorerService?.handleDeleteFailed(message.deviceId, message);
  }

  /// Request playback from a specific device.
  void requestPlayback(
    String deviceId, {
    required String sessionId,
    required String filePath,
    int positionMs = 0,
    double speed = 1.0,
    int quality = 70,
  }) {
    print('Request playback from $deviceId: $filePath');
    final message = StartPlaybackMessage(
      deviceId: 'coordinator',
      sessionId: sessionId,
      filePath: filePath,
      positionMs: positionMs,
      speed: speed,
      quality: quality,
    );
    _deviceManagerService.sendToDevice(deviceId, message);
  }

  /// Stop playback from a specific device.
  void stopPlayback(String deviceId) {
    print('Stop playback for $deviceId');
    final message = StopPlaybackMessage(deviceId: 'coordinator');
    _deviceManagerService.sendToDevice(deviceId, message);
  }

  /// Seek playback on a device.
  void seekPlayback(String deviceId, int positionMs) {
    final message = PlaybackSeekMessage(
      deviceId: 'coordinator',
      positionMs: positionMs,
    );
    _deviceManagerService.sendToDevice(deviceId, message);
  }

  /// Control playback on a device.
  void controlPlayback(
    String deviceId, {
    required String action,
    double? speed,
    int? stepFrames,
  }) {
    final message = PlaybackControlMessage(
      deviceId: 'coordinator',
      action: action,
      speed: speed,
      stepFrames: stepFrames,
    );
    _deviceManagerService.sendToDevice(deviceId, message);
  }

  /// Request preview from a specific device.
  void requestPreview(String deviceId, {int quality = 30, int fps = 10, int width = 640, int height = 360}) {
    print('Request preview from $deviceId: ${width}x$height @${fps}fps q=$quality');
    final message = StartPreviewMessage(
      deviceId: 'coordinator',
      quality: quality,
      fps: fps,
      width: width,
      height: height,
    );
    _deviceManagerService.sendToDevice(deviceId, message);
  }

  /// Stop preview from a specific device.
  void stopPreview(String deviceId) {
    print('Stop preview for $deviceId');
    final message = StopPreviewMessage(deviceId: 'coordinator');
    _deviceManagerService.sendToDevice(deviceId, message);
  }

  /// Request preview from all connected devices.
  void requestPreviewFromAll({int quality = 30, int fps = 10, int width = 640, int height = 360}) {
    final message = StartPreviewMessage(
      deviceId: 'coordinator',
      quality: quality,
      fps: fps,
      width: width,
      height: height,
    );
    _deviceManagerService.broadcastToAll(message);
  }

  /// Stop preview from all connected devices.
  void stopPreviewFromAll() {
    final message = StopPreviewMessage(deviceId: 'coordinator');
    _deviceManagerService.broadcastToAll(message);
  }

  /// Send ping to all connected devices for time sync.
  void pingAllDevices() {
    final ping = PingMessage(
      deviceId: 'coordinator',
      coordinatorTs: DateTime.now().millisecondsSinceEpoch,
    );
    _deviceManagerService.broadcastToAll(ping);
  }

  void _updateState(ServerState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// Dispose resources.
  Future<void> dispose() async {
    await stop();
    await _stateController.close();
  }
}

enum ServerState {
  stopped,
  starting,
  running,
  stopping,
  error,
}
