/// Device model representing a paired camera device.
class Device {
  final String id;
  final String deviceKey;
  final String assignedName;
  final String? slotName;
  final String? deviceName;
  final String? platform;
  final String? appVersion;
  final String? maxResolution;
  final int? maxFps;
  final DateTime pairedAt;
  final DateTime? lastSeenAt;
  final bool isActive;

  Device({
    required this.id,
    required this.deviceKey,
    required this.assignedName,
    this.slotName,
    this.deviceName,
    this.platform,
    this.appVersion,
    this.maxResolution,
    this.maxFps,
    required this.pairedAt,
    this.lastSeenAt,
    this.isActive = false,
  });

  /// Create from database row
  factory Device.fromMap(Map<String, dynamic> map) {
    return Device(
      id: map['id'] as String,
      deviceKey: map['device_key'] as String,
      assignedName: map['assigned_name'] as String,
      slotName: map['slot_name'] as String?,
      deviceName: map['device_name'] as String?,
      platform: map['platform'] as String?,
      appVersion: map['app_version'] as String?,
      maxResolution: map['max_resolution'] as String?,
      maxFps: map['max_fps'] as int?,
      pairedAt: DateTime.fromMillisecondsSinceEpoch(map['paired_at'] as int),
      lastSeenAt: map['last_seen_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_seen_at'] as int)
          : null,
      isActive: (map['is_active'] as int?) == 1,
    );
  }

  /// Convert to database row
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'device_key': deviceKey,
      'assigned_name': assignedName,
      'slot_name': slotName,
      'device_name': deviceName,
      'platform': platform,
      'app_version': appVersion,
      'max_resolution': maxResolution,
      'max_fps': maxFps,
      'paired_at': pairedAt.millisecondsSinceEpoch,
      'last_seen_at': lastSeenAt?.millisecondsSinceEpoch,
      'is_active': isActive ? 1 : 0,
    };
  }

  Device copyWith({
    String? id,
    String? deviceKey,
    String? assignedName,
    String? slotName,
    String? deviceName,
    String? platform,
    String? appVersion,
    String? maxResolution,
    int? maxFps,
    DateTime? pairedAt,
    DateTime? lastSeenAt,
    bool? isActive,
  }) {
    return Device(
      id: id ?? this.id,
      deviceKey: deviceKey ?? this.deviceKey,
      assignedName: assignedName ?? this.assignedName,
      slotName: slotName ?? this.slotName,
      deviceName: deviceName ?? this.deviceName,
      platform: platform ?? this.platform,
      appVersion: appVersion ?? this.appVersion,
      maxResolution: maxResolution ?? this.maxResolution,
      maxFps: maxFps ?? this.maxFps,
      pairedAt: pairedAt ?? this.pairedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() => 'Device(id: $id, name: $assignedName, active: $isActive)';
}

/// Runtime device state (not persisted)
class ConnectedDevice {
  final Device device;
  final dynamic webSocket;

  // Convenience getters for Device properties
  String get id => device.id;
  String get assignedName => device.assignedName;
  String? get slotName => device.slotName;
  DeviceRuntimeState state;
  int? batteryLevel;
  double? temperature;
  int? storageAvailableMb;
  bool isRecording;
  String? currentSessionId;
  DateTime lastStatusAt;

  // Preview streaming state
  String? previewUrl;
  int? previewWidth;
  int? previewHeight;
  int? previewFps;
  bool get isPreviewAvailable => previewUrl != null;

  ConnectedDevice({
    required this.device,
    required this.webSocket,
    this.state = DeviceRuntimeState.connected,
    this.batteryLevel,
    this.temperature,
    this.storageAvailableMb,
    this.isRecording = false,
    this.currentSessionId,
    DateTime? lastStatusAt,
    this.previewUrl,
    this.previewWidth,
    this.previewHeight,
    this.previewFps,
  }) : lastStatusAt = lastStatusAt ?? DateTime.now();

  void updateStatus({
    int? batteryLevel,
    double? temperature,
    int? storageAvailableMb,
    bool? isRecording,
    String? currentSessionId,
  }) {
    if (batteryLevel != null) this.batteryLevel = batteryLevel;
    if (temperature != null) this.temperature = temperature;
    if (storageAvailableMb != null) this.storageAvailableMb = storageAvailableMb;
    if (isRecording != null) this.isRecording = isRecording;
    if (currentSessionId != null) this.currentSessionId = currentSessionId;
    lastStatusAt = DateTime.now();
  }

  void updatePreview({
    String? url,
    int? width,
    int? height,
    int? fps,
  }) {
    previewUrl = url;
    if (width != null) previewWidth = width;
    if (height != null) previewHeight = height;
    if (fps != null) previewFps = fps;
  }
}

enum DeviceRuntimeState {
  connecting,
  connected,
  paired,
  recording,
  error,
  disconnected,
}
