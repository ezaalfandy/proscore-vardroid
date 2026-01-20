import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:var_protocol/var_protocol.dart';
import '../services/websocket_client_service.dart';
import '../services/device_storage_service.dart';
import '../services/device_status_service.dart';

/// Provider for managing connection and pairing with coordinator
class ConnectionProvider with ChangeNotifier {
  final WebSocketClientService _wsService = WebSocketClientService();
  final DeviceStorageService _storage = DeviceStorageService();
  final DeviceStatusService _statusService = DeviceStatusService();

  StreamSubscription? _messageSubscription;
  StreamSubscription? _connectionStateSubscription;
  Timer? _statusHeartbeatTimer;
  Timer? _connectionTimeoutTimer;

  String? _deviceId;
  String? _assignedName;
  String? _currentSessionId;
  VarConnectionState _connectionState = VarConnectionState.disconnected;
  String? _errorMessage;
  bool _isReconnecting = false;

  // Last connection parameters for retry
  String? _lastHost;
  int? _lastPort;
  String? _lastToken;

  // Connection timeout duration
  static const Duration connectionTimeout = Duration(seconds: 10);

  // Getters
  VarConnectionState get connectionState => _connectionState;
  String? get deviceId => _deviceId;
  String? get assignedName => _assignedName;
  String? get currentSessionId => _currentSessionId;
  String? get errorMessage => _errorMessage;
  bool get isConnected => _connectionState == VarConnectionState.connected ||
      _connectionState == VarConnectionState.paired;
  bool get isPaired => _connectionState == VarConnectionState.paired;
  bool get isReconnecting => _isReconnecting;
  WebSocketClientService get wsService => _wsService;

  /// Initialize the provider
  Future<void> init({bool autoReconnect = true}) async {
    // Get or create device ID
    _deviceId = await _storage.getDeviceId();
    if (_deviceId == null) {
      _deviceId = const Uuid().v4();
      await _storage.setDeviceId(_deviceId!);
    }

    _assignedName = await _storage.getAssignedName();

    // Set up message listeners
    _messageSubscription = _wsService.messageStream.listen(_handleMessage);
    _connectionStateSubscription = _wsService.connectionStateStream.listen(_handleConnectionStateChange);

    notifyListeners();

    // Attempt auto-reconnect if previously paired
    if (autoReconnect) {
      await autoReconnectOnStartup();
    }
  }

  /// Connect to coordinator (QR code or manual)
  Future<bool> connectToCoordinator({
    required String host,
    required int port,
    String? pairToken,
  }) async {
    try {
      _errorMessage = null;
      _cancelConnectionTimeout();
      notifyListeners();

      // Store last connection parameters for retry
      _lastHost = host;
      _lastPort = port;
      _lastToken = pairToken;

      // Save coordinator info
      await _storage.setCoordinatorHost(host);
      await _storage.setCoordinatorPort(port);

      // Ensure clean state before reconnecting
      await _wsService.disconnect();

      // Initialize WebSocket client
      _wsService.init(
        deviceId: _deviceId!,
        host: host,
        port: port,
      );

      // Start connection timeout
      _startConnectionTimeout();

      // Connect
      final connected = await _wsService.connect();
      if (!connected) {
        _cancelConnectionTimeout();
        _errorMessage = 'Failed to connect to coordinator';
        _updateConnectionState(VarConnectionState.error);
        return false;
      }

      // Check if we have a device key (already paired)
      final deviceKey = await _storage.getDeviceKey();

      // Get device info for hello message
      final deviceInfo = await _getDeviceInfo();

      // Send hello message
      _wsService.sendHello(
        deviceName: deviceInfo['name']!,
        platform: deviceInfo['platform']!,
        appVersion: '0.1.0',
        capabilities: DeviceCapabilities(
          maxResolution: '4K',
          maxFps: 60,
          segmentRecording: true,
        ),
      );

      if (deviceKey != null) {
        // Already paired, send auth
        _wsService.sendAuth(deviceKey: deviceKey);
      } else if (pairToken != null) {
        // New pairing with token
        _wsService.sendPairRequest(
          pairToken: pairToken,
          deviceName: deviceInfo['name']!,
        );
      }

      return true;
    } catch (e) {
      _cancelConnectionTimeout();
      _errorMessage = 'Connection error: $e';
      _updateConnectionState(VarConnectionState.error);
      return false;
    }
  }

