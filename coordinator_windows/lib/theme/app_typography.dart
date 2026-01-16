import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTypography {
  static TextTheme textTheme = const TextTheme(
    displaySmall: TextStyle(
      fontSize: 28,
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
    labelSmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppColors.textMuted,
    ),
  );
}
