import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/recording_provider.dart';
import '../../../../services/device_status_service.dart';
import '../../../theme/app_colors.dart';

class StatusPanel extends StatelessWidget {
  final DeviceStatus? deviceStatus;

  const StatusPanel({
    super.key,
    required this.deviceStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordingProvider>(
      builder: (context, recordingProvider, child) {
        final isRecording = recordingProvider.isRecording;
        final session = recordingProvider.currentSession;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Recording Status
              Row(
                children: [
                  if (isRecording)
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    isRecording ? 'RECORDING' : 'STANDBY',
                    style: TextStyle(
                      color: isRecording ? AppColors.primary : AppColors.textMuted,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),

              if (session != null && isRecording) ...[
                const SizedBox(height: 8),
                Text(
                  _formatDuration(session.duration),
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],

              const Divider(color: AppColors.border, height: 20),

              // Device Status
              if (deviceStatus != null) ...[
                _buildStatusRow(
                  Icons.battery_std,
                  '${deviceStatus!.battery}%',
                  deviceStatus!.hasLowBattery ? AppColors.danger : AppColors.text,
                ),
                const SizedBox(height: 6),
                _buildStatusRow(
                  Icons.thermostat,
                  '${deviceStatus!.temperature.toStringAsFixed(1)}C',
                  deviceStatus!.isOverheating ? AppColors.danger : AppColors.text,
                ),
                const SizedBox(height: 6),
                _buildStatusRow(
                  Icons.storage,
                  '${(deviceStatus!.freeSpaceMB / 1024).toStringAsFixed(1)}GB',
                  deviceStatus!.hasLowStorage ? AppColors.danger : AppColors.text,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusRow(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }
}
