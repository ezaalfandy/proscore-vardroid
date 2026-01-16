import 'package:flutter/material.dart';

import 'screens/coordinator_home.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const CoordinatorApp());
}

class CoordinatorApp extends StatelessWidget {
  const CoordinatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VAR Coordinator',
      theme: AppTheme.dark(),
      debugShowCheckedModeBanner: false,
      home: const CoordinatorHome(),
    );
  }
}
