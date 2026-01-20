import 'dart:math';

import '../models/pairing_token.dart';
import 'database_service.dart';

/// Service for managing device pairing tokens.
class PairingService {
  final DatabaseService _databaseService;

  /// Token expiry duration (5 minutes as per protocol)
  static const Duration tokenExpiry = Duration(minutes: 5);

  /// Characters used for token generation
  static const String _tokenChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  PairingToken? _currentToken;

  PairingService({required DatabaseService databaseService})
      : _databaseService = databaseService;

  /// Get the current active pairing token, or generate a new one if expired.
  Future<PairingToken> getCurrentToken() async {
    if (_currentToken != null && _currentToken!.isValid) {
      return _currentToken!;
    }
    return await generateToken();
  }

  /// Generate a new 6-character alphanumeric pairing token.
  Future<PairingToken> generateToken() async {
    // Clean up old tokens first
    await _databaseService.cleanupExpiredTokens();

    final random = Random.secure();
    final tokenChars = List.generate(
      6,
      (_) => _tokenChars[random.nextInt(_tokenChars.length)],
    );
    final tokenString = tokenChars.join();

    final now = DateTime.now();
    final token = PairingToken(
      token: tokenString,
      createdAt: now,
      expiresAt: now.add(tokenExpiry),
      used: false,
    );

    await _databaseService.insertPairingToken(token);
    _currentToken = token;

    print('Generated new pairing token: $tokenString (expires in 5 minutes)');
    return token;
  }

  /// Validate a pairing token.
  /// Returns the token if valid, null otherwise.
  Future<PairingToken?> validateToken(String tokenString) async {
    final token = await _databaseService.getPairingToken(tokenString.toUpperCase());

    if (token == null) {
      print('Token not found: $tokenString');
      return null;
    }

    if (token.used) {
      print('Token already used: $tokenString');
      return null;
    }

    if (token.isExpired) {
      print('Token expired: $tokenString');
      return null;
    }

    return token;
  }

  /// Mark a token as used after successful pairing.
  Future<void> markTokenUsed(String tokenString) async {
    await _databaseService.markTokenUsed(tokenString.toUpperCase());

    // Clear current token if it was the one used
    if (_currentToken?.token == tokenString.toUpperCase()) {
      _currentToken = null;
    }

    print('Token marked as used: $tokenString');
  }

  /// Generate a unique device key for a newly paired device.
  String generateDeviceKey() {
    final random = Random.secure();
    final bytes = List.generate(32, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Generate a unique device ID.
  String generateDeviceId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Generate an assigned name for a device (e.g., "Camera 1", "Camera 2").
  Future<String> generateAssignedName() async {
    final devices = await _databaseService.getAllDevices();
    final existingNumbers = <int>{};

    for (final device in devices) {
      final match = RegExp(r'Camera (\d+)').firstMatch(device.assignedName);
      if (match != null) {
        existingNumbers.add(int.parse(match.group(1)!));
      }
    }

    // Find the first available number
    var number = 1;
    while (existingNumbers.contains(number)) {
      number++;
    }

    return 'Camera $number';
  }

  /// Refresh the current token (generate a new one).
  Future<PairingToken> refreshToken() async {
    return await generateToken();
  }

  /// Get time remaining on current token.
  Duration? get tokenTimeRemaining {
    if (_currentToken == null || !_currentToken!.isValid) {
      return null;
    }
    return _currentToken!.timeRemaining;
  }
}
