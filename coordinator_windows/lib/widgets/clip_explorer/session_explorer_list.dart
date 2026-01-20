import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/remote_session.dart';
import '../../providers/clip_explorer_provider.dart';
import 'delete_confirmation_dialog.dart';

/// List of sessions for clip explorer, grouped by event.
class SessionExplorerList extends StatelessWidget {
  const SessionExplorerList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ClipExplorerProvider>(
      builder: (context, provider, child) {
        if (provider.isLoadingSessions) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading sessions...'),
              ],
            ),
          );
        }

        final groupedSessions = provider.sessionsGroupedByEvent;

        if (groupedSessions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.video_library_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No sessions found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Record some matches to see sessions here',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final entry in groupedSessions.entries) ...[
              _buildEventHeader(entry.key),
              const SizedBox(height: 8),
              ...entry.value.map((session) => _buildSessionCard(
                    context,
                    session,
                    provider,
                  )),
              const SizedBox(height: 16),
            ],
          ],
        );
      },
    );
  }

  Widget _buildEventHeader(String eventName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Row(
        children: [
          Icon(Icons.event, color: Colors.blue[700], size: 20),
          const SizedBox(width: 8),
          Text(
            eventName,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(
    BuildContext context,
    RemoteSession session,
    ClipExplorerProvider provider,
  ) {
    final dateFormat = DateFormat('MMM d, yyyy HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => provider.selectSession(session.sessionId),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Session icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.play_circle_outline,
                  color: Colors.green[700],
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),

              // Session info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          dateFormat.format(session.startedAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildInfoBadge(
                          Icons.movie,
                          '${session.clipCount} clips',
                          Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        if (session.duration != null)
                          _buildInfoBadge(
                            Icons.timer,
                            session.formattedDuration,
                            Colors.purple,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                onSelected: (value) {
                  switch (value) {
                    case 'delete':
                      _showDeleteConfirmation(context, session, provider);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Delete Session'),
                      ],
                    ),
                  ),
                ],
              ),

              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    RemoteSession session,
    ClipExplorerProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => DeleteConfirmationDialog(
        title: 'Delete Session',
        message:
            'Are you sure you want to delete "${session.displayName}"?\n\nThis will permanently delete the session and all ${session.clipCount} clips from the device.',
        onConfirm: () {
          provider.deleteSession(session);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
