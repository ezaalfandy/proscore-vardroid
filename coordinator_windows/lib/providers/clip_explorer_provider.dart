import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/remote_session.dart';
import '../models/remote_clip.dart';
import '../services/clip_explorer_service.dart';
import '../services/device_manager_service.dart';

/// Navigation view states for the clip explorer
enum ExplorerView {
  devices,
  sessions,
  clips,
}

/// Provider for clip explorer UI state.
class ClipExplorerProvider extends ChangeNotifier {
  final ClipExplorerService _explorerService;
  final DeviceManagerService _deviceManagerService;

  StreamSubscription? _sessionsSubscription;
  StreamSubscription? _clipsSubscription;
  StreamSubscription? _devicesSubscription;

  // Navigation state
  ExplorerView _currentView = ExplorerView.devices;
  String? _selectedDeviceId;
  String? _selectedSessionId;

  // Data
  Map<String, List<RemoteSession>> _deviceSessions = {};
  Map<String, List<RemoteClip>> _sessionClips = {};

  // Selection state for batch operations
  final Set<String> _selectedClipIds = {};

  // Loading states
  bool _isLoadingSessions = false;
  bool _isLoadingClips = false;

  ClipExplorerProvider({
    required ClipExplorerService explorerService,
    required DeviceManagerService deviceManagerService,
  })  : _explorerService = explorerService,
        _deviceManagerService = deviceManagerService {
    _init();
  }

  void _init() {
    // Listen to sessions changes
    _sessionsSubscription = _explorerService.sessionsStream.listen((sessions) {
      _deviceSessions = sessions;
      _isLoadingSessions = false;
      notifyListeners();
    });

    // Listen to clips changes
    _clipsSubscription = _explorerService.clipsStream.listen((clips) {
      _sessionClips = clips;
      _isLoadingClips = false;
      notifyListeners();
    });

    // Listen to device connection changes
    _devicesSubscription =
        _deviceManagerService.devicesStream.listen((_) {
      notifyListeners();
    });
  }

  // ===== Getters =====

  /// Current navigation view
  ExplorerView get currentView => _currentView;

  /// Selected device ID
  String? get selectedDeviceId => _selectedDeviceId;

  /// Selected session ID
  String? get selectedSessionId => _selectedSessionId;

  /// Whether sessions are loading
  bool get isLoadingSessions => _isLoadingSessions;

  /// Whether clips are loading
  bool get isLoadingClips => _isLoadingClips;

  /// Selected clip IDs for batch operations
  Set<String> get selectedClipIds => Set.unmodifiable(_selectedClipIds);

  /// Number of selected clips
  int get selectedClipCount => _selectedClipIds.length;

  /// Whether any clips are selected
  bool get hasSelection => _selectedClipIds.isNotEmpty;

  /// Get connected devices
  List<dynamic> get connectedDevices =>
      _deviceManagerService.connectedDevices;

  /// Get sessions for currently selected device
  List<RemoteSession> get currentDeviceSessions {
    if (_selectedDeviceId == null) return [];
    return _deviceSessions[_selectedDeviceId] ?? [];
  }

  /// Get sessions grouped by event for current device
  Map<String, List<RemoteSession>> get sessionsGroupedByEvent {
    final sessions = currentDeviceSessions;
    final grouped = <String, List<RemoteSession>>{};

    for (final session in sessions) {
      final eventKey = session.eventDisplayName;
      grouped.putIfAbsent(eventKey, () => []);
      grouped[eventKey]!.add(session);
    }

    return grouped;
  }

  /// Get clips for currently selected session
  List<RemoteClip> get currentSessionClips {
    if (_selectedDeviceId == null || _selectedSessionId == null) return [];
    return _sessionClips['${_selectedDeviceId}_$_selectedSessionId'] ?? [];
  }

  /// Get the currently selected session
  RemoteSession? get currentSession {
    if (_selectedDeviceId == null || _selectedSessionId == null) return null;
    final sessions = _deviceSessions[_selectedDeviceId];
    if (sessions == null) return null;
    try {
      return sessions.firstWhere((s) => s.sessionId == _selectedSessionId);
    } catch (e) {
      return null;
    }
  }

  /// Get breadcrumb path
  List<String> get breadcrumbs {
    final crumbs = <String>['Devices'];

    if (_selectedDeviceId != null) {
      final device =
          _deviceManagerService.getConnectedDevice(_selectedDeviceId!);
      crumbs.add(device?.assignedName ?? _selectedDeviceId!);
    }

    if (_selectedSessionId != null) {
      final session = currentSession;
      crumbs.add(session?.displayName ?? _selectedSessionId!);
    }

    return crumbs;
  }

  // ===== Navigation =====

  /// Select a device and show its sessions
  void selectDevice(String deviceId) {
    _selectedDeviceId = deviceId;
    _selectedSessionId = null;
    _currentView = ExplorerView.sessions;
    _selectedClipIds.clear();
    notifyListeners();

    // Request sessions from device
    _isLoadingSessions = true;
    notifyListeners();
    _explorerService.requestSessions(deviceId);
  }

  /// Select a session and show its clips
  void selectSession(String sessionId) {
    _selectedSessionId = sessionId;
    _currentView = ExplorerView.clips;
    _selectedClipIds.clear();
    notifyListeners();

    // Request clips for session
    if (_selectedDeviceId != null) {
      _isLoadingClips = true;
      notifyListeners();
      _explorerService.requestClips(_selectedDeviceId!, sessionId);
    }
  }

