import 'package:flutter/material.dart';

import '../../models/remote_clip.dart';

/// Card widget displaying a clip with thumbnail.
class ClipThumbnailCard extends StatelessWidget {
  final RemoteClip clip;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onPreview;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;
  final VoidCallback? onRequestThumbnail;

  const ClipThumbnailCard({
    super.key,
    required this.clip,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
    this.onPreview,
    this.onDownload,
    this.onDelete,
    this.onRequestThumbnail,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? const BorderSide(color: Colors.blue, width: 2)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail area
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildThumbnail(),
                  _buildOverlays(),
                  if (isSelected) _buildSelectionIndicator(),
                ],
              ),
            ),

            // Info area
            _buildInfoArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (clip.hasThumbnail) {
      return Image.memory(
        clip.thumbnailData!,
        fit: BoxFit.cover,
      );
    }

    if (clip.isThumbnailLoading) {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    // No thumbnail yet - show placeholder and trigger load
    return GestureDetector(
      onTap: onRequestThumbnail,
      child: Container(
        color: Colors.grey[300],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.movie, size: 48, color: Colors.grey[500]),
            const SizedBox(height: 8),
            Text(
              'Tap to load',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlays() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.7),
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Duration
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                clip.formattedDuration,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Download status
            if (clip.isDownloaded)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.download_done,
                  color: Colors.white,
                  size: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionIndicator() {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: const Icon(
          Icons.check,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildInfoArea() {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // File size
          Row(
            children: [
              Icon(Icons.storage, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  clip.formattedSize,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Download progress
          if (clip.isDownloading) ...[
            LinearProgressIndicator(
              value: clip.downloadProgress,
              backgroundColor: Colors.grey[200],
            ),
            const SizedBox(height: 4),
            Text(
              '${(clip.downloadProgress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],

          // Error message
          if (clip.errorMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              clip.errorMessage!,
              style: TextStyle(
                fontSize: 11,
                color: Colors.red[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Action buttons
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: Icons.play_arrow,
                tooltip: 'Preview',
                onPressed: onPreview,
              ),
              _buildActionButton(
                icon: clip.isDownloaded ? Icons.folder_open : Icons.download,
                tooltip: clip.isDownloaded ? 'Open' : 'Download',
                onPressed: onDownload,
                color: clip.isDownloaded ? Colors.green : null,
              ),
              _buildActionButton(
                icon: Icons.delete_outline,
                tooltip: 'Delete',
                onPressed: onDelete,
                color: Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    VoidCallback? onPressed,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 20,
            color: color ?? Colors.grey[700],
          ),
        ),
      ),
    );
  }
}
