import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/websocket_server_service.dart';
import '../services/network_service.dart';
import '../services/pairing_service.dart';
import '../models/pairing_token.dart';

/// Provider for WebSocket server state.
class ServerProvider extends ChangeNotifier {
  final WebSocketServerService _serverService;
  final NetworkService _networkService;
  final PairingService _pairingService;

  StreamSubscription? _stateSubscription;

  ServerState _state = ServerState.stopped;
  String? _serverAddress;
  String? _localIp;
  PairingToken? _currentToken;
  String? _error;

  ServerProvider({
    required WebSocketServerService serverService,
    required NetworkService networkService,
    required PairingService pairingService,
  })  : _serverService = serverService,
        _networkService = networkService,
        _pairingService = pairingService {
    _init();
  }

  void _init() {
    // Listen to server state changes
    _stateSubscription = _serverService.stateStream.listen((state) {
      _state = state;
      _serverAddress = _serverService.serverAddress;
      notifyListeners();
    });
  }

  /// Current server state
  ServerState get state => _state;

  /// Server address (e.g., "ws://192.168.1.100:8765/ws")
  String? get serverAddress => _serverAddress;

  /// Local IP address
  String? get localIp => _localIp;

  /// Current pairing token
  PairingToken? get currentToken => _currentToken;

  /// Server port
  int get port => _serverService.port;

  /// Error message (if any)
  String? get error => _error;

  /// Whether server is running
  bool get isRunning => _state == ServerState.running;

  /// QR code data URL for pairing
  String? get pairingUrl {
    if (_localIp == null || _currentToken == null) return null;
    return _networkService.generatePairingUrl(
      host: _localIp!,
      port: port,
      token: _currentToken!.token,
    );
  }

  /// Start the server.
  Future<void> startServer() async {
    try {
      _error = null;
      await _serverService.start();
      _localIp = await _networkService.getPrimaryLocalIp();
      _currentToken = await _pairingService.getCurrentToken();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Stop the server.
  Future<void> stopServer() async {
    try {
      await _serverService.stop();
      _serverAddress = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Refresh the pairing token.
  Future<void> refreshToken() async {
    _currentToken = await _pairingService.refreshToken();
    notifyListeners();
  }

  /// Get all local IP addresses.
  Future<List<String>> getLocalIpAddresses() async {
    return await _networkService.getLocalIpAddresses();
  }

  /// Request preview from a specific device.
  void requestPreview(String deviceId, {int quality = 30, int fps = 10, int width = 640, int height = 360}) {
    _serverService.requestPreview(deviceId, quality: quality, fps: fps, width: width, height: height);
  }

  /// Stop preview from a specific device.
  void stopPreview(String deviceId) {
    _serverService.stopPreview(deviceId);
  }

  /// Request preview from all connected devices.
  void requestPreviewFromAll({int quality = 30, int fps = 10, int width = 640, int height = 360}) {
    _serverService.requestPreviewFromAll(quality: quality, fps: fps, width: width, height: height);
  }

  /// Stop preview from all connected devices.
  void stopPreviewFromAll() {
    _serverService.stopPreviewFromAll();
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    super.dispose();
  }
}
