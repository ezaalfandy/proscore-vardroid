import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../providers/recording_provider.dart';
import '../../../theme/app_colors.dart';
import 'focus_exposure_control.dart';

class CameraPreviewWidget extends StatefulWidget {
  const CameraPreviewWidget({super.key});

  @override
  State<CameraPreviewWidget> createState() => _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends State<CameraPreviewWidget> {
  // Focus/Exposure state
  Offset? _focusPoint;
  bool _showFocusControl = false;

  // Zoom gesture tracking
  double _baseZoom = 1.0;

  void _handleTapToFocus(
    TapUpDetails details,
    BoxConstraints constraints,
    RecordingProvider recordingProvider,
  ) {
    final tapPosition = details.localPosition;

    // Normalize tap position to 0.0 - 1.0
    final normalizedX = tapPosition.dx / constraints.maxWidth;
    final normalizedY = tapPosition.dy / constraints.maxHeight;

    // Set focus point on camera
    recordingProvider.setFocusPoint(Offset(normalizedX, normalizedY));

    // Show focus/exposure control
    setState(() {
      _focusPoint = tapPosition;
      _showFocusControl = true;
    });
  }

  void _handleZoomStart(RecordingProvider recordingProvider) {
    _baseZoom = recordingProvider.recordingService.currentZoom;
  }

  void _handleZoomUpdate(
    ScaleUpdateDetails details,
    RecordingProvider recordingProvider,
  ) {
    // Only handle zoom if scale changed (pinch gesture)
    if (details.scale == 1.0) return;

    final recordingService = recordingProvider.recordingService;
    final newZoom = (_baseZoom * details.scale).clamp(
      recordingService.minZoom,
      recordingService.maxZoom,
    );
    recordingProvider.setZoom(newZoom);
  }

  void _dismissFocusControl() {
    setState(() {
      _showFocusControl = false;
      _focusPoint = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordingProvider>(
      builder: (context, recordingProvider, child) {
        // Show error state with retry options
        if (recordingProvider.errorMessage != null) {
          return _buildErrorState(context, recordingProvider);
        }

        if (!recordingProvider.isCameraInitialized) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.text),
          );
        }

        final controller = recordingProvider.recordingService.cameraController;
        if (controller == null) {
          return const Center(
            child: Text(
              'Camera not available',
              style: TextStyle(color: AppColors.text),
            ),
          );
        }

        final previewSize = controller.value.previewSize;
        if (previewSize == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.text),
          );
        }

        // For landscape mode, use width/height directly
        final cameraAspectRatio = previewSize.width / previewSize.height;

        return LayoutBuilder(
          builder: (context, constraints) {
            final screenAspectRatio = constraints.maxWidth / constraints.maxHeight;

            double previewWidth;
            double previewHeight;

            if (screenAspectRatio > cameraAspectRatio) {
              previewWidth = constraints.maxWidth;
              previewHeight = previewWidth / cameraAspectRatio;
            } else {
              previewHeight = constraints.maxHeight;
              previewWidth = previewHeight * cameraAspectRatio;
            }

            return GestureDetector(
              onTapUp: (details) => _handleTapToFocus(
                details,
                constraints,
                recordingProvider,
              ),
              onScaleStart: (_) => _handleZoomStart(recordingProvider),
              onScaleUpdate: (details) => _handleZoomUpdate(
                details,
                recordingProvider,
              ),
              child: Stack(
                children: [
                  // Camera preview
                  ClipRect(
                    child: OverflowBox(
                      maxWidth: previewWidth,
                      maxHeight: previewHeight,
                      child: CameraPreview(controller),
                    ),
                  ),

                  // Focus/Exposure control
                  if (_showFocusControl && _focusPoint != null)
                    FocusExposureControl(
                      position: _focusPoint!,
                      currentExposure: recordingProvider.recordingService.currentExposureOffset,
                      minExposure: recordingProvider.recordingService.minExposureOffset,
                      maxExposure: recordingProvider.recordingService.maxExposureOffset,
                      onExposureChanged: (value) {
                        recordingProvider.setExposureOffset(value);
                      },
                      onDismiss: _dismissFocusControl,
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildErrorState(BuildContext context, RecordingProvider recordingProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.videocam_off,
              size: 64,
              color: AppColors.iconMuted,
            ),
            const SizedBox(height: 16),
            Text(
              recordingProvider.errorMessage!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                await recordingProvider.initializeCamera();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => openAppSettings(),
              icon: const Icon(Icons.settings, color: AppColors.textMuted),
              label: const Text(
                'Open Settings',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
