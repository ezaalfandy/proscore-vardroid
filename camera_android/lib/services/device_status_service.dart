import 'dart:io';
import 'package:battery_plus/battery_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Service for monitoring device status (battery, storage, temperature)
class DeviceStatusService {
  final Battery _battery = Battery();

  /// Get current battery level (0-100)
  Future<int> getBatteryLevel() async {
    try {
      final level = await _battery.batteryLevel;
      return level;
    } catch (e) {
      return 0;
    }
  }

  /// Get current battery state
  Future<BatteryState> getBatteryState() async {
    try {
      return await _battery.batteryState;
    } catch (e) {
      return BatteryState.unknown;
    }
  }

  /// Get free storage space in MB
  Future<int> getFreeSpaceMB() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final stat = await directory.stat();
      // Note: This is an approximation - actual implementation would need platform-specific code
      // For a real implementation, you'd use platform channels to get accurate free space
      return await _estimateFreeSpace(directory);
    } catch (e) {
      return 0;
    }
  }

  Future<int> _estimateFreeSpace(Directory directory) async {
    try {
      // This is a simplified estimation
      // For production, use platform-specific code to get actual free space
      final path = directory.path;

      // On Android, we would use platform channels to call
      // StatFs to get actual free space. For now, return a placeholder.
      // This should be implemented with platform channels.
      return 10000; // Placeholder: 10GB
    } catch (e) {
      return 0;
    }
  }

  /// Get device temperature in Celsius
  /// Note: This is platform-specific and would require platform channels
  Future<double> getTemperature() async {
    try {
      // This would require platform-specific implementation
      // For now, return a normal temperature
      // In production, use platform channels to get actual CPU/battery temp
      return 35.0; // Placeholder
    } catch (e) {
      return 0.0;
    }
  }

  /// Check if device has low storage
  Future<bool> hasLowStorage() async {
    final freeSpace = await getFreeSpaceMB();
    return freeSpace < 2000; // Less than 2GB
  }

  /// Check if device is overheating
  Future<bool> isOverheating() async {
    final temp = await getTemperature();
    return temp > 45.0; // Above 45°C
  }

  /// Check if device is charging
  Future<bool> isCharging() async {
    final state = await getBatteryState();
    return state == BatteryState.charging || state == BatteryState.full;
  }

  /// Get comprehensive device status
  Future<DeviceStatus> getStatus() async {
    final battery = await getBatteryLevel();
    final temperature = await getTemperature();
    final freeSpace = await getFreeSpaceMB();
    final isCharging = await this.isCharging();

    return DeviceStatus(
      battery: battery,
      temperature: temperature,
      freeSpaceMB: freeSpace,
      isCharging: isCharging,
    );
  }
}

/// Device status data class
class DeviceStatus {
  final int battery;
  final double temperature;
  final int freeSpaceMB;
  final bool isCharging;

  DeviceStatus({
    required this.battery,
    required this.temperature,
    required this.freeSpaceMB,
    required this.isCharging,
  });

  bool get hasLowStorage => freeSpaceMB < 2000;
  bool get isOverheating => temperature > 45.0;
  bool get hasLowBattery => battery < 20;
}
