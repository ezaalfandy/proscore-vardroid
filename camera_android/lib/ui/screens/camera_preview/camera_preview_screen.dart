import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../providers/recording_provider.dart';
import '../../../services/device_status_service.dart';
import 'widgets/camera_preview_widget.dart';
import 'widgets/top_bar.dart';
import 'widgets/status_panel.dart';
import 'widgets/bottom_controls.dart';
import 'widgets/camera_controls.dart';
import 'widgets/settings_panel.dart';
import 'widgets/lock_overlay.dart';
import 'widgets/warnings_overlay.dart';

class CameraPreviewScreen extends StatefulWidget {
  const CameraPreviewScreen({super.key});

  @override
  State<CameraPreviewScreen> createState() => _CameraPreviewScreenState();
}

class _CameraPreviewScreenState extends State<CameraPreviewScreen> {
  final DeviceStatusService _statusService = DeviceStatusService();
  DeviceStatus? _deviceStatus;
  bool _isScreenLocked = false;
  bool _showSettingsPanel = false;

  @override
  void initState() {
    super.initState();
    _lockToLandscape();
    _initializeScreen();
    _startStatusUpdates();
  }

  @override
  void dispose() {
    _unlockOrientation();
    WakelockPlus.disable();
    super.dispose();
  }

  void _lockToLandscape() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _unlockOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _initializeScreen() async {
    await WakelockPlus.enable();

    final recordingProvider = context.read<RecordingProvider>();
    if (!recordingProvider.isCameraInitialized) {
      await recordingProvider.initializeCamera();
    }
  }

  void _startStatusUpdates() {
    Future.delayed(const Duration(seconds: 2), () async {
      if (mounted) {
        final status = await _statusService.getStatus();
        setState(() {
          _deviceStatus = status;
        });
        _startStatusUpdates();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera Preview (handles focus, zoom, exposure internally)
            const CameraPreviewWidget(),

            // Top Bar
            const TopBar(),

            // Status Panel
            Positioned(
              right: 8,
              top: 60,
              child: StatusPanel(deviceStatus: _deviceStatus),
            ),

            // Camera Controls (Left side)
            if (!_isScreenLocked && !_showSettingsPanel)
              Positioned(
                left: 8,
                top: 60,
                child: CameraControls(
                  onSettingsPressed: () {
                    setState(() {
                      _showSettingsPanel = !_showSettingsPanel;
                    });
                  },
                ),
              ),

            // Bottom Control Strip
            if (!_isScreenLocked)
              BottomControls(
                onLockScreen: () {
                  setState(() {
                    _isScreenLocked = true;
                  });
                },
              ),

            // Settings Panel
            if (_showSettingsPanel)
              SettingsPanel(
                onClose: () {
                  setState(() {
                    _showSettingsPanel = false;
                  });
                },
              ),

            // Lock Screen Overlay
            if (_isScreenLocked)
              LockOverlay(
                onUnlock: () {
                  setState(() {
                    _isScreenLocked = false;
                  });
                },
              ),

            // Warnings
            WarningsOverlay(deviceStatus: _deviceStatus),
          ],
        ),
      ),
    );
  }
}
