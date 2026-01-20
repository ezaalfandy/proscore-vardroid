import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/clip_explorer_provider.dart';

/// List of connected devices for clip explorer.
class DeviceExplorerList extends StatelessWidget {
  const DeviceExplorerList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ClipExplorerProvider>(
      builder: (context, provider, child) {
        final devices = provider.connectedDevices;

        if (devices.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.devices, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No devices connected',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Connect Android devices to browse clips',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: devices.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final connectedDevice = devices[index];
            final deviceId = connectedDevice.id;
            final sessionCount = provider.getSessionCountForDevice(deviceId);
            final clipCount = provider.getClipCountForDevice(deviceId);

            return Card(
              elevation: 2,
              child: ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.smartphone,
                    color: Colors.blue[700],
                    size: 28,
                  ),
                ),
                title: Text(
                  connectedDevice.assignedName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildInfoChip(
                          Icons.video_library,
                          sessionCount > 0 ? '$sessionCount sessions' : 'No sessions loaded',
                        ),
                        const SizedBox(width: 8),
                        if (clipCount > 0)
                          _buildInfoChip(
                            Icons.movie,
                            '$clipCount clips',
                          ),
                      ],
                    ),
                  ],
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: Colors.grey[400],
                ),
                onTap: () => provider.selectDevice(deviceId),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
