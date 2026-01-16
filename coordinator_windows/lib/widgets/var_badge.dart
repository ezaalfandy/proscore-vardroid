import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme_extensions.dart';

class VarBadge extends StatelessWidget {
  const VarBadge({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space3,
        vertical: AppSpacing.space2,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(
        label,
        style: context.text.bodySmall?.copyWith(color: color),
      ),
    );
  }
}
