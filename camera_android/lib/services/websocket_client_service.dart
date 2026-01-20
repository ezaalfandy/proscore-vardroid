import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:var_protocol/var_protocol.dart';

/// WebSocket client for communicating with the coordinator
class WebSocketClientService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  String? _deviceId;
  String? _coordinatorHost;
  int? _coordinatorPort;

  final _messageController = StreamController<BaseMessage>.broadcast();
  final _connectionStateController = StreamController<VarConnectionState>.broadcast();

  VarConnectionState _connectionState = VarConnectionState.disconnected;

  /// Stream of received messages
  Stream<BaseMessage> get messageStream => _messageController.stream;

  /// Stream of connection state changes
  Stream<VarConnectionState> get connectionStateStream => _connectionStateController.stream;

  /// Current connection state
  VarConnectionState get connectionState => _connectionState;

  /// Initialize the WebSocket client
  void init({
    required String deviceId,
    required String host,
    required int port,
  }) {
    _deviceId = deviceId;
    _coordinatorHost = host;
    _coordinatorPort = port;
  }

  /// Connect to coordinator WebSocket
  Future<bool> connect() async {
    if (_connectionState == VarConnectionState.connected ||
        _connectionState == VarConnectionState.connecting) {
      return false;
    }

    if (_coordinatorHost == null || _coordinatorPort == null) {
      return false;
    }

    try {
      _updateConnectionState(VarConnectionState.connecting);

      final wsUrl = 'ws://$_coordinatorHost:$_coordinatorPort/ws';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      _updateConnectionState(VarConnectionState.connected);
      return true;
    } catch (e) {
      _updateConnectionState(VarConnectionState.disconnected);
      return false;
    }
  }

  /// Disconnect from coordinator
  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    _updateConnectionState(VarConnectionState.disconnected);
  }

  /// Send a message to coordinator
  void sendMessage(BaseMessage message) {
    // Allow sending when connected or paired
    if ((_connectionState != VarConnectionState.connected &&
            _connectionState != VarConnectionState.paired) ||
        _channel == null) {
      return;
    }

    try {
      final jsonString = message.toJsonString();
      _channel!.sink.add(jsonString);
    } catch (e) {
      // Handle error
    }
  }

  /// Send hello message
  void sendHello({
    required String deviceName,
    required String platform,
    required String appVersion,
    required DeviceCapabilities capabilities,
  }) {
    if (_deviceId == null) return;

    final message = HelloMessage(
      deviceId: _deviceId!,
      deviceName: deviceName,
      platform: platform,
      appVersion: appVersion,
      capabilities: capabilities,
    );

    sendMessage(message);
  }

  /// Send pair request
  void sendPairRequest({
    required String pairToken,
    required String deviceName,
  }) {
    if (_deviceId == null) return;

    final message = PairRequestMessage(
      deviceId: _deviceId!,
      pairToken: pairToken,
      deviceName: deviceName,
    );

    sendMessage(message);
  }

  /// Send auth message
  void sendAuth({
    required String deviceKey,
  }) {
    if (_deviceId == null) return;

    final message = AuthMessage(
      deviceId: _deviceId!,
      deviceKey: deviceKey,
    );

    sendMessage(message);
  }

  /// Send status update
  void sendStatus({
    String? sessionId,
    required int battery,
    required double temperature,
    required int freeSpaceMB,
    required bool isRecording,
    int? signalStrength,
  }) {
    if (_deviceId == null) return;

    final message = StatusMessage(
      deviceId: _deviceId!,
      sessionId: sessionId,
      battery: battery,
      temperature: temperature,
      freeSpaceMB: freeSpaceMB,
      isRecording: isRecording,
      signalStrength: signalStrength,
    );

    sendMessage(message);
  }

  /// Send recording started acknowledgment
  void sendRecordingStarted({
    required String sessionId,
    required int startedAt,
  }) {
    if (_deviceId == null) return;

    final message = RecordingStartedMessage(
      deviceId: _deviceId!,
      sessionId: sessionId,
      startedAt: startedAt,
    );

    sendMessage(message);
  }

  /// Send recording stopped acknowledgment
  void sendRecordingStopped({
    required String sessionId,
    required int stoppedAt,
  }) {
    if (_deviceId == null) return;

    final message = RecordingStoppedMessage(
      deviceId: _deviceId!,
      sessionId: sessionId,
      stoppedAt: stoppedAt,
    );

    sendMessage(message);
  }

  /// Send mark acknowledgment
  void sendMarkAck({
    required String sessionId,
    required String markId,
    required int deviceTs,
  }) {
    if (_deviceId == null) return;

    final message = MarkAckMessage(
      deviceId: _deviceId!,
      sessionId: sessionId,
      markId: markId,
      deviceTs: deviceTs,
    );

    sendMessage(message);
  }

  /// Send clip ready notification
  void sendClipReady({
    required String sessionId,
    required String clipId,
    required String markId,
    required String url,
    required int durationMs,
    required int sizeBytes,
  }) {
    if (_deviceId == null) return;

    final message = ClipReadyMessage(
      deviceId: _deviceId!,
      sessionId: sessionId,
      clipId: clipId,
      markId: markId,
      url: url,
      durationMs: durationMs,
      sizeBytes: sizeBytes,
    );

    sendMessage(message);
  }

  /// Send pong (time sync response)
  void sendPong({
    required int deviceTs,
  }) {
    if (_deviceId == null) return;

    final message = PongMessage(
      deviceId: _deviceId!,
      deviceTs: deviceTs,
    );

    sendMessage(message);
  }

  /// Send error message
  void sendError({
    String? sessionId,
    required String code,
    required String message,
  }) {
    if (_deviceId == null) return;

    final errorMessage = ErrorMessage(
      deviceId: _deviceId!,
      sessionId: sessionId,
      code: code,
      message: message,
    );

    sendMessage(errorMessage);
  }

  /// Send preview available message
  void sendPreviewAvailable({
    required String url,
    required int width,
    required int height,
    required int fps,
  }) {
    if (_deviceId == null) return;

    final message = PreviewAvailableMessage(
      deviceId: _deviceId!,
      url: url,
      width: width,
      height: height,
      fps: fps,
    );

    sendMessage(message);
  }

  /// Send preview stopped message
  void sendPreviewStopped() {
    if (_deviceId == null) return;

    final message = PreviewStoppedMessage(
      deviceId: _deviceId!,
    );

    sendMessage(message);
  }

  /// Send playback ready message
  void sendPlaybackReady({
    required String url,
    required int durationMs,
    required int width,
    required int height,
    required int fps,
  }) {
    if (_deviceId == null) return;

    final message = PlaybackReadyMessage(
      deviceId: _deviceId!,
      url: url,
      durationMs: durationMs,
      width: width,
      height: height,
      fps: fps,
    );

    sendMessage(message);
  }

  /// Send playback status message
  void sendPlaybackStatus({
    required int positionMs,
    required bool isPlaying,
    required double speed,
  }) {
    if (_deviceId == null) return;

    final message = PlaybackStatusMessage(
      deviceId: _deviceId!,
      positionMs: positionMs,
      isPlaying: isPlaying,
      speed: speed,
    );

    sendMessage(message);
  }

  /// Send playback stopped message
  void sendPlaybackStopped() {
    if (_deviceId == null) return;

    final message = PlaybackStoppedMessage(
      deviceId: _deviceId!,
    );

    sendMessage(message);
  }

  /// Send playback error message
  void sendPlaybackError({
    required String code,
    required String message,
  }) {
    if (_deviceId == null) return;

    final errorMessage = PlaybackErrorMessage(
      deviceId: _deviceId!,
      code: code,
      message: message,
    );

    sendMessage(errorMessage);
  }

  void _onMessage(dynamic data) {
    try {
      final message = MessageParser.parse(data as String);
      if (message != null) {
        _messageController.add(message);
      }
    } catch (e) {
      // Handle parse error
    }
  }

  void _onError(error) {
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    _updateConnectionState(VarConnectionState.error);
  }

  void _onDone() {
    _updateConnectionState(VarConnectionState.disconnected);
  }

  void _updateConnectionState(VarConnectionState state) {
    _connectionState = state;
    _connectionStateController.add(state);
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _connectionStateController.close();
  }
}

/// Connection states for VAR system
enum VarConnectionState {
  disconnected,
  connecting,
  connected,
  paired,
  error,
}
