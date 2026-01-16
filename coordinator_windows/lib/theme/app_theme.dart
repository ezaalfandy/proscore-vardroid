import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

class AppThemeColors extends ThemeExtension<AppThemeColors> {
  const AppThemeColors({
    required this.surfaceAlt,
    required this.border,
    required this.textMuted,
    required this.iconMuted,
    required this.success,
    required this.warning,
  });

  final Color surfaceAlt;
  final Color border;
  final Color textMuted;
  final Color iconMuted;
  final Color success;
  final Color warning;

  @override
  AppThemeColors copyWith({
    Color? surfaceAlt,
    Color? border,
    Color? textMuted,
    Color? iconMuted,
    Color? success,
    Color? warning,
  }) {
    return AppThemeColors(
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      textMuted: textMuted ?? this.textMuted,
      iconMuted: iconMuted ?? this.iconMuted,
      success: success ?? this.success,
      warning: warning ?? this.warning,
    );
  }

  @override
  ThemeExtension<AppThemeColors> lerp(
    ThemeExtension<AppThemeColors>? other,
    double t,
  ) {
    if (other is! AppThemeColors) {
      return this;
    }
    return AppThemeColors(
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t) ?? surfaceAlt,
      border: Color.lerp(border, other.border, t) ?? border,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
      iconMuted: Color.lerp(iconMuted, other.iconMuted, t) ?? iconMuted,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
    );
  }
}

class AppTheme {
  static ThemeData dark() {
    final colorScheme = const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.info,
      onSecondary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      background: AppColors.background,
      onBackground: AppColors.text,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: AppTypography.textTheme,
      dividerColor: AppColors.border,
      cardTheme: CardThemeData(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.surfaceAlt,
        contentTextStyle: TextStyle(color: AppColors.text),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space4,
          vertical: AppSpacing.space3,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(120, 36),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space4,
            vertical: AppSpacing.space2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(120, 36),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space4,
            vertical: AppSpacing.space2,
          ),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      extensions: const [
        AppThemeColors(
          surfaceAlt: AppColors.surfaceAlt,
          border: AppColors.border,
          textMuted: AppColors.textMuted,
          iconMuted: AppColors.iconMuted,
          success: AppColors.success,
          warning: AppColors.warning,
        ),
      ],
    );
  }
}
