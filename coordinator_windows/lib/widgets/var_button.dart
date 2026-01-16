import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme_extensions.dart';

enum VarButtonStyle { primary, secondary, danger, ghost }

class VarButton extends StatelessWidget {
  const VarButton._({
    required this.label,
    required this.onPressed,
    required this.style,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final VarButtonStyle style;
  final IconData? icon;

  factory VarButton.primary({
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
  }) {
    return VarButton._(
      label: label,
      onPressed: onPressed,
      icon: icon,
      style: VarButtonStyle.primary,
    );
  }

  factory VarButton.secondary({
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
  }) {
    return VarButton._(
      label: label,
      onPressed: onPressed,
      icon: icon,
      style: VarButtonStyle.secondary,
    );
  }

  factory VarButton.danger({
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
  }) {
    return VarButton._(
      label: label,
      onPressed: onPressed,
      icon: icon,
      style: VarButtonStyle.danger,
    );
  }

  factory VarButton.ghost({
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
  }) {
    return VarButton._(
      label: label,
      onPressed: onPressed,
      icon: icon,
      style: VarButtonStyle.ghost,
    );
  }

  @override
  Widget build(BuildContext context) {
    final buttonStyle = switch (style) {
      VarButtonStyle.primary => _primaryStyle(context),
      VarButtonStyle.secondary => _secondaryStyle(context),
      VarButtonStyle.danger => _dangerStyle(context),
      VarButtonStyle.ghost => _ghostStyle(context),
    };

    return SizedBox(
      height: 36,
      child: TextButton(
        onPressed: onPressed,
        style: buttonStyle,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: AppSpacing.space2),
            ],
            Text(label),
          ],
        ),
      ),
    );
  }

  static ButtonStyle _primaryStyle(BuildContext context) {
    return TextButton.styleFrom(
      foregroundColor: context.colors.onPrimary,
      backgroundColor: context.colors.primary,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    );
  }

  static ButtonStyle _secondaryStyle(BuildContext context) {
    return TextButton.styleFrom(
      foregroundColor: context.colors.onSurface,
      backgroundColor: context.colors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        side: BorderSide(color: context.tokens.border),
      ),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    );
  }

  static ButtonStyle _dangerStyle(BuildContext context) {
    return TextButton.styleFrom(
      foregroundColor: context.colors.onError,
      backgroundColor: context.colors.error,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    );
  }

  static ButtonStyle _ghostStyle(BuildContext context) {
    return TextButton.styleFrom(
      foregroundColor: context.colors.onSurface,
      backgroundColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space3,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    );
  }
}
