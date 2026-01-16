import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import '../theme/app_colors.dart';

/// Data parsed from coordinator QR code
class QrPairingData {
  final String host;
  final int port;
  final String? token;

  QrPairingData({
    required this.host,
    required this.port,
    this.token,
  });

  /// Parse QR code data in format: var://pair?host=192.168.1.100&port=8765&token=abc123
  static QrPairingData? parse(String data) {
    try {
      final uri = Uri.parse(data);

      // Check if it's our protocol
      if (uri.scheme != 'var' || uri.host != 'pair') {
        return null;
      }

      final host = uri.queryParameters['host'];
      final portStr = uri.queryParameters['port'];
      final token = uri.queryParameters['token'];

      if (host == null || host.isEmpty) {
        return null;
      }

      final port = int.tryParse(portStr ?? '8765') ?? 8765;

      return QrPairingData(
        host: host,
        port: port,
        token: token?.isNotEmpty == true ? token : null,
      );
    } catch (e) {
      return null;
    }
  }
}

/// QR code scanner screen for pairing with coordinator
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void reassemble() {
    super.reassemble();
    // Pause/resume camera on hot reload
    if (controller != null) {
      controller!.pauseCamera();
      controller!.resumeCamera();
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen(_onScan);
  }

  void _onScan(Barcode scanData) {
    if (_isProcessing) return;
    if (scanData.code == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final data = QrPairingData.parse(scanData.code!);

    if (data != null) {
      // Valid QR code, return the data
      controller?.pauseCamera();
      Navigator.of(context).pop(data);
    } else {
      // Invalid QR code
      setState(() {
        _errorMessage = 'Invalid QR code. Please scan the coordinator QR code.';
        _isProcessing = false;
      });

      // Clear error after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _errorMessage = null;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // QR Scanner
          QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: AppColors.primary,
              borderRadius: 12,
              borderLength: 30,
              borderWidth: 8,
              cutOutSize: MediaQuery.of(context).size.width * 0.7,
            ),
          ),

          // Top bar with back button and title
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surface.withValues(alpha: 0.8),
                      foregroundColor: AppColors.text,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Scan Coordinator QR',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.text,
                          shadows: [
                            const Shadow(
                              blurRadius: 4,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                  ),
                ],
              ),
            ),
          ),

          // Instructions
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.qr_code_scanner,
                        color: AppColors.primary,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Point at the QR code displayed on the coordinator screen',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.text,
                            ),
                      ),
                    ],
                  ),
                ),

                // Error message
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.text,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.text,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Flash and camera switch buttons
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => controller?.toggleFlash(),
                  icon: const Icon(Icons.flash_on),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surface.withValues(alpha: 0.8),
                    foregroundColor: AppColors.text,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(width: 24),
                IconButton(
                  onPressed: () => controller?.flipCamera(),
                  icon: const Icon(Icons.cameraswitch),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surface.withValues(alpha: 0.8),
                    foregroundColor: AppColors.text,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
