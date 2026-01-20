/// Incident mark model.
class Mark {
  final String id;
  final String sessionId;
  final DateTime coordinatorTs;
  final String? label;
  final String? note;
  final DateTime createdAt;

  Mark({
    required this.id,
    required this.sessionId,
    required this.coordinatorTs,
    this.label,
    this.note,
    required this.createdAt,
  });

  /// Create from database row
  factory Mark.fromMap(Map<String, dynamic> map) {
    return Mark(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      coordinatorTs: DateTime.fromMillisecondsSinceEpoch(map['coordinator_ts'] as int),
      label: map['label'] as String?,
      note: map['note'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  /// Convert to database row
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'coordinator_ts': coordinatorTs.millisecondsSinceEpoch,
      'label': label,
      'note': note,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  Mark copyWith({
    String? id,
    String? sessionId,
    DateTime? coordinatorTs,
    String? label,
    String? note,
    DateTime? createdAt,
  }) {
    return Mark(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      coordinatorTs: coordinatorTs ?? this.coordinatorTs,
      label: label ?? this.label,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'Mark(id: $id, label: $label)';
}

/// Mark acknowledgment from a device
class MarkAck {
  final int? id;
  final String markId;
  final String deviceId;
  final DateTime deviceTs;
  final DateTime receivedAt;

  MarkAck({
    this.id,
    required this.markId,
    required this.deviceId,
    required this.deviceTs,
    required this.receivedAt,
  });

  /// Create from database row
  factory MarkAck.fromMap(Map<String, dynamic> map) {
    return MarkAck(
      id: map['id'] as int?,
      markId: map['mark_id'] as String,
      deviceId: map['device_id'] as String,
      deviceTs: DateTime.fromMillisecondsSinceEpoch(map['device_ts'] as int),
      receivedAt: DateTime.fromMillisecondsSinceEpoch(map['received_at'] as int),
    );
  }

  /// Convert to database row
  Map<String, dynamic> toMap() {
    return {
      'mark_id': markId,
      'device_id': deviceId,
      'device_ts': deviceTs.millisecondsSinceEpoch,
      'received_at': receivedAt.millisecondsSinceEpoch,
    };
  }

  @override
  String toString() => 'MarkAck(markId: $markId, deviceId: $deviceId)';
}