  /// Retry last connection attempt
  Future<bool> retryConnection() async {
    if (_lastHost == null || _lastPort == null) {
      // Try to get from storage
      final host = await _storage.getCoordinatorHost();
      final port = await _storage.getCoordinatorPort();
      if (host == null || port == null) {
        _errorMessage = 'No previous connection to retry';
        notifyListeners();
        return false;
      }
      _lastHost = host;
      _lastPort = port;
    }

    _isReconnecting = true;
    notifyListeners();

    final result = await connectToCoordinator(
      host: _lastHost!,
      port: _lastPort!,
      pairToken: _lastToken,
    );

    _isReconnecting = false;
    notifyListeners();

    return result;
  }

  /// Attempt auto-reconnect on app startup if previously paired
  Future<bool> autoReconnectOnStartup() async {
    final wasPaired = await _storage.isPaired();
    if (!wasPaired) return false;

    final host = await _storage.getCoordinatorHost();
    final port = await _storage.getCoordinatorPort();

    if (host == null || port == null) return false;

    _isReconnecting = true;
    notifyListeners();

    final result = await connectToCoordinator(
      host: host,
      port: port,
      // No token needed, will use stored device key
    );

    _isReconnecting = false;
    notifyListeners();

    return result;
  }

  void _startConnectionTimeout() {
    _connectionTimeoutTimer = Timer(connectionTimeout, () {
      if (_connectionState == VarConnectionState.connecting ||
          _connectionState == VarConnectionState.connected) {
        _errorMessage = 'Connection timed out';
        disconnect();
        _updateConnectionState(VarConnectionState.error);
      }
    });
  }

  void _cancelConnectionTimeout() {
    _connectionTimeoutTimer?.cancel();
    _connectionTimeoutTimer = null;
  }

  /// Disconnect from coordinator
  Future<void> disconnect() async {
    _stopStatusHeartbeat();
    await _wsService.disconnect();
    _currentSessionId = null;
    notifyListeners();
  }

  /// Unpair device (clear pairing data)
  Future<void> unpair() async {
    await disconnect();
    await _storage.clearPairingData();
    _assignedName = null;
    notifyListeners();
  }

  /// Check if device was previously paired
  Future<bool> wasPreviouslyPaired() async {
    return await _storage.isPaired();
  }

  /// Get last used coordinator info
  Future<Map<String, dynamic>?> getLastCoordinator() async {
    final host = await _storage.getCoordinatorHost();
    final port = await _storage.getCoordinatorPort();

    if (host != null && port != null) {
      return {'host': host, 'port': port};
    }
    return null;
  }

  /// Send recording started acknowledgment
  void sendRecordingStarted(String sessionId) {
    _currentSessionId = sessionId;
    _wsService.sendRecordingStarted(
      sessionId: sessionId,
      startedAt: DateTime.now().millisecondsSinceEpoch,
    );
    notifyListeners();
  }

