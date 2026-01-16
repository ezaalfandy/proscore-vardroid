import 'package:flutter/material.dart';

import '../theme/app_theme_extensions.dart';

enum DeviceStatus {
  disconnected,
  connecting,
  unpaired,
  paired,
  recording,
  exporting,
  error,
}

class StatusDot extends StatelessWidget {
  const StatusDot({
    super.key,
    required this.status,
    this.size = 10,
  });

  final DeviceStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = _colorForStatus(context);
    final showPulse = status == DeviceStatus.recording;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: showPulse
            ? [
                BoxShadow(
                  color: color.withOpacity(0.6),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }

  Color _colorForStatus(BuildContext context) {
    switch (status) {
      case DeviceStatus.disconnected:
        return context.colors.error;
      case DeviceStatus.connecting:
        return context.tokens.warning;
      case DeviceStatus.unpaired:
        return context.colors.secondary;
      case DeviceStatus.paired:
        return context.tokens.success;
      case DeviceStatus.recording:
        return context.colors.primary;
      case DeviceStatus.exporting:
        return context.colors.secondary;
      case DeviceStatus.error:
        return context.colors.error;
    }
  }
}
