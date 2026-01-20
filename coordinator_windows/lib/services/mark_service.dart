import 'dart:async';

import 'package:uuid/uuid.dart';
import 'package:var_protocol/var_protocol.dart';

import '../models/mark.dart';
import 'database_service.dart';
import 'device_manager_service.dart';
import 'session_manager_service.dart';

/// Service for managing incident marks.
class MarkService {
  final DatabaseService _databaseService;
  final DeviceManagerService _deviceManagerService;
  final SessionManagerService _sessionManagerService;
  final _uuid = const Uuid();

  /// Stream controller for marks list changes
  final _marksController = StreamController<List<Mark>>.broadcast();

  /// Stream of marks updates
  Stream<List<Mark>> get marksStream => _marksController.stream;

  /// Cached marks for current session
  List<Mark> _currentSessionMarks = [];

  /// Get marks for current session
  List<Mark> get currentSessionMarks => List.unmodifiable(_currentSessionMarks);

  MarkService({
    required DatabaseService databaseService,
    required DeviceManagerService deviceManagerService,
    required SessionManagerService sessionManagerService,
  })  : _databaseService = databaseService,
        _deviceManagerService = deviceManagerService,
        _sessionManagerService = sessionManagerService;

  /// Create a new mark and broadcast to all recording devices.
  Future<Mark> createMark({String? label, String? note}) async {
    final session = _sessionManagerService.currentSession;
    if (session == null) {
      throw StateError('No active session');
    }

    final now = DateTime.now();
    final markId = _uuid.v4();

    final mark = Mark(
      id: markId,
      sessionId: session.id,
      coordinatorTs: now,
      label: label ?? 'Mark ${_currentSessionMarks.length + 1}',
      note: note,
      createdAt: now,
    );

    // Save to database
    await _databaseService.insertMark(mark);

    // Add to cache
    _currentSessionMarks.add(mark);
    _marksController.add(_currentSessionMarks);

    // Broadcast to all recording devices
    final markMessage = MarkMessage(
      deviceId: 'coordinator',
      sessionId: session.id,
      markId: markId,
      coordinatorTs: now.millisecondsSinceEpoch,
      note: note ?? mark.label,  // Use label as note if no note provided
    );

    _deviceManagerService.broadcastToRecording(markMessage);

    print('Created mark: ${mark.label} (${mark.id})');
    return mark;
  }

  /// Handle mark acknowledgment from a device.
  Future<void> handleMarkAck(MarkAckMessage message) async {
    print('Mark ${message.markId} acknowledged by ${message.deviceId} at ${message.deviceTs}');

    final ack = MarkAck(
      markId: message.markId,
      deviceId: message.deviceId,
      deviceTs: DateTime.fromMillisecondsSinceEpoch(message.deviceTs),
      receivedAt: DateTime.now(),
    );

    await _databaseService.insertMarkAck(ack);
  }

  /// Update a mark's label or note.
  Future<Mark> updateMark(String markId, {String? label, String? note}) async {
    final existing = await _databaseService.getMarkById(markId);
    if (existing == null) {
      throw ArgumentError('Mark not found: $markId');
    }

    final updated = existing.copyWith(
      label: label ?? existing.label,
      note: note ?? existing.note,
    );

    await _databaseService.updateMark(updated);

    // Update cache
    final index = _currentSessionMarks.indexWhere((m) => m.id == markId);
    if (index >= 0) {
      _currentSessionMarks[index] = updated;
      _marksController.add(_currentSessionMarks);
    }

    return updated;
  }

  /// Delete a mark.
  Future<void> deleteMark(String markId) async {
    await _databaseService.deleteMark(markId);

    // Update cache
    _currentSessionMarks.removeWhere((m) => m.id == markId);
    _marksController.add(_currentSessionMarks);
  }

  /// Get marks for a specific session.
  Future<List<Mark>> getMarksForSession(String sessionId) async {
    return await _databaseService.getMarksBySession(sessionId);
  }

  /// Load marks for the current session.
  Future<void> loadCurrentSessionMarks() async {
    final session = _sessionManagerService.currentSession;
    if (session == null) {
      _currentSessionMarks = [];
    } else {
      _currentSessionMarks = await _databaseService.getMarksBySession(session.id);
    }
    _marksController.add(_currentSessionMarks);
  }

  /// Clear marks cache (call when session changes).
  void clearMarksCache() {
    _currentSessionMarks = [];
    _marksController.add(_currentSessionMarks);
  }

  /// Get mark acknowledgments.
  Future<List<MarkAck>> getMarkAcks(String markId) async {
    return await _databaseService.getAcksByMark(markId);
  }

  /// Dispose resources.
  void dispose() {
    _marksController.close();
  }
}
