import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/device.dart';
import '../services/device_manager_service.dart';

/// Provider for connected devices state.
class DeviceProvider extends ChangeNotifier {
  final DeviceManagerService _deviceManagerService;

  StreamSubscription? _devicesSubscription;

  List<ConnectedDevice> _connectedDevices = [];
  List<Device> _pairedDevices = [];

  DeviceProvider({
    required DeviceManagerService deviceManagerService,
  }) : _deviceManagerService = deviceManagerService {
    _init();
  }

  void _init() {
    // Listen to device list changes
    _devicesSubscription = _deviceManagerService.devicesStream.listen((devices) {
      _connectedDevices = devices;
      notifyListeners();
    });

    // Load initial state
    _connectedDevices = _deviceManagerService.connectedDevices;
  }

  /// List of currently connected devices
  List<ConnectedDevice> get connectedDevices => List.unmodifiable(_connectedDevices);

  /// List of all paired devices (from database)
  List<Device> get pairedDevices => List.unmodifiable(_pairedDevices);

  /// Number of connected devices
  int get connectedCount => _connectedDevices.length;

  /// Number of recording devices
  int get recordingCount =>
      _connectedDevices.where((d) => d.isRecording).length;

  /// Get a specific connected device by ID
  ConnectedDevice? getConnectedDevice(String deviceId) {
    try {
      return _connectedDevices.firstWhere((d) => d.id == deviceId);
    } catch (e) {
      return null;
    }
  }

  /// Check if a device is connected
  bool isDeviceConnected(String deviceId) {
    return _connectedDevices.any((d) => d.id == deviceId);
  }

  /// Load paired devices from database.
  Future<void> loadPairedDevices() async {
    _pairedDevices = await _deviceManagerService.getAllPairedDevices();
    notifyListeners();
  }

  /// Set slot name for a device.
  Future<void> setDeviceSlot(String deviceId, String slotName) async {
    await _deviceManagerService.setDeviceSlot(deviceId, slotName);
  }

  /// Remove a paired device.
  Future<void> removeDevice(String deviceId) async {
    await _deviceManagerService.removeDevice(deviceId);
    await loadPairedDevices();
  }

  /// Refresh device list.
  void refresh() {
    _connectedDevices = _deviceManagerService.connectedDevices;
    notifyListeners();
  }

  @override
  void dispose() {
    _devicesSubscription?.cancel();
    super.dispose();
  }
}
