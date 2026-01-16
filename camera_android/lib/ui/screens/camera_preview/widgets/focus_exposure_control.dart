import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

/// Animated focus indicator with exposure slide control (like iOS camera)
class FocusExposureControl extends StatefulWidget {
  final Offset position;
  final double currentExposure;
  final double minExposure;
  final double maxExposure;
  final Function(double) onExposureChanged;
  final VoidCallback onDismiss;

  const FocusExposureControl({
    super.key,
    required this.position,
    required this.currentExposure,
    required this.minExposure,
    required this.maxExposure,
    required this.onExposureChanged,
    required this.onDismiss,
  });

  @override
  State<FocusExposureControl> createState() => _FocusExposureControlState();
}

class _FocusExposureControlState extends State<FocusExposureControl>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  bool _isDragging = false;
  double _dragExposure = 0.0;

  @override
  void initState() {
    super.initState();
    _dragExposure = widget.currentExposure;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();

    // Auto-dismiss after 3 seconds if not interacting
    _startAutoDismissTimer();
  }

  void _startAutoDismissTimer() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && !_isDragging) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.position.dx - 40,
      top: widget.position.dy - 40,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Focus square
                Transform.scale(
                  scale: _scaleAnimation.value,
                  child: _buildFocusSquare(),
                ),

                // Exposure slider (vertical)
                const SizedBox(width: 8),
                _buildExposureSlider(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFocusSquare() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        border: Border.all(
          color: AppColors.warning,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        children: [
          // Corner brackets
          Positioned(top: 0, left: 0, child: _buildCorner(true, true)),
          Positioned(top: 0, right: 0, child: _buildCorner(true, false)),
          Positioned(bottom: 0, left: 0, child: _buildCorner(false, true)),
          Positioned(bottom: 0, right: 0, child: _buildCorner(false, false)),
        ],
      ),
    );
  }

  Widget _buildCorner(bool isTop, bool isLeft) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? const BorderSide(color: AppColors.warning, width: 3) : BorderSide.none,
          bottom: !isTop ? const BorderSide(color: AppColors.warning, width: 3) : BorderSide.none,
          left: isLeft ? const BorderSide(color: AppColors.warning, width: 3) : BorderSide.none,
          right: !isLeft ? const BorderSide(color: AppColors.warning, width: 3) : BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildExposureSlider() {
    final range = widget.maxExposure - widget.minExposure;
    final normalizedValue = (_dragExposure - widget.minExposure) / range;

    return GestureDetector(
      onVerticalDragStart: (_) {
        setState(() {
          _isDragging = true;
        });
      },
      onVerticalDragUpdate: (details) {
        setState(() {
          // Invert: drag up = brighter (positive), drag down = darker (negative)
          final delta = -details.delta.dy / 100;
          _dragExposure = (_dragExposure + delta).clamp(
            widget.minExposure,
            widget.maxExposure,
          );
        });
        widget.onExposureChanged(_dragExposure);
      },
      onVerticalDragEnd: (_) {
        setState(() {
          _isDragging = false;
        });
        _startAutoDismissTimer();
      },
      child: Container(
        width: 40,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Track
            Container(
              width: 2,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(1),
              ),
            ),

            // Sun icon indicator
            Positioned(
              top: 20 + (1 - normalizedValue) * 80 - 12,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.warning,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wb_sunny,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),

            // + at top
            const Positioned(
              top: 4,
              child: Icon(Icons.add, color: Colors.white, size: 12),
            ),

            // - at bottom
            const Positioned(
              bottom: 4,
              child: Icon(Icons.remove, color: Colors.white, size: 12),
            ),
          ],
        ),
      ),
    );
  }
}
