import 'package:flutter/material.dart';

import 'app_theme.dart';

extension AppThemeX on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  AppThemeColors get tokens =>
      Theme.of(this).extension<AppThemeColors>() ??
      const AppThemeColors(
        surfaceAlt: Colors.black,
        border: Colors.black,
        textMuted: Colors.black,
        iconMuted: Colors.black,
        success: Colors.black,
        warning: Colors.black,
      );
}
