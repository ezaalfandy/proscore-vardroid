import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/clip_explorer_provider.dart';
import 'explorer_breadcrumb.dart';
import 'device_explorer_list.dart';
import 'session_explorer_list.dart';
import 'clip_explorer_grid.dart';

/// Main panel for the clip explorer feature.
/// Provides hierarchical navigation: Devices > Sessions > Clips
class ClipExplorerPanel extends StatelessWidget {
  const ClipExplorerPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ClipExplorerProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            // Header with title and actions
            _buildHeader(context, provider),

            // Breadcrumb navigation
            ExplorerBreadcrumb(
              items: provider.breadcrumbs,
              onTap: provider.navigateToBreadcrumb,
            ),

            // Content area based on current view
            Expanded(
              child: _buildContent(provider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, ClipExplorerProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          if (provider.currentView != ExplorerView.devices)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: provider.navigateBack,
              tooltip: 'Back',
            ),

          // Title
          Icon(
            _getViewIcon(provider.currentView),
            color: Colors.blue[700],
          ),
          const SizedBox(width: 8),
          Text(
            _getViewTitle(provider.currentView),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),

          const Spacer(),

          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: provider.refresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ClipExplorerProvider provider) {
    switch (provider.currentView) {
      case ExplorerView.devices:
        return const DeviceExplorerList();
      case ExplorerView.sessions:
        return const SessionExplorerList();
      case ExplorerView.clips:
        return const ClipExplorerGrid();
    }
  }

  IconData _getViewIcon(ExplorerView view) {
    switch (view) {
      case ExplorerView.devices:
        return Icons.devices;
      case ExplorerView.sessions:
        return Icons.video_library;
      case ExplorerView.clips:
        return Icons.movie;
    }
  }

  String _getViewTitle(ExplorerView view) {
    switch (view) {
      case ExplorerView.devices:
        return 'Clip Explorer';
      case ExplorerView.sessions:
        return 'Sessions';
      case ExplorerView.clips:
        return 'Clips';
    }
  }
}
