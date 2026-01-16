import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import '../../../../providers/recording_provider.dart';
import '../../../theme/app_colors.dart';

class SettingsPanel extends StatelessWidget {
  final VoidCallback onClose;

  const SettingsPanel({
    super.key,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordingProvider>(
      builder: (context, recordingProvider, child) {
        final recordingService = recordingProvider.recordingService;
        final currentResolution = recordingService.currentResolution;
        final currentFps = recordingService.currentFps;
        final availableCameras = recordingService.availableVARCameras;
        final currentCamera = recordingService.currentCamera;

        return Container(
          width: double.infinity,
          height: double.infinity,
          color: AppColors.background.withOpacity(0.9),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(),

                  const SizedBox(height: 16),

                  // Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Camera Selection
                          if (availableCameras.length > 1)
                            _buildCameraSelection(
                              recordingProvider,
                              recordingService,
                              availableCameras,
                              currentCamera,
                            ),

                          // Resolution Selection
                          _buildResolutionSelection(
                            recordingProvider,
                            recordingService,
                            currentResolution,
                          ),

                          const SizedBox(height: 24),

                          // FPS Selection
                          _buildFpsSelection(
                            recordingProvider,
                            currentFps,
                          ),

                          const SizedBox(height: 24),
                          const Divider(color: AppColors.border),
                          const SizedBox(height: 16),

                          // Camera Adjustments Section
                          _buildCameraAdjustments(recordingProvider, recordingService),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // Info text (outside scroll area)
                  if (recordingProvider.isRecording) _buildRecordingWarning(),

                  // Close Button
                  _buildCloseButton(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Camera Settings',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: AppColors.text),
          onPressed: onClose,
        ),
      ],
    );
  }

  Widget _buildCameraSelection(
    RecordingProvider recordingProvider,
    dynamic recordingService,
    List<CameraDescription> availableCameras,
    CameraDescription? currentCamera,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Camera',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: availableCameras.map((camera) {
            final isSelected = camera == currentCamera;
            return ChoiceChip(
              label: Text(recordingService.getCameraName(camera)),
              selected: isSelected,
              onSelected: recordingProvider.isRecording
                  ? null
                  : (selected) async {
                      if (selected) {
                        await recordingProvider.switchCamera(camera);
                      }
                    },
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.text : AppColors.textMuted,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildResolutionSelection(
    RecordingProvider recordingProvider,
    dynamic recordingService,
    ResolutionPreset currentResolution,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resolution',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ResolutionPreset.high,
            ResolutionPreset.veryHigh,
            ResolutionPreset.ultraHigh,
          ].map((preset) {
            final isSelected = preset == currentResolution;
            return ChoiceChip(
              label: Text(recordingService.getResolutionName(preset)),
              selected: isSelected,
              onSelected: recordingProvider.isRecording
                  ? null
                  : (selected) async {
                      if (selected) {
                        await recordingProvider.changeResolution(preset);
                      }
                    },
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.text : AppColors.textMuted,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFpsSelection(
    RecordingProvider recordingProvider,
    int currentFps,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Frame Rate',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [30, 60].map((fps) {
            final isSelected = fps == currentFps;
            return ChoiceChip(
              label: Text('$fps FPS'),
              selected: isSelected,
              onSelected: recordingProvider.isRecording
                  ? null
                  : (selected) async {
                      if (selected) {
                        await recordingProvider.changeFps(fps);
                      }
                    },
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.text : AppColors.textMuted,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCameraAdjustments(
    RecordingProvider recordingProvider,
    dynamic recordingService,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Camera Adjustments',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Zoom Slider
        Row(
          children: [
            const Icon(Icons.zoom_out, color: AppColors.textMuted, size: 20),
            Expanded(
              child: Slider(
                value: recordingService.currentZoom,
                min: recordingService.minZoom,
                max: recordingService.maxZoom,
                onChanged: (value) {
                  recordingProvider.setZoom(value);
                },
                activeColor: AppColors.primary,
                inactiveColor: AppColors.border,
              ),
            ),
            const Icon(Icons.zoom_in, color: AppColors.textMuted, size: 20),
            const SizedBox(width: 8),
            SizedBox(
              width: 50,
              child: Text(
                '${recordingService.currentZoom.toStringAsFixed(1)}x',
                style: const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const Text(
          'Zoom',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),

        const SizedBox(height: 12),

        // Brightness/Exposure Slider
        Row(
          children: [
            const Icon(Icons.brightness_low, color: AppColors.textMuted, size: 20),
            Expanded(
              child: Slider(
                value: recordingService.currentExposureOffset,
                min: recordingService.minExposureOffset,
                max: recordingService.maxExposureOffset,
                onChanged: (value) {
                  recordingProvider.setExposureOffset(value);
                },
                activeColor: AppColors.primary,
                inactiveColor: AppColors.border,
              ),
            ),
            const Icon(Icons.brightness_high, color: AppColors.textMuted, size: 20),
            const SizedBox(width: 8),
            SizedBox(
              width: 50,
              child: Text(
                recordingService.currentExposureOffset >= 0
                    ? '+${recordingService.currentExposureOffset.toStringAsFixed(1)}'
                    : recordingService.currentExposureOffset.toStringAsFixed(1),
                style: const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const Text(
          'Brightness',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),

        const SizedBox(height: 16),

        // Focus Mode Toggle
        Row(
          children: [
            const Text(
              'Focus Mode',
              style: TextStyle(color: AppColors.text, fontSize: 14),
            ),
            const SizedBox(width: 16),
            ChoiceChip(
              label: const Text('Auto'),
              selected: recordingService.focusMode == FocusMode.auto,
              onSelected: (selected) {
                if (selected) {
                  recordingProvider.setFocusMode(FocusMode.auto);
                }
              },
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: recordingService.focusMode == FocusMode.auto
                    ? AppColors.text
                    : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Locked'),
              selected: recordingService.focusMode == FocusMode.locked,
              onSelected: (selected) {
                if (selected) {
                  recordingProvider.setFocusMode(FocusMode.locked);
                }
              },
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: recordingService.focusMode == FocusMode.locked
                    ? AppColors.text
                    : AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Tap on preview to focus. Use Locked to maintain focus.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildRecordingWarning() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.warning),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Resolution and FPS cannot be changed while recording. Zoom, brightness, and focus can still be adjusted.',
              style: TextStyle(color: AppColors.warning, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloseButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onClose,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: AppColors.primary,
        ),
        child: const Text('Done'),
      ),
    );
  }
}
