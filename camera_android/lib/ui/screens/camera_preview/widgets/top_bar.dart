import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/connection_provider.dart';
import '../../../theme/app_colors.dart';

class TopBar extends StatelessWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionProvider>(
      builder: (context, connectionProvider, child) {
        final assignedName = connectionProvider.assignedName ?? 'Not Assigned';
        final isConnected = connectionProvider.isConnected;

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
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isConnected ? AppColors.success : AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isConnected ? 'Connected' : 'Disconnected',
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                    ),
                  ),
                ],
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
}
