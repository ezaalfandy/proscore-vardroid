import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:var_protocol/var_protocol.dart';

import '../models/session.dart';
import '../services/session_manager_service.dart';

/// Provider for recording session state.
class SessionProvider extends ChangeNotifier {
  final SessionManagerService _sessionManagerService;

  StreamSubscription? _sessionSubscription;
  StreamSubscription? _durationSubscription;

  Session? _currentSession;
  Duration _currentDuration = Duration.zero;
  List<Session> _sessions = [];

  SessionProvider({
    required SessionManagerService sessionManagerService,
  }) : _sessionManagerService = sessionManagerService {
    _init();
  }

  void _init() {
    // Listen to session changes
    _sessionSubscription = _sessionManagerService.sessionStream.listen((session) {
      _currentSession = session;
      notifyListeners();
    });

    // Listen to duration updates
    _durationSubscription = _sessionManagerService.durationStream.listen((duration) {
      _currentDuration = duration;
      notifyListeners();
    });

    // Load initial state
    _currentSession = _sessionManagerService.currentSession;
    _currentDuration = _sessionManagerService.currentDuration;
  }

  /// Current recording session
  Session? get currentSession => _currentSession;

  /// Whether currently recording
  bool get isRecording => _sessionManagerService.isRecording;

  /// Current session duration
  Duration get currentDuration => _currentDuration;

  /// Formatted duration string (HH:MM:SS)
  String get formattedDuration {
    final hours = _currentDuration.inHours.toString().padLeft(2, '0');
    final minutes = (_currentDuration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_currentDuration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  /// List of all sessions
  List<Session> get sessions => List.unmodifiable(_sessions);

  /// Start a new recording session.
  Future<void> startRecording({
    String? eventId,
    String? matchId,
    String? title,
    VideoProfile? profile,
  }) async {
    await _sessionManagerService.startSession(
      eventId: eventId,
      matchId: matchId,
      title: title,
      profile: profile,
    );
  }

  /// Stop the current recording session.
  Future<void> stopRecording() async {
    await _sessionManagerService.stopSession();
  }

  /// Load all sessions from database.
  Future<void> loadSessions() async {
    _sessions = await _sessionManagerService.getAllSessions();
    notifyListeners();
  }

  /// Get a session by ID.
  Future<Session?> getSession(String sessionId) async {
    return await _sessionManagerService.getSession(sessionId);
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _durationSubscription?.cancel();
    super.dispose();
  }
}
