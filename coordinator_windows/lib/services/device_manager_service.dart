import 'dart:async';

import 'package:var_protocol/var_protocol.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/device.dart';
import 'database_service.dart';
import 'pairing_service.dart';

/// Service for managing connected devices.
class DeviceManagerService {
  final DatabaseService _databaseService;
  final PairingService _pairingService;

  /// Map of device ID to connected device state
  final Map<String, ConnectedDevice> _connectedDevices = {};

  /// Stream controller for device list changes
  final _devicesController = StreamController<List<ConnectedDevice>>.broadcast();

  /// Stream of connected devices updates
  Stream<List<ConnectedDevice>> get devicesStream => _devicesController.stream;

  /// Get current list of connected devices
  List<ConnectedDevice> get connectedDevices => _connectedDevices.values.toList();

  DeviceManagerService({
    required DatabaseService databaseService,
    required PairingService pairingService,
  })  : _databaseService = databaseService,
        _pairingService = pairingService;

  /// Handle a hello message from a new device.
  Future<void> handleHello(
    HelloMessage message,
    WebSocketChannel webSocket,
    void Function(BaseMessage) sendMessage,
  ) async {
    print('Received hello from device: ${message.deviceId}');
    // Hello is just an introduction, device will follow with pair_request or auth
  }

  /// Handle a pairing request from a device.
  Future<void> handlePairRequest(
    PairRequestMessage message,
    WebSocketChannel webSocket,
    void Function(BaseMessage) sendMessage,
  ) async {
    print('Received pair request with token: ${message.pairToken}');

    // Validate the token
    final token = await _pairingService.validateToken(message.pairToken);

    if (token == null) {
      // Token invalid - send rejection
      sendMessage(PairRejectMessage(
        deviceId: 'coordinator',
        reason: 'Invalid or expired pairing token',
      ));
      return;
    }

    // Generate device credentials
    // Use the device's own ID (from their hello/pair_request message)
    final deviceKey = _pairingService.generateDeviceKey();
    final assignedName = await _pairingService.generateAssignedName();

    // Create device record - use the device's own ID so we can track it
    final device = Device(
      id: message.deviceId,
      deviceKey: deviceKey,
      assignedName: assignedName,
      deviceName: message.deviceName,
      pairedAt: DateTime.now(),
      lastSeenAt: DateTime.now(),
      isActive: true,
    );

    // Store in database
    await _databaseService.insertDevice(device);

    // Mark token as used
    await _pairingService.markTokenUsed(message.pairToken);

    // Add to connected devices
    final connectedDevice = ConnectedDevice(
      device: device,
      webSocket: webSocket,
      state: DeviceRuntimeState.paired,
    );
    _connectedDevices[message.deviceId] = connectedDevice;

    // Notify listeners
    _notifyDevicesChanged();

    // Send acceptance (deviceId is 'coordinator' as sender)
    sendMessage(PairAcceptMessage(
      deviceId: 'coordinator',
      deviceKey: deviceKey,
      assignedName: assignedName,
    ));

    print('Device paired successfully: $assignedName (${message.deviceId})');
  }

  /// Handle an authentication request from a previously paired device.
  Future<void> handleAuth(
    AuthMessage message,
    WebSocketChannel webSocket,
    void Function(BaseMessage) sendMessage,
  ) async {
    print('Received auth request from device: ${message.deviceId}');

    // Look up device by key
    var device = await _databaseService.getDeviceByKey(message.deviceKey);

    if (device == null) {
      // Device not found
      sendMessage(AuthFailedMessage(
        deviceId: 'coordinator',
        reason: 'Device not recognized',
      ));
      return;
    }

    if (device.id != message.deviceId) {
      print(
        'Device ID changed for key ${message.deviceKey}: ${device.id} -> ${message.deviceId}',
      );
      final updatedDevice = device.copyWith(
        id: message.deviceId,
        lastSeenAt: DateTime.now(),
        isActive: true,
      );
      await _databaseService.insertDevice(updatedDevice);
      _connectedDevices.remove(device.id);
      device = updatedDevice;
    }

    // Update last seen
    await _databaseService.updateDeviceLastSeen(device.id);

    // Add to connected devices
    final connectedDevice = ConnectedDevice(
      device: device.copyWith(isActive: true, lastSeenAt: DateTime.now()),
      webSocket: webSocket,
      state: DeviceRuntimeState.paired,
    );
    _connectedDevices[device.id] = connectedDevice;

    // Notify listeners
    _notifyDevicesChanged();

    // Send success
    sendMessage(AuthOkMessage(
      deviceId: 'coordinator',
      assignedName: device.assignedName,
    ));

    print('Device authenticated: ${device.assignedName} (${device.id})');
  }

