import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/mark.dart';
import '../services/mark_service.dart';

/// Provider for marks state.
class MarkProvider extends ChangeNotifier {
  final MarkService _markService;

  StreamSubscription? _marksSubscription;

  List<Mark> _marks = [];

  MarkProvider({
    required MarkService markService,
  }) : _markService = markService {
    _init();
  }

  void _init() {
    // Listen to marks changes
    _marksSubscription = _markService.marksStream.listen((marks) {
      _marks = marks;
      notifyListeners();
    });

    // Load initial state
    _marks = _markService.currentSessionMarks;
  }

  /// List of marks for current session
  List<Mark> get marks => List.unmodifiable(_marks);

  /// Number of marks
  int get markCount => _marks.length;

  /// Create a new mark.
  Future<Mark> createMark({String? label, String? note}) async {
    return await _markService.createMark(label: label, note: note);
  }

  /// Update a mark.
  Future<void> updateMark(String markId, {String? label, String? note}) async {
    await _markService.updateMark(markId, label: label, note: note);
  }

  /// Delete a mark.
  Future<void> deleteMark(String markId) async {
    await _markService.deleteMark(markId);
  }

  /// Load marks for the current session.
  Future<void> loadMarks() async {
    await _markService.loadCurrentSessionMarks();
  }

  /// Clear marks cache.
  void clearMarks() {
    _markService.clearMarksCache();
  }

  /// Get marks for a specific session.
  Future<List<Mark>> getMarksForSession(String sessionId) async {
    return await _markService.getMarksForSession(sessionId);
  }

  /// Get mark by ID from current marks.
  Mark? getMark(String markId) {
    try {
      return _marks.firstWhere((m) => m.id == markId);
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _marksSubscription?.cancel();
    super.dispose();
  }
}
