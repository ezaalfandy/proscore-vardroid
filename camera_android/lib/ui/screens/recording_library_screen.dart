import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/recording_provider.dart';
import '../../models/recording_session.dart';
import 'video_playback_screen.dart';

class RecordingLibraryScreen extends StatefulWidget {
  const RecordingLibraryScreen({super.key});

  @override
  State<RecordingLibraryScreen> createState() => _RecordingLibraryScreenState();
}

class _RecordingLibraryScreenState extends State<RecordingLibraryScreen> {
  List<RecordingSession> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);

    final recordingProvider = context.read<RecordingProvider>();
    final sessions = await recordingProvider.recordingService.getAllSessions();

    setState(() {
      _sessions = sessions;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recording Library'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSessions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? _buildEmptyState()
              : _buildSessionList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library,
            size: 100,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            'No Recordings',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your recorded sessions will appear here',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionList() {
    return ListView.builder(
      itemCount: _sessions.length,
      itemBuilder: (context, index) {
        final session = _sessions[index];
        return _buildSessionCard(session);
      },
    );
  }

  Widget _buildSessionCard(RecordingSession session) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _showSessionDetails(session),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Match ${session.matchId}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  if (session.isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'RECORDING',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.event, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Event: ${session.eventId}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateTime(session.startedAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.timer, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Duration: ${_formatDuration(session.duration)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatChip(
                    icon: Icons.video_file,
                    label: '${session.segments.length} segments',
                  ),
                  _buildStatChip(
                    icon: Icons.flag,
                    label: '${session.marks.length} marks',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  void _showSessionDetails(RecordingSession session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Session Details',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                _buildDetailRow('Session ID', session.sessionId),
                _buildDetailRow('Event ID', session.eventId),
                _buildDetailRow('Match ID', session.matchId),
                _buildDetailRow('Started', _formatDateTime(session.startedAt)),
                if (session.stoppedAt != null)
                  _buildDetailRow(
                    'Stopped',
                    _formatDateTime(session.stoppedAt!),
                  ),
                _buildDetailRow(
                  'Duration',
                  _formatDuration(session.duration),
                ),
                _buildDetailRow('Segments', '${session.segments.length}'),
                _buildDetailRow('Marks', '${session.marks.length}'),
                const SizedBox(height: 24),
                if (session.marks.isNotEmpty) ...[
                  Text(
                    'Marks',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: session.marks.length,
                      itemBuilder: (context, index) {
                        final mark = session.marks[index];
                        return ListTile(
                          leading: const Icon(Icons.flag, color: Colors.orange),
                          title: Text(mark.markId),
                          subtitle: Text(
                            mark.note ?? 'No note',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Text(
                            _formatDateTime(
                              DateTime.fromMillisecondsSinceEpoch(
                                mark.deviceTs,
                              ),
                            ),
                            style: const TextStyle(fontSize: 11),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _playSession(session);
                        },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Play'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showDeleteConfirmation(session);
                        },
                        icon: const Icon(Icons.delete),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _playSession(RecordingSession session) {
    // Check if we have a full recording or clips
    final hasFullRecording = session.videoPath != null;
    final hasClips = session.clips.isNotEmpty;

    if (!hasFullRecording && !hasClips) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No video found in this session'),
        ),
      );
      return;
    }

    // Show video selection dialog
    _showVideoSelector(session);
  }

  void _showVideoSelector(RecordingSession session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select Video to Play',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    // Full recording option
                    if (session.videoPath != null) ...[
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Icon(Icons.movie, color: Colors.white),
                        ),
                        title: const Text('Full Recording'),
                        subtitle: Text('Duration: ${_formatDuration(session.duration)}'),
                        trailing: const Icon(Icons.play_arrow),
                        onTap: () {
                          Navigator.pop(context);
                          _openVideoPlayer(
                            session.videoPath!,
                            'Match ${session.matchId} - Full Recording',
                          );
                        },
                      ),
                      if (session.clips.isNotEmpty) const Divider(),
                    ],
                    // Clips section
                    if (session.clips.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Extracted Clips',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      ...session.clips.map((clip) => ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.orange,
                              child: Icon(Icons.content_cut, color: Colors.white),
                            ),
                            title: Text('Clip: ${clip.markId}'),
                            subtitle: Text(
                              '${(clip.durationMs / 1000).toStringAsFixed(1)}s - ${_formatFileSize(clip.sizeBytes)}',
                            ),
                            trailing: const Icon(Icons.play_arrow),
                            onTap: () {
                              Navigator.pop(context);
                              _openVideoPlayer(
                                clip.filePath,
                                'Clip: ${clip.markId}',
                              );
                            },
                          )),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _openVideoPlayer(String filePath, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlaybackScreen(
          videoPath: filePath,
          title: title,
        ),
      ),
    );
  }

  void _showDeleteConfirmation(RecordingSession session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recording'),
        content: Text(
          'Are you sure you want to delete the recording for Match ${session.matchId}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteSession(session);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSession(RecordingSession session) async {
    final recordingProvider = context.read<RecordingProvider>();
    final success = await recordingProvider.recordingService.deleteSession(session);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh the list
        _loadSessions();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete recording'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}