  /// Handle a status update from a device.
  void handleStatus(StatusMessage message) {
    final connected = _connectedDevices[message.deviceId];
    if (connected == null) {
      print('Status from unknown device: ${message.deviceId}');
      return;
    }

    print(
      'Status from ${message.deviceId}: battery=${message.battery} temp=${message.temperature} free=${message.freeSpaceMB} recording=${message.isRecording}',
    );
    // Update runtime state
    connected.updateStatus(
      batteryLevel: message.battery,
      temperature: message.temperature,
      storageAvailableMb: message.freeSpaceMB,
      isRecording: message.isRecording,
      currentSessionId: message.sessionId,
    );

    if (message.isRecording) {
      connected.state = DeviceRuntimeState.recording;
    } else {
      connected.state = DeviceRuntimeState.paired;
    }

    // Notify listeners
    _notifyDevicesChanged();
  }

  /// Handle device disconnection.
  void handleDisconnect(String deviceId) {
    final connected = _connectedDevices.remove(deviceId);
    if (connected != null) {
      print('Device disconnected: ${connected.assignedName}');
      _notifyDevicesChanged();
    }
  }

  /// Get a connected device by ID.
  ConnectedDevice? getConnectedDevice(String deviceId) {
    return _connectedDevices[deviceId];
  }

  /// Get all recording devices.
  List<ConnectedDevice> getRecordingDevices() {
    return _connectedDevices.values
        .where((d) => d.state == DeviceRuntimeState.recording || d.isRecording)
        .toList();
  }

  /// Send a message to a specific device.
  void sendToDevice(String deviceId, BaseMessage message) {
    final connected = _connectedDevices[deviceId];
    if (connected != null) {
      try {
        (connected.webSocket as WebSocketChannel).sink.add(message.toJsonString());
      } catch (e) {
        print('Error sending to device $deviceId: $e');
      }
    }
  }

  /// Send a message to all connected devices.
  void broadcastToAll(BaseMessage message) {
    for (final connected in _connectedDevices.values) {
      try {
        (connected.webSocket as WebSocketChannel).sink.add(message.toJsonString());
      } catch (e) {
        print('Error broadcasting to ${connected.id}: $e');
      }
    }
  }

  /// Send a message to all recording devices.
  void broadcastToRecording(BaseMessage message) {
    for (final connected in getRecordingDevices()) {
      try {
        (connected.webSocket as WebSocketChannel).sink.add(message.toJsonString());
      } catch (e) {
        print('Error broadcasting to ${connected.id}: $e');
      }
    }
  }

  /// Update device recording state.
  void updateDeviceRecordingState(String deviceId, bool isRecording, String? sessionId) {
    final connected = _connectedDevices[deviceId];
    if (connected != null) {
      connected.isRecording = isRecording;
      connected.currentSessionId = sessionId;
      connected.state = isRecording ? DeviceRuntimeState.recording : DeviceRuntimeState.paired;
      _notifyDevicesChanged();
    }
  }

  /// Update device preview state.
  void updateDevicePreview(
    String deviceId, {
    String? url,
    int? width,
    int? height,
    int? fps,
  }) {
    final connected = _connectedDevices[deviceId];
    if (connected != null) {
      connected.updatePreview(
        url: url,
        width: width,
        height: height,
        fps: fps,
      );
      _notifyDevicesChanged();
    }
  }

  /// Set slot name for a device.
  Future<void> setDeviceSlot(String deviceId, String slotName) async {
    final connected = _connectedDevices[deviceId];
    if (connected != null) {
      // Update in memory
      final updatedDevice = connected.device.copyWith(slotName: slotName);
      _connectedDevices[deviceId] = ConnectedDevice(
        device: updatedDevice,
        webSocket: connected.webSocket,
        state: connected.state,
        batteryLevel: connected.batteryLevel,
        temperature: connected.temperature,
        storageAvailableMb: connected.storageAvailableMb,
        isRecording: connected.isRecording,
        currentSessionId: connected.currentSessionId,
        lastStatusAt: connected.lastStatusAt,
      );

      // Update in database
      await _databaseService.updateDevice(updatedDevice);

      // Send to device
      sendToDevice(deviceId, SetSlotMessage(
        deviceId: 'coordinator',
        slotName: slotName,
      ));

      _notifyDevicesChanged();
    }
  }

  /// Get all paired devices from database.
  Future<List<Device>> getAllPairedDevices() async {
    return await _databaseService.getAllDevices();
  }

  /// Remove a paired device.
  Future<void> removeDevice(String deviceId) async {
    // Disconnect if connected
    final connected = _connectedDevices.remove(deviceId);
    if (connected != null) {
      try {
        sendToDevice(deviceId, DisconnectMessage(
          deviceId: 'coordinator',
          reason: 'Device removed by coordinator',
        ));
        (connected.webSocket as WebSocketChannel).sink.close();
      } catch (e) {
        print('Error disconnecting device: $e');
      }
    }

    // Remove from database
    await _databaseService.deleteDevice(deviceId);
    _notifyDevicesChanged();
  }

  void _notifyDevicesChanged() {
    _devicesController.add(_connectedDevices.values.toList());
  }

  /// Dispose resources.
  void dispose() {
    _devicesController.close();
  }
}
