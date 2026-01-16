import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTypography {
  static TextTheme get textTheme => const TextTheme(
        displaySmall: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.text,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.text,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textMuted,
        ),
      );

  static const TextStyle mono = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    fontFamily: 'monospace',
    color: AppColors.textMuted,
  );
}
