import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

class LockOverlay extends StatelessWidget {
  final VoidCallback onUnlock;

  const LockOverlay({
    super.key,
    required this.onUnlock,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: onUnlock,
      child: Container(
        color: AppColors.background.withOpacity(0.6),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock,
                color: AppColors.text,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Screen Locked',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Double tap to unlock',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
