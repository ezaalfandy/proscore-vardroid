import 'package:flutter/material.dart';
import '../../../../services/device_status_service.dart';
import '../../../theme/app_colors.dart';

class WarningsOverlay extends StatelessWidget {
  final DeviceStatus? deviceStatus;

  const WarningsOverlay({
    super.key,
    required this.deviceStatus,
  });

  @override
  Widget build(BuildContext context) {
    if (deviceStatus == null) return const SizedBox.shrink();

    final warnings = <String>[];
    if (deviceStatus!.hasLowStorage) {
      warnings.add('LOW STORAGE');
    }
    if (deviceStatus!.isOverheating) {
      warnings.add('OVERHEATING');
    }
    if (deviceStatus!.hasLowBattery && !deviceStatus!.isCharging) {
      warnings.add('LOW BATTERY - PLUG CHARGER');
    }

    if (warnings.isEmpty) return const SizedBox.shrink();

    return Positioned(
      left: 16,
      right: 16,
      bottom: 120,
      child: Column(
        children: warnings
            .map(
              (warning) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: AppColors.text),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        warning,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
