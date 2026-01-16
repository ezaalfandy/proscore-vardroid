import 'package:flutter/material.dart';
import '../../services/websocket_client_service.dart';
import '../theme/app_colors.dart';

/// Reusable widget showing connection state with coordinator
class ConnectionStatusCard extends StatelessWidget {
  final VarConnectionState connectionState;
  final String? assignedName;
  final String? errorMessage;
  final bool isReconnecting;
  final VoidCallback? onRetry;

  const ConnectionStatusCard({
    super.key,
    required this.connectionState,
    this.assignedName,
    this.errorMessage,
    this.isReconnecting = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getBorderColor(),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status icon with animation
          _buildStatusIcon(),
          const SizedBox(height: 16),

          // Device name or status
          Text(
            assignedName ?? _getStatusTitle(),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Status text
          Text(
            _getStatusText(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _getStatusColor(),
                ),
            textAlign: TextAlign.center,
          ),

          // Error message
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.danger,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.danger,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Retry button on error
          if (connectionState == VarConnectionState.error && onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Connection'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
            ),
          ],

          // Reconnecting indicator
          if (isReconnecting) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Reconnecting...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.warning,
                      ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusIcon() {
    final color = _getStatusColor();
    final icon = _getStatusIcon();

    if (connectionState == VarConnectionState.connecting || isReconnecting) {
      return SizedBox(
        width: 80,
        height: 80,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: color,
              ),
            ),
            Icon(
              icon,
              size: 40,
              color: color,
            ),
          ],
        ),
      );
    }

    return Icon(
      icon,
      size: 80,
      color: color,
    );
  }

  IconData _getStatusIcon() {
    switch (connectionState) {
      case VarConnectionState.disconnected:
        return Icons.link_off;
      case VarConnectionState.connecting:
        return Icons.sync;
      case VarConnectionState.connected:
        return Icons.link;
      case VarConnectionState.paired:
        return Icons.videocam;
      case VarConnectionState.error:
        return Icons.error_outline;
    }
  }

  String _getStatusTitle() {
    switch (connectionState) {
      case VarConnectionState.disconnected:
        return 'Not Connected';
      case VarConnectionState.connecting:
        return 'Connecting...';
      case VarConnectionState.connected:
        return 'Connected';
      case VarConnectionState.paired:
        return 'Paired';
      case VarConnectionState.error:
        return 'Connection Error';
    }
  }

  String _getStatusText() {
    switch (connectionState) {
      case VarConnectionState.disconnected:
        return 'Tap below to connect to coordinator';
      case VarConnectionState.connecting:
        return 'Establishing connection...';
      case VarConnectionState.connected:
        return 'Authenticating with coordinator...';
      case VarConnectionState.paired:
        return 'Ready to record';
      case VarConnectionState.error:
        return 'Failed to connect';
    }
  }

  Color _getStatusColor() {
    switch (connectionState) {
      case VarConnectionState.disconnected:
        return AppColors.textMuted;
      case VarConnectionState.connecting:
        return AppColors.warning;
      case VarConnectionState.connected:
        return AppColors.info;
      case VarConnectionState.paired:
        return AppColors.success;
      case VarConnectionState.error:
        return AppColors.danger;
    }
  }

  Color _getBorderColor() {
    switch (connectionState) {
      case VarConnectionState.disconnected:
        return AppColors.border;
      case VarConnectionState.connecting:
        return AppColors.warning.withValues(alpha: 0.5);
      case VarConnectionState.connected:
        return AppColors.info.withValues(alpha: 0.5);
      case VarConnectionState.paired:
        return AppColors.success.withValues(alpha: 0.5);
      case VarConnectionState.error:
        return AppColors.danger.withValues(alpha: 0.5);
    }
  }
}
