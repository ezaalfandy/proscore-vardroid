import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../services/playback_service.dart';

class VideoPlaybackScreen extends StatefulWidget {
  final String videoPath;
  final String? title;

  const VideoPlaybackScreen({
    super.key,
    required this.videoPath,
    this.title,
  });

  @override
  State<VideoPlaybackScreen> createState() => _VideoPlaybackScreenState();
}

class _VideoPlaybackScreenState extends State<VideoPlaybackScreen> {
  final PlaybackService _playbackService = PlaybackService();
  bool _isLoading = true;
  String? _error;
  bool _showControls = true;
  bool _isDraggingSeek = false;

  // Zoom gesture state
  double _baseZoom = 1.0;
  Offset _basePan = Offset.zero;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void dispose() {
    _playbackService.dispose();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final success = await _playbackService.initialize(widget.videoPath);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (!success) {
          _error = 'Failed to load video';
        }
      });

      // Add listener for video updates
      _playbackService.controller?.addListener(_onVideoUpdate);
    }
  }

  void _onVideoUpdate() {
    if (mounted && !_isDraggingSeek) {
      setState(() {});
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final millis = (duration.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
    return '$minutes:$seconds.$millis';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Video Player with Zoom/Pan
            _buildVideoPlayer(),

            // Top Bar
            if (_showControls) _buildTopBar(),

            // Playback Controls
            if (_showControls) _buildPlaybackControls(),

            // Loading/Error Overlay
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            if (_error != null)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _initializePlayer,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (!_playbackService.isInitialized) {
      return const SizedBox.expand();
    }

    return GestureDetector(
      onTap: _toggleControls,
      onScaleStart: (details) {
        _baseZoom = _playbackService.zoomLevel;
        _basePan = Offset(_playbackService.panX, _playbackService.panY);
      },
      onScaleUpdate: (details) {
        setState(() {
          // Update zoom
          _playbackService.setZoom(_baseZoom * details.scale);

          // Update pan
          if (_playbackService.zoomLevel > 1.0) {
            final panDelta = details.focalPointDelta;
            final sensitivity = 0.002 / _playbackService.zoomLevel;
            _playbackService.setPan(
              _basePan.dx - panDelta.dx * sensitivity,
              _basePan.dy - panDelta.dy * sensitivity,
            );
            _basePan = Offset(_playbackService.panX, _playbackService.panY);
          }
        });
      },
      onDoubleTap: () {
        setState(() {
          if (_playbackService.zoomLevel > 1.0) {
            _playbackService.resetZoomAndPan();
          } else {
            _playbackService.setZoom(2.0);
          }
        });
      },
      child: Center(
        child: ClipRect(
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..scale(_playbackService.zoomLevel)
              ..translate(
                -_playbackService.panX * 100,
                -_playbackService.panY * 100,
              ),
            child: AspectRatio(
              aspectRatio: _playbackService.controller!.value.aspectRatio,
              child: VideoPlayer(_playbackService.controller!),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Text(
                widget.title ?? 'Video Playback',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Zoom indicator
            if (_playbackService.zoomLevel > 1.0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_playbackService.zoomLevel.toStringAsFixed(1)}x',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaybackControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Speed controls
            _buildSpeedControls(),
            const SizedBox(height: 16),

            // Seek bar
            _buildSeekBar(),
            const SizedBox(height: 8),

            // Time display
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_playbackService.position),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                Text(
                  _formatDuration(_playbackService.duration),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Main controls
            _buildMainControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedControls() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: PlaybackService.speedPresets.map((speed) {
          final isSelected = _playbackService.playbackSpeed == speed;
          final label = speed == 1.0 ? '1x' : '${speed}x';

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              selectedColor: Colors.blue,
              backgroundColor: Colors.grey[800],
              onSelected: (selected) async {
                if (selected) {
                  await _playbackService.setPlaybackSpeed(speed);
                  setState(() {});
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSeekBar() {
    final position = _playbackService.position.inMilliseconds.toDouble();
    final duration = _playbackService.duration.inMilliseconds.toDouble();

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: Colors.blue,
        inactiveTrackColor: Colors.grey[600],
        thumbColor: Colors.white,
        overlayColor: Colors.blue.withOpacity(0.3),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        trackHeight: 4,
      ),
      child: Slider(
        value: duration > 0 ? position.clamp(0, duration) : 0,
        min: 0,
        max: duration > 0 ? duration : 1,
        onChangeStart: (_) {
          _isDraggingSeek = true;
        },
        onChanged: (value) {
          setState(() {
            _playbackService.seekTo(Duration(milliseconds: value.toInt()));
          });
        },
        onChangeEnd: (value) {
          _isDraggingSeek = false;
          _playbackService.seekTo(Duration(milliseconds: value.toInt()));
        },
      ),
    );
  }

  Widget _buildMainControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Step backward
        IconButton(
          icon: const Icon(Icons.skip_previous, color: Colors.white, size: 32),
          onPressed: () async {
            await _playbackService.stepBackward(frames: 10);
            setState(() {});
          },
        ),

        // Frame backward
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_left, color: Colors.white, size: 32),
          onPressed: () async {
            await _playbackService.stepBackward();
            setState(() {});
          },
        ),

        // Play/Pause
        Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              _playbackService.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 40,
            ),
            onPressed: () async {
              await _playbackService.togglePlayPause();
              setState(() {});
            },
          ),
        ),

        // Frame forward
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_right, color: Colors.white, size: 32),
          onPressed: () async {
            await _playbackService.stepForward();
            setState(() {});
          },
        ),

        // Step forward
        IconButton(
          icon: const Icon(Icons.skip_next, color: Colors.white, size: 32),
          onPressed: () async {
            await _playbackService.stepForward(frames: 10);
            setState(() {});
          },
        ),
      ],
    );
  }
}
