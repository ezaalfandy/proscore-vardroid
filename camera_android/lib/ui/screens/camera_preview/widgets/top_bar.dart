import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/connection_provider.dart';
import '../../../../services/websocket_client_service.dart';
import '../../../theme/app_colors.dart';

class TopBar extends StatelessWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionProvider>(
      builder: (context, connectionProvider, child) {
        final assignedName = connectionProvider.assignedName ?? 'Not Assigned';
        final connectionState = connectionProvider.connectionState;
        final isReconnecting = connectionProvider.isReconnecting;
        final errorMessage = connectionProvider.errorMessage;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.background.withOpacity(0.7),
                Colors.transparent,
              ],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Assigned Camera Slot
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  assignedName,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),

              // Connection Indicator
              _buildConnectionIndicator(
                context,
                connectionProvider,
                connectionState,
                isReconnecting,
                errorMessage,
              ),

              // Back button
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.text),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectionIndicator(
    BuildContext context,
    ConnectionProvider connectionProvider,
    VarConnectionState connectionState,
    bool isReconnecting,
    String? errorMessage,
  ) {
    Color dotColor;
    String statusText;
    bool showRetryButton = false;

    if (isReconnecting) {
      dotColor = AppColors.warning;
      statusText = 'Reconnecting...';
    } else {
      switch (connectionState) {
        case VarConnectionState.paired:
        case VarConnectionState.connected:
          dotColor = AppColors.success;
          statusText = 'Connected';
          break;
        case VarConnectionState.connecting:
          dotColor = AppColors.warning;
          statusText = 'Connecting...';
          break;
        case VarConnectionState.error:
          dotColor = AppColors.danger;
          statusText = 'Error';
          showRetryButton = true;
          break;
        case VarConnectionState.disconnected:
          dotColor = Colors.grey;
          statusText = 'Disconnected';
          showRetryButton = true;
          break;
      }
    }

    return GestureDetector(
      onTap: connectionState == VarConnectionState.error && errorMessage != null
          ? () => _showErrorDialog(context, errorMessage, connectionProvider)
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 14,
            ),
          ),
          if (showRetryButton) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => connectionProvider.retryConnection(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showErrorDialog(
    BuildContext context,
    String errorMessage,
    ConnectionProvider connectionProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Connection Error',
          style: TextStyle(color: AppColors.text),
        ),
        content: Text(
          errorMessage,
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              connectionProvider.retryConnection();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