  /// Send recording stopped acknowledgment
  void sendRecordingStopped() {
    if (_currentSessionId == null) return;

    _wsService.sendRecordingStopped(
      sessionId: _currentSessionId!,
      stoppedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Send mark acknowledgment
  void sendMarkAck(String markId) {
    if (_currentSessionId == null) return;

    _wsService.sendMarkAck(
      sessionId: _currentSessionId!,
      markId: markId,
      deviceTs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Send clip ready notification
  void sendClipReady({
    required String clipId,
    required String markId,
    required String url,
    required int durationMs,
    required int sizeBytes,
  }) {
    if (_currentSessionId == null) return;

    _wsService.sendClipReady(
      sessionId: _currentSessionId!,
      clipId: clipId,
      markId: markId,
      url: url,
      durationMs: durationMs,
      sizeBytes: sizeBytes,
    );
  }

  /// Send error message
  void sendError({
    required String code,
    required String message,
  }) {
    _wsService.sendError(
      sessionId: _currentSessionId,
      code: code,
      message: message,
    );
  }

  void _handleMessage(BaseMessage message) {
    switch (message.type) {
      case VarProtocol.msgPairAccept:
        _handlePairAccept(message as PairAcceptMessage);
        break;
      case VarProtocol.msgPairReject:
        _handlePairReject(message as PairRejectMessage);
        break;
      case VarProtocol.msgAuthOk:
        _handleAuthOk(message as AuthOkMessage);
        break;
      case VarProtocol.msgAuthFailed:
        _handleAuthFailed(message as AuthFailedMessage);
        break;
      case VarProtocol.msgPing:
        _handlePing(message as PingMessage);
        break;
      case VarProtocol.msgDisconnect:
        _handleDisconnect(message as DisconnectMessage);
        break;
      // Preview messages are handled but forwarded via callback
      case VarProtocol.msgStartPreview:
      case VarProtocol.msgStopPreview:
        // These are handled by PreviewProvider via the message stream
        break;
      // Other message types are handled by respective providers
      default:
        break;
    }
  }

  void _handlePairAccept(PairAcceptMessage message) async {
    _cancelConnectionTimeout();
    _errorMessage = null;
    await _storage.setDeviceKey(message.deviceKey);
    await _storage.setAssignedName(message.assignedName);
    _assignedName = message.assignedName;
    _updateConnectionState(VarConnectionState.paired);
    _startStatusHeartbeat();
    await _sendStatus();
  }

  void _handlePairReject(PairRejectMessage message) {
    _cancelConnectionTimeout();
    _errorMessage = 'Pairing rejected: ${message.reason}';
    _updateConnectionState(VarConnectionState.error);
    disconnect();
  }

  void _handleAuthOk(AuthOkMessage message) async {
    _cancelConnectionTimeout();
    _errorMessage = null;
    await _storage.setAssignedName(message.assignedName);
    _assignedName = message.assignedName;
    _updateConnectionState(VarConnectionState.paired);
    _startStatusHeartbeat();
    await _sendStatus();
  }

  void _handleAuthFailed(AuthFailedMessage message) async {
    _cancelConnectionTimeout();
    _errorMessage = 'Authentication failed: ${message.reason}';
    // Clear old pairing data
    await _storage.clearPairingData();
    _assignedName = null;
    _updateConnectionState(VarConnectionState.error);
    disconnect();
  }

  void _handlePing(PingMessage message) {
    _wsService.sendPong(
      deviceTs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  void _handleDisconnect(DisconnectMessage message) {
    _errorMessage = 'Disconnected by coordinator: ${message.reason}';
    disconnect();
  }

  void _handleConnectionStateChange(VarConnectionState state) {
    _updateConnectionState(state);

    if (state == VarConnectionState.disconnected || state == VarConnectionState.error) {
      _stopStatusHeartbeat();
    } else if (state == VarConnectionState.connected) {
      _startStatusHeartbeat();
    }
  }

  void _updateConnectionState(VarConnectionState state) {
    _connectionState = state;
    notifyListeners();
  }

  void _startStatusHeartbeat() {
    _stopStatusHeartbeat();

    _statusHeartbeatTimer = Timer.periodic(
      const Duration(milliseconds: VarProtocol.statusHeartbeatIntervalMs),
      (timer) => _sendStatus(),
    );
  }

  void _stopStatusHeartbeat() {
    _statusHeartbeatTimer?.cancel();
    _statusHeartbeatTimer = null;
  }

  Future<void> _sendStatus() async {
    if (!isConnected) return;

    final status = await _statusService.getStatus();

    print(
      'Status heartbeat battery=${status.battery} temp=${status.temperature} free=${status.freeSpaceMB} recording=${_currentSessionId != null}',
    );
    _wsService.sendStatus(
      sessionId: _currentSessionId,
      battery: status.battery,
      temperature: status.temperature,
      freeSpaceMB: status.freeSpaceMB,
      isRecording: _currentSessionId != null,
      signalStrength: null,
    );
  }

  Future<Map<String, String>> _getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return {
        'name': '${androidInfo.brand} ${androidInfo.model}',
        'platform': 'android',
      };
    } catch (e) {
      return {
        'name': 'Android Device',
        'platform': 'android',
      };
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _stopStatusHeartbeat();
    _cancelConnectionTimeout();
    _wsService.dispose();
    super.dispose();
  }
}
