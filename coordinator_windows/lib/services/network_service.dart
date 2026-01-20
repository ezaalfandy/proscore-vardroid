import 'dart:io';

/// Service for network-related operations.
class NetworkService {
  /// Get list of local IPv4 addresses.
  Future<List<String>> getLocalIpAddresses() async {
    final addresses = <String>[];

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          // Skip loopback and link-local addresses
          if (!addr.isLoopback && !addr.address.startsWith('169.254')) {
            addresses.add(addr.address);
          }
        }
      }
    } catch (e) {
      print('Error getting network interfaces: $e');
    }

    return addresses;
  }

  /// Get the primary local IP address (first non-loopback IPv4).
  Future<String?> getPrimaryLocalIp() async {
    final addresses = await getLocalIpAddresses();
    if (addresses.isEmpty) return null;

    // Prefer addresses that look like typical LAN addresses
    for (final addr in addresses) {
      if (addr.startsWith('192.168.') ||
          addr.startsWith('10.') ||
          addr.startsWith('172.')) {
        return addr;
      }
    }

    return addresses.first;
  }

  /// Generate a QR code data URL for device pairing.
  /// Format: var://pair?host=192.168.1.100&port=8765&token=ABC123
  String generatePairingUrl({
    required String host,
    required int port,
    required String token,
  }) {
    return 'var://pair?host=$host&port=$port&token=$token';
  }

  /// Check if a port is available.
  Future<bool> isPortAvailable(int port) async {
    try {
      final server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      await server.close();
      return true;
    } catch (e) {
      return false;
    }
  }
}
