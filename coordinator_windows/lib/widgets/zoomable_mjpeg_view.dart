import 'package:flutter/material.dart';

import '../models/playback_state.dart';
import '../theme/app_colors.dart';
import 'mjpeg_view.dart';

/// MJPEG view with interactive zoom and pan support.
/// Uses InteractiveViewer for smooth gestures and external control.
class ZoomableMjpegView extends StatefulWidget {
  const ZoomableMjpegView({
    super.key,
    required this.url,
    required this.zoom,
    required this.panOffset,
    required this.onZoomChanged,
    required this.onPanChanged,
    this.minZoom = PlaybackZoom.min,
    this.maxZoom = PlaybackZoom.max,
  });

  final String? url;
  final double zoom;
  final Offset panOffset;
  final ValueChanged<double> onZoomChanged;
  final ValueChanged<Offset> onPanChanged;
  final double minZoom;
  final double maxZoom;

  @override
  State<ZoomableMjpegView> createState() => _ZoomableMjpegViewState();
}

class _ZoomableMjpegViewState extends State<ZoomableMjpegView> {
  late TransformationController _transformationController;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _updateTransformation();
  }

  @override
  void didUpdateWidget(ZoomableMjpegView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zoom != widget.zoom || oldWidget.panOffset != widget.panOffset) {
      _updateTransformation();
    }
  }

  void _updateTransformation() {
    // Create transformation matrix from zoom and pan
    final matrix = Matrix4.identity()
      ..scale(widget.zoom)
      ..translate(widget.panOffset.dx, widget.panOffset.dy);

    _transformationController.value = matrix;
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: ClipRect(
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: widget.minZoom,
          maxScale: widget.maxZoom,
          boundaryMargin: const EdgeInsets.all(double.infinity),
          onInteractionEnd: (details) {
            // Extract scale and translation from transformation matrix
            final matrix = _transformationController.value;
            final scale = matrix.getMaxScaleOnAxis();
            final translation = matrix.getTranslation();

            widget.onZoomChanged(scale);
            widget.onPanChanged(Offset(translation.x, translation.y));
          },
          child: Center(
            child: MjpegView(
              url: widget.url,
              fit: BoxFit.contain,
              placeholder: _buildPlaceholder(),
              errorWidget: _buildError(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.background,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Connecting to stream...',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      color: AppColors.background,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: AppColors.danger, size: 48),
            SizedBox(height: 16),
            Text(
              'Stream connection failed',
              style: TextStyle(color: AppColors.danger),
            ),
            SizedBox(height: 8),
            Text(
              'Check device connection and try again',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// A zoomable video view for local playback using media_kit.
/// Wraps the video widget with InteractiveViewer for zoom/pan.
class ZoomableVideoView extends StatefulWidget {
  const ZoomableVideoView({
    super.key,
    required this.child,
    required this.zoom,
    required this.panOffset,
    required this.onZoomChanged,
    required this.onPanChanged,
    this.minZoom = PlaybackZoom.min,
    this.maxZoom = PlaybackZoom.max,
  });

  final Widget child;
  final double zoom;
  final Offset panOffset;
  final ValueChanged<double> onZoomChanged;
  final ValueChanged<Offset> onPanChanged;
  final double minZoom;
  final double maxZoom;

  @override
  State<ZoomableVideoView> createState() => _ZoomableVideoViewState();
}

class _ZoomableVideoViewState extends State<ZoomableVideoView> {
  late TransformationController _transformationController;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _updateTransformation();
  }

  @override
  void didUpdateWidget(ZoomableVideoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zoom != widget.zoom || oldWidget.panOffset != widget.panOffset) {
      _updateTransformation();
    }
  }

  void _updateTransformation() {
    final matrix = Matrix4.identity()
      ..scale(widget.zoom)
      ..translate(widget.panOffset.dx, widget.panOffset.dy);

    _transformationController.value = matrix;
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: ClipRect(
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: widget.minZoom,
          maxScale: widget.maxZoom,
          boundaryMargin: const EdgeInsets.all(double.infinity),
          onInteractionEnd: (details) {
            final matrix = _transformationController.value;
            final scale = matrix.getMaxScaleOnAxis();
            final translation = matrix.getTranslation();

            widget.onZoomChanged(scale);
            widget.onPanChanged(Offset(translation.x, translation.y));
          },
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}
