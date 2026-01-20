import 'dart:io';

/// Service for resolving device network information.
class NetworkService {
  /// Returns the first non-loopback IPv4 address found.
  Future<String?> getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (!address.isLoopback) {
            return address.address;
          }
        }
      }
    } catch (_) {
      // Ignore network lookup errors.
    }

    return null;
  }
}
