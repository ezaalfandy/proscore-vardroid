import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/playback_state.dart';
import '../providers/playback_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// Playback control bar with play/pause, seek, speed, and zoom controls.
class PlaybackControls extends StatelessWidget {
  const PlaybackControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaybackProvider>(
      builder: (context, playback, _) {
        final state = playback.state;

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space4,
            vertical: AppSpacing.space3,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Seek bar
              _buildSeekBar(context, playback, state),
              const SizedBox(height: AppSpacing.space3),

              // Control buttons row
              Row(
                children: [
                  // Left: Timecode
                  _buildTimecode(state),

                  const Spacer(),

                  // Center: Playback controls
                  _buildPlaybackButtons(context, playback, state),

                  const Spacer(),

                  // Right: Speed and zoom
                  _buildSpeedZoomControls(context, playback, state),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSeekBar(
    BuildContext context,
    PlaybackProvider playback,
    PlaybackState state,
  ) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.border,
        thumbColor: AppColors.primary,
        overlayColor: AppColors.primary.withValues(alpha: 0.2),
      ),
      child: Slider(
        value: state.progress.clamp(0.0, 1.0),
        onChanged: (value) {
          if (state.duration > Duration.zero) {
            final position = Duration(
              milliseconds: (state.duration.inMilliseconds * value).round(),
            );
            playback.seek(position);
          }
        },
      ),
    );
  }

  Widget _buildTimecode(PlaybackState state) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space2,
        vertical: AppSpacing.space1,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        '${state.formattedPosition} / ${state.formattedDuration}',
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 12,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPlaybackButtons(
    BuildContext context,
    PlaybackProvider playback,
    PlaybackState state,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Step backward 10 frames
        _IconButton(
          icon: Icons.keyboard_double_arrow_left,
          tooltip: 'Step back 10 frames (Shift+Left)',
          onPressed: () => playback.stepBackward(frames: 10),
        ),

        const SizedBox(width: AppSpacing.space1),

        // Step backward 1 frame
        _IconButton(
          icon: Icons.keyboard_arrow_left,
          tooltip: 'Step back 1 frame (Left)',
          onPressed: () => playback.stepBackward(),
        ),

        const SizedBox(width: AppSpacing.space2),

        // Play/Pause
        _IconButton(
          icon: state.isPlaying ? Icons.pause : Icons.play_arrow,
          tooltip: state.isPlaying ? 'Pause (Space)' : 'Play (Space)',
          onPressed: () => playback.togglePlayPause(),
          primary: true,
          size: 48,
        ),

        const SizedBox(width: AppSpacing.space2),

        // Step forward 1 frame
        _IconButton(
          icon: Icons.keyboard_arrow_right,
          tooltip: 'Step forward 1 frame (Right)',
          onPressed: () => playback.stepForward(),
        ),

        const SizedBox(width: AppSpacing.space1),

        // Step forward 10 frames
        _IconButton(
          icon: Icons.keyboard_double_arrow_right,
          tooltip: 'Step forward 10 frames (Shift+Right)',
          onPressed: () => playback.stepForward(frames: 10),
        ),
      ],
    );
  }

  Widget _buildSpeedZoomControls(
    BuildContext context,
    PlaybackProvider playback,
    PlaybackState state,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Speed control
        _buildSpeedControl(playback, state),

        const SizedBox(width: AppSpacing.space3),

        // Zoom control
        _buildZoomControl(playback, state),
      ],
    );
  }

  Widget _buildSpeedControl(PlaybackProvider playback, PlaybackState state) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _IconButton(
          icon: Icons.remove,
          tooltip: 'Slower (Down)',
          onPressed: () => playback.slowDown(),
          size: 28,
        ),

        Container(
          width: 56,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space1,
            vertical: AppSpacing.space1,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            state.formattedSpeed,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        _IconButton(
          icon: Icons.add,
          tooltip: 'Faster (Up)',
          onPressed: () => playback.speedUp(),
          size: 28,
        ),
      ],
    );
  }

  Widget _buildZoomControl(PlaybackProvider playback, PlaybackState state) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _IconButton(
          icon: Icons.zoom_out,
          tooltip: 'Zoom out (-)',
          onPressed: () => playback.zoomOut(),
          size: 28,
        ),

        Container(
          width: 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space1,
            vertical: AppSpacing.space1,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            state.formattedZoom,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        _IconButton(
          icon: Icons.zoom_in,
          tooltip: 'Zoom in (+)',
          onPressed: () => playback.zoomIn(),
          size: 28,
        ),

        const SizedBox(width: AppSpacing.space1),

        _IconButton(
          icon: Icons.restart_alt,
          tooltip: 'Reset zoom (R)',
          onPressed: () => playback.resetZoomPan(),
          size: 28,
        ),
      ],
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.primary = false,
    this.size = 36,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool primary;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: size,
        height: size,
        child: Material(
          color: primary ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(size / 2),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(size / 2),
            child: Icon(
              icon,
              color: primary ? Colors.white : AppColors.text,
              size: size * 0.55,
            ),
          ),
        ),
      ),
    );
  }
}
