import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme_extensions.dart';

class VarCard extends StatelessWidget {
  const VarCard({
    super.key,
    required this.child,
    this.padding,
    this.background,
  });

  final Widget child;
  final EdgeInsets? padding;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: background ?? context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.tokens.border),
      ),
      child: child,
    );
  }
}
