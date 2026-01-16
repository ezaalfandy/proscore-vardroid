import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/recording_provider.dart';
import '../../../theme/app_colors.dart';

class CameraControls extends StatelessWidget {
  final VoidCallback onSettingsPressed;

  const CameraControls({
    super.key,
    required this.onSettingsPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordingProvider>(
      builder: (context, recordingProvider, child) {
        final recordingService = recordingProvider.recordingService;
        final availableCameras = recordingService.availableVARCameras;

        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Camera Switch Button
              if (availableCameras.length > 1)
                IconButton(
                  icon: const Icon(Icons.flip_camera_android, color: AppColors.text),
                  onPressed: recordingProvider.isRecording
                      ? null
                      : () async {
                          await recordingProvider.toggleCamera();
                        },
                  tooltip: 'Switch Camera',
                ),

              const SizedBox(height: 8),

              // Settings Button
              IconButton(
                icon: const Icon(Icons.tune, color: AppColors.text),
                onPressed: onSettingsPressed,
                tooltip: 'Video Settings',
              ),
            ],
          ),
        );
      },
    );
  }
}
