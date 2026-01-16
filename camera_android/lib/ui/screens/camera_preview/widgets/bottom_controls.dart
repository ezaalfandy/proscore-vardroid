import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/recording_provider.dart';
import '../../../theme/app_colors.dart';

class BottomControls extends StatelessWidget {
  final VoidCallback onLockScreen;

  const BottomControls({
    super.key,
    required this.onLockScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              AppColors.background.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Consumer<RecordingProvider>(
          builder: (context, recordingProvider, child) {
            final isRecording = recordingProvider.isRecording;

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Emergency Start/Stop
                _buildControlButton(
                  icon: isRecording ? Icons.stop : Icons.play_arrow,
                  label: isRecording ? 'Stop' : 'Start',
                  color: isRecording ? AppColors.danger : AppColors.success,
                  onPressed: () async {
                    if (isRecording) {
                      await recordingProvider.emergencyStopRecording();
                    } else {
                      await recordingProvider.emergencyStartRecording();
                    }
                  },
                ),

                // Mark Button
                _buildControlButton(
                  icon: Icons.flag,
                  label: 'Mark',
                  color: AppColors.warning,
                  onPressed: isRecording
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Mark button (coordinator controls this)'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        }
                      : null,
                ),

                // Lock Screen
                _buildControlButton(
                  icon: Icons.lock,
                  label: 'Lock',
                  color: AppColors.primary,
                  onPressed: onLockScreen,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: AppColors.text,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(16),
          ),
          child: Icon(icon, size: 28),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