  /// Navigate back one level
  void navigateBack() {
    switch (_currentView) {
      case ExplorerView.clips:
        _selectedSessionId = null;
        _currentView = ExplorerView.sessions;
        _selectedClipIds.clear();
        break;
      case ExplorerView.sessions:
        _selectedDeviceId = null;
        _currentView = ExplorerView.devices;
        break;
      case ExplorerView.devices:
        // Already at top level
        break;
    }
    notifyListeners();
  }

  /// Navigate to specific breadcrumb index
  void navigateToBreadcrumb(int index) {
    if (index == 0) {
      _selectedDeviceId = null;
      _selectedSessionId = null;
      _currentView = ExplorerView.devices;
    } else if (index == 1 && _selectedDeviceId != null) {
      _selectedSessionId = null;
      _currentView = ExplorerView.sessions;
    }
    _selectedClipIds.clear();
    notifyListeners();
  }

  // ===== Refresh =====

  /// Refresh current view
  void refresh() {
    switch (_currentView) {
      case ExplorerView.devices:
        // Request sessions from all connected devices
        _explorerService.requestSessionsFromAll();
        break;
      case ExplorerView.sessions:
        if (_selectedDeviceId != null) {
          _isLoadingSessions = true;
          notifyListeners();
          _explorerService.requestSessions(_selectedDeviceId!);
        }
        break;
      case ExplorerView.clips:
        if (_selectedDeviceId != null && _selectedSessionId != null) {
          _isLoadingClips = true;
          notifyListeners();
          _explorerService.requestClips(_selectedDeviceId!, _selectedSessionId!);
        }
        break;
    }
  }

  // ===== Clip Operations =====

  /// Request thumbnail for a clip
  void requestThumbnail(RemoteClip clip) {
    _explorerService.requestThumbnail(
      clip.deviceId,
      clip.sessionId,
      clip.clipId,
    );
  }

  /// Download a clip
  Future<String?> downloadClip(RemoteClip clip) async {
    return await _explorerService.downloadClip(clip);
  }

  /// Download selected clips
  Future<void> downloadSelectedClips() async {
    for (final clipId in _selectedClipIds) {
      final clip = _findClipById(clipId);
      if (clip != null && !clip.isDownloaded) {
        await _explorerService.downloadClip(clip);
      }
    }
  }

  /// Delete a clip from device
  void deleteClip(RemoteClip clip) {
    _explorerService.deleteRemoteClip(
      clip.deviceId,
      clip.sessionId,
      clip.clipId,
    );
  }

  /// Delete selected clips
  void deleteSelectedClips() {
    for (final clipId in _selectedClipIds.toList()) {
      final clip = _findClipById(clipId);
      if (clip != null) {
        _explorerService.deleteRemoteClip(
          clip.deviceId,
          clip.sessionId,
          clip.clipId,
        );
      }
    }
    _selectedClipIds.clear();
    notifyListeners();
  }

  /// Preview a clip (start remote playback)
  void previewClip(RemoteClip clip) {
    _explorerService.startRemotePreview(
      clip.deviceId,
      clip.sessionId,
      clip.filePath,
    );
  }

  /// Stop clip preview
  void stopPreview() {
    if (_selectedDeviceId != null) {
      _explorerService.stopRemotePreview(_selectedDeviceId!);
    }
  }

  // ===== Session Operations =====

  /// Delete a session from device
  void deleteSession(RemoteSession session) {
    _explorerService.deleteRemoteSession(session.deviceId, session.sessionId);
  }

  // ===== Selection =====

  /// Toggle clip selection
  void toggleClipSelection(String clipId) {
    if (_selectedClipIds.contains(clipId)) {
      _selectedClipIds.remove(clipId);
    } else {
      _selectedClipIds.add(clipId);
    }
    notifyListeners();
  }

  /// Select all clips in current view
  void selectAllClips() {
    for (final clip in currentSessionClips) {
      _selectedClipIds.add(clip.clipId);
    }
    notifyListeners();
  }

  /// Clear all selections
  void clearSelection() {
    _selectedClipIds.clear();
    notifyListeners();
  }

  /// Check if a clip is selected
  bool isClipSelected(String clipId) => _selectedClipIds.contains(clipId);

  // ===== Helpers =====

  RemoteClip? _findClipById(String clipId) {
    for (final clips in _sessionClips.values) {
      try {
        return clips.firstWhere((c) => c.clipId == clipId);
      } catch (e) {
        // Not found in this session
      }
    }
    return null;
  }

  /// Get device name by ID
  String getDeviceName(String deviceId) {
    final device = _deviceManagerService.getConnectedDevice(deviceId);
    return device?.assignedName ?? deviceId;
  }

  /// Get session count for a device
  int getSessionCountForDevice(String deviceId) {
    return _deviceSessions[deviceId]?.length ?? 0;
  }

  /// Get total clip count for a device
  int getClipCountForDevice(String deviceId) {
    final sessions = _deviceSessions[deviceId];
    if (sessions == null) return 0;
    return sessions.fold(0, (sum, s) => sum + s.clipCount);
  }

  @override
  void dispose() {
    _sessionsSubscription?.cancel();
    _clipsSubscription?.cancel();
    _devicesSubscription?.cancel();
    super.dispose();
  }
}
