import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../models/playback_state.dart';
import '../providers/playback_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'playback_controls.dart';
import 'zoomable_mjpeg_view.dart';

/// Fullscreen playback overlay with keyboard shortcuts.
class PlaybackOverlay extends StatefulWidget {
  const PlaybackOverlay({
    super.key,
    required this.onClose,
  });

  final VoidCallback onClose;

  @override
  State<PlaybackOverlay> createState() => _PlaybackOverlayState();
}

class _PlaybackOverlayState extends State<PlaybackOverlay> {
  final FocusNode _focusNode = FocusNode();
  bool _showControls = true;
  bool _showHelp = false;

  @override
  void initState() {
    super.initState();
    // Request focus for keyboard events
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaybackProvider>(
      builder: (context, playback, _) {
        if (!playback.isPlaybackActive) {
          // Close overlay when playback becomes inactive
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onClose();
          });
          return const SizedBox.shrink();
        }

        return KeyboardListener(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (event) => _handleKeyEvent(event, playback),
          child: GestureDetector(
            onTap: () => setState(() => _showControls = !_showControls),
            child: Container(
              color: AppColors.background,
              child: Stack(
                children: [
                  // Video content
                  Positioned.fill(
                    child: _buildVideoContent(playback),
                  ),

                  // Top bar (always visible)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _buildTopBar(playback),
                  ),

                  // Bottom controls (toggleable)
                  if (_showControls)
                    Positioned(
                      bottom: AppSpacing.space4,
                      left: AppSpacing.space4,
                      right: AppSpacing.space4,
                      child: const PlaybackControls(),
                    ),

                  // Status indicators
                  if (playback.isBuffering)
                    const Positioned.fill(
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    ),

                  // Error message
                  if (playback.state.hasError)
                    Positioned.fill(
                      child: _buildErrorOverlay(playback.state),
                    ),

                  // Help overlay
                  if (_showHelp)
                    Positioned.fill(
                      child: _buildHelpOverlay(),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoContent(PlaybackProvider playback) {
    final state = playback.state;

    if (state.isLocal) {
      // Local playback with media_kit
      final controller = playback.videoController;
      if (controller == null) {
        return const Center(
          child: Text(
            'Video controller not available',
            style: TextStyle(color: AppColors.textMuted),
          ),
        );
      }

      return ZoomableVideoView(
        zoom: state.zoom,
        panOffset: state.panOffset,
        onZoomChanged: playback.setZoom,
        onPanChanged: playback.setPan,
        child: Video(
          controller: controller,
          controls: NoVideoControls,
        ),
      );
    } else if (state.isRemote) {
      // Remote streaming with MJPEG
      return ZoomableMjpegView(
        url: state.streamUrl,
        zoom: state.zoom,
        panOffset: state.panOffset,
        onZoomChanged: playback.setZoom,
        onPanChanged: playback.setPan,
      );
    }

    return const Center(
      child: Text(
        'Unknown playback source',
        style: TextStyle(color: AppColors.textMuted),
      ),
    );
  }

  Widget _buildTopBar(PlaybackProvider playback) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          // Close button
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Close (Escape)',
            onPressed: () async {
              await playback.close();
              widget.onClose();
            },
          ),

          const SizedBox(width: AppSpacing.space2),

          // Source indicator
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space2,
              vertical: AppSpacing.space1,
            ),
            decoration: BoxDecoration(
              color: playback.isLocal
                  ? AppColors.info.withValues(alpha: 0.2)
                  : AppColors.success.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  playback.isLocal ? Icons.folder : Icons.cast,
                  color: playback.isLocal ? AppColors.info : AppColors.success,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  playback.isLocal ? 'Local' : 'Remote',
                  style: TextStyle(
                    color: playback.isLocal ? AppColors.info : AppColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Help button
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white70),
            tooltip: 'Keyboard shortcuts',
            onPressed: () => setState(() => _showHelp = !_showHelp),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorOverlay(PlaybackState state) {
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 64),
            const SizedBox(height: AppSpacing.space4),
            Text(
              'Playback Error',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.danger,
                  ),
            ),
            const SizedBox(height: AppSpacing.space2),
            Text(
              state.errorMessage ?? 'Unknown error',
              style: const TextStyle(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.space4),
            ElevatedButton(
              onPressed: widget.onClose,
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpOverlay() {
    return GestureDetector(
      onTap: () => setState(() => _showHelp = false),
      child: Container(
        color: Colors.black.withValues(alpha: 0.9),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.space5),
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.keyboard, color: AppColors.text),
                    const SizedBox(width: AppSpacing.space2),
                    const Text(
                      'Keyboard Shortcuts',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textMuted),
                      onPressed: () => setState(() => _showHelp = false),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space4),
                _buildShortcutRow('Space', 'Play / Pause'),
                _buildShortcutRow('Left / Right', 'Step frame -/+'),
                _buildShortcutRow('Shift + Left/Right', 'Step 10 frames'),
                _buildShortcutRow('Up / Down', 'Speed +/-'),
                _buildShortcutRow('+ / -', 'Zoom in/out'),
                _buildShortcutRow('R', 'Reset zoom/pan'),
                _buildShortcutRow('H', 'Toggle controls'),
                _buildShortcutRow('Escape', 'Close playback'),
                _buildShortcutRow('?', 'Show this help'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShortcutRow(String key, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              key,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.space3),
          Text(
            description,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event, PlaybackProvider playback) {
    if (event is! KeyDownEvent) return;

    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
        playback.togglePlayPause();
        break;

      case LogicalKeyboardKey.arrowLeft:
        if (isShiftPressed) {
          playback.stepBackward(frames: 10);
        } else {
          playback.stepBackward();
        }
        break;

      case LogicalKeyboardKey.arrowRight:
        if (isShiftPressed) {
          playback.stepForward(frames: 10);
        } else {
          playback.stepForward();
        }
        break;

      case LogicalKeyboardKey.arrowUp:
        playback.speedUp();
        break;

      case LogicalKeyboardKey.arrowDown:
        playback.slowDown();
        break;

      case LogicalKeyboardKey.equal: // + key
      case LogicalKeyboardKey.numpadAdd:
        playback.zoomIn();
        break;

      case LogicalKeyboardKey.minus:
      case LogicalKeyboardKey.numpadSubtract:
        playback.zoomOut();
        break;

      case LogicalKeyboardKey.keyR:
        playback.resetZoomPan();
        break;

      case LogicalKeyboardKey.keyH:
        setState(() => _showControls = !_showControls);
        break;

      case LogicalKeyboardKey.slash: // ? key
        if (isShiftPressed) {
          setState(() => _showHelp = !_showHelp);
        }
        break;

      case LogicalKeyboardKey.escape:
        if (_showHelp) {
          setState(() => _showHelp = false);
        } else {
          playback.close();
          widget.onClose();
        }
        break;
    }
  }
}
