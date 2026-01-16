import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/connection_provider.dart';
import '../../services/websocket_client_service.dart';
import '../theme/app_colors.dart';
import '../widgets/connection_status_card.dart';
import 'camera_preview_screen.dart';
import 'settings_screen.dart';
import 'recording_library_screen.dart';
import 'qr_scanner_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VAR Camera Node'),
        actions: [
          IconButton(
            icon: const Icon(Icons.video_library),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RecordingLibraryScreen(),
                ),
              );
            },
            tooltip: 'Library',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Consumer<ConnectionProvider>(
        builder: (context, connectionProvider, child) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),

                  // Connection status card
                  ConnectionStatusCard(
                    connectionState: connectionProvider.connectionState,
                    assignedName: connectionProvider.assignedName,
                    errorMessage: connectionProvider.errorMessage,
                    isReconnecting: connectionProvider.isReconnecting,
                    onRetry: connectionProvider.connectionState == VarConnectionState.error
                        ? () => connectionProvider.retryConnection()
                        : null,
                  ),

                  const SizedBox(height: 32),

                  // Action buttons
                  if (!connectionProvider.isConnected) ...[
                    // Open camera standalone
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CameraPreviewScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.videocam),
                      label: const Text('Open Camera (Standalone)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: AppColors.text,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Divider with text
                    Row(
                      children: [
                        const Expanded(child: Divider(color: AppColors.border)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Or connect to coordinator',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textMuted,
                                ),
                          ),
                        ),
                        const Expanded(child: Divider(color: AppColors.border)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Scan QR Code button (primary)
                    ElevatedButton.icon(
                      onPressed: () => _scanQrCode(context),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan QR Code'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.text,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Manual entry button (secondary)
                    OutlinedButton.icon(
                      onPressed: () => _showManualEntryDialog(context),
                      icon: const Icon(Icons.edit),
                      label: const Text('Enter IP Manually'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.text,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],

                  if (connectionProvider.isConnected) ...[
                    // Open camera (connected)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CameraPreviewScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.videocam),
                      label: const Text('Open Camera'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: AppColors.text,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Disconnect button
                    ElevatedButton.icon(
                      onPressed: () => connectionProvider.disconnect(),
                      icon: const Icon(Icons.link_off),
                      label: const Text('Disconnect'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surfaceAlt,
                        foregroundColor: AppColors.text,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Unpair button
                    OutlinedButton.icon(
                      onPressed: () => _showUnpairDialog(context),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Unpair Device'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Open QR scanner and handle result
  Future<void> _scanQrCode(BuildContext context) async {
    final result = await Navigator.push<QrPairingData>(
      context,
      MaterialPageRoute(
        builder: (context) => const QrScannerScreen(),
      ),
    );

    if (result != null && mounted) {
      // Connect with scanned data
      context.read<ConnectionProvider>().connectToCoordinator(
            host: result.host,
            port: result.port,
            pairToken: result.token,
          );
    }
  }

  /// Show manual entry dialog with validation
  void _showManualEntryDialog(BuildContext context) async {
    // Pre-fill with last used coordinator
    final connectionProvider = context.read<ConnectionProvider>();
    final lastCoordinator = await connectionProvider.getLastCoordinator();

    if (!mounted) return;

    final hostController = TextEditingController(
      text: lastCoordinator?['host'] ?? '192.168.1.10',
    );
    final portController = TextEditingController(
      text: (lastCoordinator?['port'] ?? 8765).toString(),
    );
    final tokenController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => _ManualEntryDialog(
        hostController: hostController,
        portController: portController,
        tokenController: tokenController,
        onConnect: (host, port, token) {
          Navigator.pop(dialogContext);
          context.read<ConnectionProvider>().connectToCoordinator(
                host: host,
                port: port,
                pairToken: token,
              );
        },
      ),
    );
  }

  void _showUnpairDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unpair Device'),
        content: const Text(
          'This will remove all pairing data. You will need to pair again to use this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ConnectionProvider>().unpair();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.text,
            ),
            child: const Text('Unpair'),
          ),
        ],
      ),
    );
  }
}

/// Manual entry dialog with validation
class _ManualEntryDialog extends StatefulWidget {
  final TextEditingController hostController;
  final TextEditingController portController;
  final TextEditingController tokenController;
  final void Function(String host, int port, String? token) onConnect;

  const _ManualEntryDialog({
    required this.hostController,
    required this.portController,
    required this.tokenController,
    required this.onConnect,
  });

  @override
  State<_ManualEntryDialog> createState() => _ManualEntryDialogState();
}

class _ManualEntryDialogState extends State<_ManualEntryDialog> {
  String? _hostError;
  String? _portError;

  @override
  void initState() {
    super.initState();
    widget.hostController.addListener(_validateHost);
    widget.portController.addListener(_validatePort);
  }

  void _validateHost() {
    final host = widget.hostController.text.trim();
    setState(() {
      if (host.isEmpty) {
        _hostError = 'IP address is required';
      } else if (!_isValidIp(host) && !_isValidHostname(host)) {
        _hostError = 'Enter a valid IP or hostname';
      } else {
        _hostError = null;
      }
    });
  }

  void _validatePort() {
    final portStr = widget.portController.text.trim();
    setState(() {
      if (portStr.isEmpty) {
        _portError = 'Port is required';
      } else {
        final port = int.tryParse(portStr);
        if (port == null || port < 1 || port > 65535) {
          _portError = 'Port must be 1-65535';
        } else {
          _portError = null;
        }
      }
    });
  }

  bool _isValidIp(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) return false;
    }
    return true;
  }

  bool _isValidHostname(String hostname) {
    // Allow simple hostnames and domain names
    final regex = RegExp(r'^[a-zA-Z0-9]([a-zA-Z0-9\-\.]*[a-zA-Z0-9])?$');
    return regex.hasMatch(hostname);
  }

  bool get _isValid => _hostError == null && _portError == null;

  void _submit() {
    _validateHost();
    _validatePort();

    if (_isValid) {
      final host = widget.hostController.text.trim();
      final port = int.tryParse(widget.portController.text.trim()) ?? 8765;
      final token = widget.tokenController.text.trim();

      widget.onConnect(host, port, token.isEmpty ? null : token);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Connect Manually'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: widget.hostController,
              decoration: InputDecoration(
                labelText: 'Host / IP Address',
                hintText: '192.168.1.10',
                errorText: _hostError,
                prefixIcon: const Icon(Icons.computer),
              ),
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: widget.portController,
              decoration: InputDecoration(
                labelText: 'Port',
                hintText: '8765',
                errorText: _portError,
                prefixIcon: const Icon(Icons.numbers),
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: widget.tokenController,
              decoration: const InputDecoration(
                labelText: 'Pair Token (optional)',
                hintText: 'Leave empty if already paired',
                prefixIcon: Icon(Icons.key),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Connect'),
        ),
      ],
    );
  }
}
