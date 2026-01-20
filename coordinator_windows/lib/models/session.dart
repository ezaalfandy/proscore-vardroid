/// Recording session model.
class Session {
  final String id;
  final String? eventId;
  final String? matchId;
  final String? title;
  final DateTime? startedAt;
  final DateTime? stoppedAt;
  final SessionStatus status;

  Session({
    required this.id,
    this.eventId,
    this.matchId,
    this.title,
    this.startedAt,
    this.stoppedAt,
    this.status = SessionStatus.pending,
  });

  /// Create from database row
  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      id: map['id'] as String,
      eventId: map['event_id'] as String?,
      matchId: map['match_id'] as String?,
      title: map['title'] as String?,
      startedAt: map['started_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['started_at'] as int)
          : null,
      stoppedAt: map['stopped_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['stopped_at'] as int)
          : null,
      status: SessionStatus.fromString(map['status'] as String? ?? 'pending'),
    );
  }

  /// Convert to database row
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'event_id': eventId,
      'match_id': matchId,
      'title': title,
      'started_at': startedAt?.millisecondsSinceEpoch,
      'stopped_at': stoppedAt?.millisecondsSinceEpoch,
      'status': status.value,
    };
  }

  Session copyWith({
    String? id,
    String? eventId,
    String? matchId,
    String? title,
    DateTime? startedAt,
    DateTime? stoppedAt,
    SessionStatus? status,
  }) {
    return Session(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      matchId: matchId ?? this.matchId,
      title: title ?? this.title,
      startedAt: startedAt ?? this.startedAt,
      stoppedAt: stoppedAt ?? this.stoppedAt,
      status: status ?? this.status,
    );
  }

  /// Get session duration
  Duration? get duration {
    if (startedAt == null) return null;
    final end = stoppedAt ?? DateTime.now();
    return end.difference(startedAt!);
  }

  bool get isActive => status == SessionStatus.recording;

  @override
  String toString() => 'Session(id: $id, status: $status)';
}

enum SessionStatus {
  pending('pending'),
  recording('recording'),
  stopped('stopped'),
  completed('completed');

  final String value;
  const SessionStatus(this.value);

  static SessionStatus fromString(String value) {
    return SessionStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SessionStatus.pending,
    );
  }
}
