import 'package:flutter/material.dart';

import '../models/playback_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// A sophisticated seek bar with timecode display and scrubbing.
class PlaybackSeekBar extends StatefulWidget {
  const PlaybackSeekBar({
    super.key,
    required this.state,
    required this.onSeek,
    this.height = 36,
    this.showTimecode = true,
  });

  final PlaybackState state;
  final ValueChanged<Duration> onSeek;
  final double height;
  final bool showTimecode;

  @override
  State<PlaybackSeekBar> createState() => _PlaybackSeekBarState();
}

class _PlaybackSeekBarState extends State<PlaybackSeekBar> {
  bool _isDragging = false;
  double _dragProgress = 0.0;

  @override
  Widget build(BuildContext context) {
    final progress = _isDragging ? _dragProgress : widget.state.progress;

    return SizedBox(
      height: widget.height,
      child: Column(
        children: [
          if (widget.showTimecode) ...[
            _buildTimecodeRow(progress),
            const SizedBox(height: AppSpacing.space1),
          ],
          Expanded(
            child: _buildSeekTrack(progress),
          ),
        ],
      ),
    );
  }

  Widget _buildTimecodeRow(double progress) {
    final position = _isDragging
        ? Duration(
            milliseconds:
                (widget.state.duration.inMilliseconds * progress).round(),
          )
        : widget.state.position;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _formatDuration(position),
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
        if (_isDragging)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space2,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              'Seeking to ${_formatDuration(position)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        Text(
          _formatDuration(widget.state.duration),
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildSeekTrack(double progress) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final thumbPosition = trackWidth * progress.clamp(0.0, 1.0);

        return GestureDetector(
          onHorizontalDragStart: (details) {
            setState(() {
              _isDragging = true;
              _dragProgress = (details.localPosition.dx / trackWidth).clamp(0.0, 1.0);
            });
          },
          onHorizontalDragUpdate: (details) {
            setState(() {
              _dragProgress = (details.localPosition.dx / trackWidth).clamp(0.0, 1.0);
            });
          },
          onHorizontalDragEnd: (details) {
            _finishSeeking();
          },
          onHorizontalDragCancel: () {
            setState(() {
              _isDragging = false;
            });
          },
          onTapDown: (details) {
            final newProgress = (details.localPosition.dx / trackWidth).clamp(0.0, 1.0);
            _seekToProgress(newProgress);
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
              ),
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Track background
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),

                  // Buffered indicator (if applicable)
                  // Could be added for remote streaming

                  // Progress fill
                  AnimatedContainer(
                    duration: _isDragging
                        ? Duration.zero
                        : const Duration(milliseconds: 50),
                    height: 6,
                    width: thumbPosition,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),

                  // Thumb
                  AnimatedPositioned(
                    duration: _isDragging
                        ? Duration.zero
                        : const Duration(milliseconds: 50),
                    left: thumbPosition - 8,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Frame indicator overlay (shows frame number)
                  if (_isDragging)
                    Positioned(
                      left: thumbPosition.clamp(24.0, trackWidth - 48),
                      bottom: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.space2,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          'Frame ${_calculateFrame(_dragProgress)}',
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _finishSeeking() {
    if (_isDragging) {
      final duration = widget.state.duration;
      final position = Duration(
        milliseconds: (duration.inMilliseconds * _dragProgress).round(),
      );
      widget.onSeek(position);
      setState(() {
        _isDragging = false;
      });
    }
  }

  void _seekToProgress(double progress) {
    final duration = widget.state.duration;
    final position = Duration(
      milliseconds: (duration.inMilliseconds * progress).round(),
    );
    widget.onSeek(position);
  }

  int _calculateFrame(double progress) {
    final fps = widget.state.fps > 0 ? widget.state.fps : 30;
    final totalMs = widget.state.duration.inMilliseconds;
    final positionMs = (totalMs * progress).round();
    return (positionMs * fps / 1000).round();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    final millis = d.inMilliseconds % 1000;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${(millis ~/ 10).toString().padLeft(2, '0')}';
  }
}
