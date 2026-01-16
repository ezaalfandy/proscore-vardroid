import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme_extensions.dart';

class DeviceStatusRow extends StatelessWidget {
  const DeviceStatusRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: context.tokens.iconMuted),
        const SizedBox(width: AppSpacing.space2),
        Expanded(
          child: Text(
            label,
            style: context.text.bodySmall?.copyWith(
              color: context.tokens.textMuted,
            ),
          ),
        ),
        Text(
          value,
          style: context.text.bodyMedium,
        ),
      ],
    );
  }
}
