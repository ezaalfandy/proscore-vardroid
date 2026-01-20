import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Widget for displaying MJPEG streams from camera devices
class MjpegView extends StatefulWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const MjpegView({
    super.key,
    this.url,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<MjpegView> createState() => _MjpegViewState();
}

class _MjpegViewState extends State<MjpegView> {
  Uint8List? _currentFrame;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isStopped = false;
  StreamSubscription? _subscription;
  http.Client? _client;

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  @override
  void didUpdateWidget(MjpegView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _stopStream();
      _startStream();
    }
  }

  @override
  void dispose() {
    _stopStream();
    super.dispose();
  }

  void _startStream() {
    if (widget.url == null) {
      setState(() {
        _isLoading = false;
        _hasError = false;
        _isStopped = false;
        _currentFrame = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
      _isStopped = false;
    });

    _client = http.Client();
    _connectToStream();
  }

  Future<void> _connectToStream() async {
    try {
      final request = http.Request('GET', Uri.parse(widget.url!));
      final response = await _client!.send(request);

      if (response.statusCode != 200) {
        throw Exception('Failed to connect: ${response.statusCode}');
      }

      final List<int> buffer = [];
      bool inFrame = false;
      int frameStartIndex = 0;

      _subscription = response.stream.listen(
        (chunk) {
          buffer.addAll(chunk);

          // Look for JPEG frame boundaries
          while (true) {
            if (!inFrame) {
              // Look for JPEG start marker (FFD8)
              final startIdx = _findPattern(buffer, [0xFF, 0xD8]);
              if (startIdx >= 0) {
                frameStartIndex = startIdx;
                inFrame = true;
              } else {
                // Keep only the last byte in case FFD8 spans chunks
                if (buffer.length > 1) {
                  buffer.removeRange(0, buffer.length - 1);
                }
                break;
              }
            }

            if (inFrame) {
              // Look for JPEG end marker (FFD9)
              final endIdx = _findPattern(buffer, [0xFF, 0xD9], start: frameStartIndex);
              if (endIdx >= 0) {
                // Extract the complete frame
                final frameEnd = endIdx + 2;
                final frameData = Uint8List.fromList(
                  buffer.sublist(frameStartIndex, frameEnd),
                );

                // Remove processed data from buffer
                buffer.removeRange(0, frameEnd);
                inFrame = false;

                // Update the displayed frame
                if (mounted) {
                  setState(() {
                    _currentFrame = frameData;
                    _isLoading = false;
                    _hasError = false;
                  });
                }
              } else {
                // Frame not complete yet, wait for more data
                break;
              }
            }
          }
        },
        onError: (error) {
          print('MJPEG stream error: $error');
          if (mounted) {
            setState(() {
              _hasError = true;
              _isLoading = false;
              _isStopped = false;
              _currentFrame = null;
            });
          }
        },
        onDone: () {
          print('MJPEG stream ended');
          if (mounted) {
            setState(() {
              _isStopped = true;
              _isLoading = false;
              _currentFrame = null;
            });
          }
          // Attempt to reconnect after a delay
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && widget.url != null) {
              _connectToStream();
            }
          });
        },
        cancelOnError: true,
      );
    } catch (e) {
      print('Failed to connect to MJPEG stream: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  void _stopStream() {
    _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
  }

  int _findPattern(List<int> data, List<int> pattern, {int start = 0}) {
    for (int i = start; i <= data.length - pattern.length; i++) {
      bool found = true;
      for (int j = 0; j < pattern.length; j++) {
        if (data[i + j] != pattern[j]) {
          found = false;
          break;
        }
      }
      if (found) return i;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url == null) {
      return _buildPlaceholder();
    }

    if (_isStopped) {
      return _buildStopped();
    }

    if (_hasError) {
      return widget.errorWidget ?? _buildError();
    }

    if (_isLoading || _currentFrame == null) {
      return widget.placeholder ?? _buildLoading();
    }

    return Image.memory(
      _currentFrame!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      gaplessPlayback: true,
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[900],
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off, color: Colors.grey, size: 48),
            SizedBox(height: 8),
            Text('No preview', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[900],
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[900],
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            SizedBox(height: 8),
            Text('Connection error', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }

  Widget _buildStopped() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[900],
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pause_circle_outline, color: Colors.grey, size: 48),
            SizedBox(height: 8),
            Text('Preview stopped', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
