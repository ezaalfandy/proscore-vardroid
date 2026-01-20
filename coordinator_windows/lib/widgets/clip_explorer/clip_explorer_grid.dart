import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/remote_clip.dart';
import '../../providers/clip_explorer_provider.dart';
import 'clip_thumbnail_card.dart';
import 'delete_confirmation_dialog.dart';

/// Grid view of clips with thumbnails.
class ClipExplorerGrid extends StatelessWidget {
  const ClipExplorerGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ClipExplorerProvider>(
      builder: (context, provider, child) {
        if (provider.isLoadingClips) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading clips...'),
              ],
            ),
          );
        }

        final clips = provider.currentSessionClips;

        if (clips.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.movie_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No clips in this session',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create marks during recording to generate clips',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Selection toolbar
            if (provider.hasSelection) _buildSelectionToolbar(context, provider),

            // Grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount: clips.length,
                itemBuilder: (context, index) {
                  final clip = clips[index];
                  return ClipThumbnailCard(
                    clip: clip,
                    isSelected: provider.isClipSelected(clip.clipId),
                    onTap: () => _handleTap(context, clip, provider),
                    onLongPress: () => provider.toggleClipSelection(clip.clipId),
                    onPreview: () => _handlePreview(context, clip, provider),
                    onDownload: () => _handleDownload(context, clip, provider),
                    onDelete: () => _handleDelete(context, clip, provider),
                    onRequestThumbnail: () => provider.requestThumbnail(clip),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSelectionToolbar(
    BuildContext context,
    ClipExplorerProvider provider,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border(
          bottom: BorderSide(color: Colors.blue[200]!),
        ),
      ),
      child: Row(
        children: [
          Text(
            '${provider.selectedClipCount} selected',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.blue[700],
            ),
          ),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.select_all, size: 18),
            label: const Text('Select All'),
            onPressed: provider.selectAllClips,
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Download'),
            onPressed: () => provider.downloadSelectedClips(),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
            label: const Text('Delete', style: TextStyle(color: Colors.red)),
            onPressed: () => _handleDeleteSelected(context, provider),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Clear'),
            onPressed: provider.clearSelection,
          ),
        ],
      ),
    );
  }

  void _handleTap(
    BuildContext context,
    RemoteClip clip,
    ClipExplorerProvider provider,
  ) {
    if (provider.hasSelection) {
      provider.toggleClipSelection(clip.clipId);
    } else {
      // Request thumbnail if not loaded
      if (!clip.hasThumbnail && !clip.isThumbnailLoading) {
        provider.requestThumbnail(clip);
      }
    }
  }

  void _handlePreview(
    BuildContext context,
    RemoteClip clip,
    ClipExplorerProvider provider,
  ) {
    provider.previewClip(clip);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting preview for ${clip.clipId}...'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleDownload(
    BuildContext context,
    RemoteClip clip,
    ClipExplorerProvider provider,
  ) async {
    if (clip.isDownloaded) {
      // TODO: Open file
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening ${clip.localPath}...'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final localPath = await provider.downloadClip(clip);
    if (context.mounted) {
      if (localPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded to $localPath'),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Download failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleDelete(
    BuildContext context,
    RemoteClip clip,
    ClipExplorerProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => DeleteConfirmationDialog(
        title: 'Delete Clip',
        message:
            'Are you sure you want to delete this clip?\n\nSize: ${clip.formattedSize}\nDuration: ${clip.formattedDuration}',
        onConfirm: () {
          provider.deleteClip(clip);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _handleDeleteSelected(
    BuildContext context,
    ClipExplorerProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => DeleteConfirmationDialog(
        title: 'Delete ${provider.selectedClipCount} Clips',
        message:
            'Are you sure you want to delete the selected clips?\n\nThis action cannot be undone.',
        onConfirm: () {
          provider.deleteSelectedClips();
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
