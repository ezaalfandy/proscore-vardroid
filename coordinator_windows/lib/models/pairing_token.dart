/// Pairing token model for device pairing.
class PairingToken {
  final String token;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool used;

  PairingToken({
    required this.token,
    required this.createdAt,
    required this.expiresAt,
    this.used = false,
  });

  /// Create from database row
  factory PairingToken.fromMap(Map<String, dynamic> map) {
    return PairingToken(
      token: map['token'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(map['expires_at'] as int),
      used: (map['used'] as int?) == 1,
    );
  }

  /// Convert to database row
  Map<String, dynamic> toMap() {
    return {
      'token': token,
      'created_at': createdAt.millisecondsSinceEpoch,
      'expires_at': expiresAt.millisecondsSinceEpoch,
      'used': used ? 1 : 0,
    };
  }

  /// Check if token is valid (not expired and not used)
  bool get isValid => !used && DateTime.now().isBefore(expiresAt);

  /// Check if token is expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Time remaining until expiration
  Duration get timeRemaining {
    final remaining = expiresAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  PairingToken copyWith({
    String? token,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? used,
  }) {
    return PairingToken(
      token: token ?? this.token,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      used: used ?? this.used,
    );
  }

  @override
  String toString() => 'PairingToken(token: $token, valid: $isValid)';
}
