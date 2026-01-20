import 'dart:async';

import 'package:uuid/uuid.dart';
import 'package:var_protocol/var_protocol.dart';

import '../models/session.dart';
import 'database_service.dart';
import 'device_manager_service.dart';

/// Service for managing recording sessions.
class SessionManagerService {
  final DatabaseService _databaseService;
  final DeviceManagerService _deviceManagerService;
  final _uuid = const Uuid();

  Session? _currentSession;
  DateTime? _sessionStartTime;
  Timer? _durationTimer;

  /// Stream controller for session state changes
  final _sessionController = StreamController<Session?>.broadcast();

  /// Stream controller for session duration updates
  final _durationController = StreamController<Duration>.broadcast();

  /// Stream of session changes
  Stream<Session?> get sessionStream => _sessionController.stream;

  /// Stream of duration updates (fires every second during recording)
  Stream<Duration> get durationStream => _durationController.stream;

  /// Get current session
  Session? get currentSession => _currentSession;

  /// Check if currently recording
  bool get isRecording => _currentSession?.status == SessionStatus.recording;

  /// Get current session duration
  Duration get currentDuration {
    if (_sessionStartTime == null) return Duration.zero;
    return DateTime.now().difference(_sessionStartTime!);
  }

  SessionManagerService({
    required DatabaseService databaseService,
    required DeviceManagerService deviceManagerService,
  })  : _databaseService = databaseService,
        _deviceManagerService = deviceManagerService;

  /// Initialize service, restore any active session.
  Future<void> init() async {
    // Check for any active session from previous run
    final activeSession = await _databaseService.getActiveSession();
    if (activeSession != null) {
      print('Found active session from previous run: ${activeSession.id}');
      // Mark it as stopped since the app restarted
      final stoppedSession = activeSession.copyWith(
        status: SessionStatus.stopped,
        stoppedAt: DateTime.now(),
      );
      await _databaseService.updateSession(stoppedSession);
    }
  }

  /// Start a new recording session.
  Future<Session> startSession({
    String? eventId,
    String? matchId,
    String? title,
    VideoProfile? profile,
  }) async {
    if (_currentSession != null && _currentSession!.isActive) {
      throw StateError('Session already in progress');
    }

    final sessionId = _uuid.v4();
    final now = DateTime.now();

    final session = Session(
      id: sessionId,
      eventId: eventId,
      matchId: matchId,
      title: title ?? 'Session ${now.toIso8601String().substring(0, 10)}',
      startedAt: now,
      status: SessionStatus.recording,
    );

    // Save to database
    await _databaseService.insertSession(session);

    // Update state
    _currentSession = session;
    _sessionStartTime = now;

    // Start duration timer
    _startDurationTimer();

    // Notify listeners
    _sessionController.add(_currentSession);

    // Send start_record to all connected devices
    final startMessage = StartRecordMessage(
      deviceId: 'coordinator',
      sessionId: sessionId,
      profile: profile ?? VideoProfile(resolution: '1080p', fps: 30, bitrate: 10000000),
      meta: SessionMeta(
        eventId: eventId ?? '',
        matchId: matchId ?? '',
      ),
    );

    _deviceManagerService.broadcastToAll(startMessage);

    print('Started recording session: $sessionId');
    return session;
  }

  /// Stop the current recording session.
  Future<Session?> stopSession() async {
    if (_currentSession == null || !_currentSession!.isActive) {
      return null;
    }

    final now = DateTime.now();
    final stoppedSession = _currentSession!.copyWith(
      status: SessionStatus.stopped,
      stoppedAt: now,
    );

    // Update database
    await _databaseService.updateSession(stoppedSession);

    // Stop duration timer
    _stopDurationTimer();

    // Update state
    _currentSession = stoppedSession;
    _sessionStartTime = null;

    // Notify listeners
    _sessionController.add(_currentSession);

    // Send stop_record to all devices
    final stopMessage = StopRecordMessage(deviceId: 'coordinator');
    _deviceManagerService.broadcastToAll(stopMessage);

    print('Stopped recording session: ${stoppedSession.id}');
    return stoppedSession;
  }

  /// Handle recording_started acknowledgment from a device.
  void handleRecordingStarted(RecordingStartedMessage message) {
    print('Device ${message.deviceId} started recording at ${message.startedAt}');

    // Update device state
    _deviceManagerService.updateDeviceRecordingState(
      message.deviceId,
      true,
      message.sessionId,
    );
  }

  /// Handle recording_stopped acknowledgment from a device.
  void handleRecordingStopped(RecordingStoppedMessage message) {
    print('Device ${message.deviceId} stopped recording at ${message.stoppedAt}');

    // Update device state
    _deviceManagerService.updateDeviceRecordingState(
      message.deviceId,
      false,
      null,
    );
  }

  /// Get all sessions.
  Future<List<Session>> getAllSessions() async {
    return await _databaseService.getAllSessions();
  }

  /// Get a session by ID.
  Future<Session?> getSession(String sessionId) async {
    return await _databaseService.getSessionById(sessionId);
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_sessionStartTime != null) {
        _durationController.add(currentDuration);
      }
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  /// Dispose resources.
  void dispose() {
    _durationTimer?.cancel();
    _sessionController.close();
    _durationController.close();
  }
}
