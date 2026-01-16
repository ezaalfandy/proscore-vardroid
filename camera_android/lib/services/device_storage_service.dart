import 'package:shared_preferences/shared_preferences.dart';

/// Service for storing device pairing information and settings
class DeviceStorageService {
  static const String _keyDeviceId = 'device_id';
  static const String _keyDeviceKey = 'device_key';
  static const String _keyAssignedName = 'assigned_name';
  static const String _keyCoordinatorHost = 'coordinator_host';
  static const String _keyCoordinatorPort = 'coordinator_port';
  static const String _keySegmentDuration = 'segment_duration';
  static const String _keyVideoResolution = 'video_resolution';
  static const String _keyVideoFps = 'video_fps';
  static const String _keyVideoBitrate = 'video_bitrate';

  Future<String?> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDeviceId);
  }

  Future<void> setDeviceId(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDeviceId, deviceId);
  }

  Future<String?> getDeviceKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDeviceKey);
  }

  Future<void> setDeviceKey(String deviceKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDeviceKey, deviceKey);
  }

  Future<String?> getAssignedName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAssignedName);
  }

  Future<void> setAssignedName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAssignedName, name);
  }

  Future<String?> getCoordinatorHost() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCoordinatorHost);
  }

  Future<void> setCoordinatorHost(String host) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCoordinatorHost, host);
  }

  Future<int?> getCoordinatorPort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyCoordinatorPort);
  }

  Future<void> setCoordinatorPort(int port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCoordinatorPort, port);
  }

  Future<bool> isPaired() async {
    final deviceKey = await getDeviceKey();
    final host = await getCoordinatorHost();
    final port = await getCoordinatorPort();
    return deviceKey != null && host != null && port != null;
  }

  Future<void> clearPairingData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDeviceKey);
    await prefs.remove(_keyAssignedName);
    await prefs.remove(_keyCoordinatorHost);
    await prefs.remove(_keyCoordinatorPort);
  }

  // Video settings
  Future<int> getSegmentDuration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keySegmentDuration) ?? 3;
  }

  Future<void> setSegmentDuration(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySegmentDuration, seconds);
  }

  Future<String> getVideoResolution() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyVideoResolution) ?? '1080p';
  }

  Future<void> setVideoResolution(String resolution) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyVideoResolution, resolution);
  }

  Future<int> getVideoFps() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyVideoFps) ?? 30;
  }

  Future<void> setVideoFps(int fps) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyVideoFps, fps);
  }

  Future<int> getVideoBitrate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyVideoBitrate) ?? 12000000;
  }

  Future<void> setVideoBitrate(int bitrate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyVideoBitrate, bitrate);
  }
}
