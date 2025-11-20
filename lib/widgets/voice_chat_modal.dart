import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'animated_waveform.dart';

class VoiceChatModal extends StatefulWidget {
  final bool isReceived;
  final VoidCallback? onReply;
  final String duration;

  const VoiceChatModal({
    super.key,
    this.isReceived = true,
    this.onReply,
    this.duration = '00:12:19',
  });

  @override
  State<VoiceChatModal> createState() => _VoiceChatModalState();
}

class _VoiceChatModalState extends State<VoiceChatModal> {
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  int _currentSeconds = 0;
  late int _totalSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _totalSeconds = _parseDuration(widget.duration);
  }

  int _parseDuration(String duration) {
    final parts =
        duration.split(':').map((e) => int.tryParse(e.trim()) ?? 0).toList();
    if (parts.length == 3) {
      return parts[0] * 3600 + parts[1] * 60 + parts[2];
    }
    return 739; // Default: 00:12:19
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _startTimer();
      } else {
        _timer?.cancel();
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(
        Duration(milliseconds: (1000 / _playbackSpeed).round()), (timer) {
      if (_currentSeconds < _totalSeconds) {
        setState(() {
          _currentSeconds++;
        });
      } else {
        setState(() {
          _isPlaying = false;
          _currentSeconds = 0;
        });
        timer.cancel();
      }
    });
  }

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')} : ${minutes.toString().padLeft(2, '0')} : ${secs.toString().padLeft(2, '0')}';
  }

  void _showSpeedControl() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Playback Speed',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Color(0xFF151515),
              ),
            ),
            const SizedBox(height: 24),
            ...[0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
              return ListTile(
                title: Text(
                  '${speed}x',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: _playbackSpeed == speed
                        ? const Color(0xFF0AC5C5)
                        : const Color(0xFF151515),
                  ),
                ),
                trailing: _playbackSpeed == speed
                    ? const Icon(Icons.check, color: Color(0xFF0AC5C5))
                    : null,
                onTap: () {
                  setState(() {
                    _playbackSpeed = speed;
                  });
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 9, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 80,
              height: 3,
              decoration: BoxDecoration(
                color: const Color(0xFF737373),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                const Text(
                  'Voice Chat',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF151515),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/icons/xmark.svg',
                        width: 16,
                        height: 16,
                        colorFilter: const ColorFilter.mode(
                          Color(0xFF151515),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 48),

            // Timer
            Text(
              _formatTime(_currentSeconds),
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Color(0xFF151515),
              ),
            ),

            const SizedBox(height: 48),

            // Play/Pause button
            GestureDetector(
              onTap: _togglePlayPause,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFE3E3E3),
                    width: 1.6,
                  ),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    _isPlaying
                        ? 'assets/icons/pause.svg'
                        : 'assets/icons/play.svg',
                    width: 32,
                    height: 32,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFF151515),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 48),

            // Animated Waveform
            AnimatedWaveform(
              isAnimating: _isPlaying,
              color: const Color(0xFF0AC5C5),
              barCount: 30,
              height: 60,
              barWidth: 3,
              spacing: 2,
            ),

            const SizedBox(height: 48),

            // Speed control
            GestureDetector(
              onTap: _showSpeedControl,
              child: Column(
                children: [
                  Text(
                    '${_playbackSpeed}x',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF151515),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Speed',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF737373),
                    ),
                  ),
                ],
              ),
            ),

            if (widget.isReceived) ...[
              const SizedBox(height: 32),
              // Send reply button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: widget.onReply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0AC5C5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Send a reply',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
