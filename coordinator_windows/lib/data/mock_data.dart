import '../widgets/status_dot.dart';

class DeviceInfo {
  const DeviceInfo({
    required this.name,
    required this.ip,
    required this.status,
    required this.battery,
    required this.storage,
    required this.temperature,
    required this.lastClip,
  });

  final String name;
  final String ip;
  final DeviceStatus status;
  final int battery;
  final int storage;
  final int temperature;
  final String lastClip;
}

class ClipInfo {
  const ClipInfo({
    required this.label,
    required this.camera,
    required this.duration,
    required this.state,
  });

  final String label;
  final String camera;
  final String duration;
  final String state;
}

class TimelineMark {
  const TimelineMark({
    required this.label,
    required this.timecode,
  });

  final String label;
  final String timecode;
}

class MockData {
  static const List<DeviceInfo> devices = [
    DeviceInfo(
      name: 'Camera A',
      ip: '192.168.10.21',
      status: DeviceStatus.recording,
      battery: 82,
      storage: 64,
      temperature: 38,
      lastClip: 'A_2026-01-15_18-22-14',
    ),
    DeviceInfo(
      name: 'Camera B',
      ip: '192.168.10.22',
      status: DeviceStatus.paired,
      battery: 71,
      storage: 52,
      temperature: 36,
      lastClip: 'B_2026-01-15_18-18-03',
    ),
    DeviceInfo(
      name: 'Camera C',
      ip: '192.168.10.23',
      status: DeviceStatus.connecting,
      battery: 64,
      storage: 47,
      temperature: 34,
      lastClip: 'C_2026-01-15_18-12-49',
    ),
    DeviceInfo(
      name: 'Camera D',
      ip: '192.168.10.24',
      status: DeviceStatus.unpaired,
      battery: 93,
      storage: 81,
      temperature: 33,
      lastClip: 'D_2026-01-15_18-05-20',
    ),
  ];

  static const List<ClipInfo> clips = [
    ClipInfo(
      label: 'CLIP 014',
      camera: 'Camera A',
      duration: '00:12',
      state: 'Ready',
    ),
    ClipInfo(
      label: 'CLIP 013',
      camera: 'Camera B',
      duration: '00:18',
      state: 'Ready',
    ),
    ClipInfo(
      label: 'CLIP 012',
      camera: 'Camera A',
      duration: '00:10',
      state: 'Downloading',
    ),
    ClipInfo(
      label: 'CLIP 011',
      camera: 'Camera C',
      duration: '00:15',
      state: 'Failed',
    ),
  ];

  static const List<TimelineMark> marks = [
    TimelineMark(label: 'Exchange 1', timecode: '00:02:13'),
    TimelineMark(label: 'Exchange 2', timecode: '00:04:05'),
    TimelineMark(label: 'Exchange 3', timecode: '00:06:47'),
    TimelineMark(label: 'Exchange 4', timecode: '00:08:26'),
    TimelineMark(label: 'Exchange 5', timecode: '00:11:10'),
  ];
}
