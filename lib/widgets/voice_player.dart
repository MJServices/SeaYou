import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class VoicePlayer extends StatefulWidget {
  final String? audioPath; // Local file path
  final String? audioUrl;  // Network URL
  final Color color;
  final bool isLocal; // Force local if needed, or inferred

  const VoicePlayer({
    super.key,
    this.audioPath,
    this.audioUrl,
    this.color = const Color(0xFF151515),
    this.isLocal = false,
  });

  @override
  State<VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<VoicePlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      if (widget.audioPath != null) {
        debugPrint('🎙️ VoicePlayer loading file source: ${widget.audioPath}');
        await _audioPlayer.setSource(DeviceFileSource(widget.audioPath!));
      } else if (widget.audioUrl != null) {
        debugPrint('🎙️ VoicePlayer loading url source: ${widget.audioUrl}');
        await _audioPlayer.setSourceUrl(widget.audioUrl!);
      } else {
        return;
      }

      // Get duration
      final d = await _audioPlayer.getDuration();
      if (d != null) {
        if (mounted) setState(() => _duration = d);
      }

      // Listeners
      _audioPlayer.onPlayerStateChanged.listen((state) {
        if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
      });

      _audioPlayer.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      });

      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
          });
        }
      });

      setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Error initializing voice player: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Timer Display (Large)
        Text(
          _formatDuration(_position), // Or duration if desired
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: widget.color,
          ),
        ),
        const SizedBox(height: 24),

        // Controls
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              // Play/Pause Button
              GestureDetector(
                onTap: () {
                  if (_isPlaying) {
                    _audioPlayer.pause();
                  } else {
                    _audioPlayer.resume();
                  }
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: const Color(0xFF0AC5C5),
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Slider
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                        activeTrackColor: widget.color,
                        inactiveTrackColor: widget.color.withValues(alpha: 0.3),
                        thumbColor: widget.color,
                        overlayColor: widget.color.withValues(alpha: 0.1),
                      ),
                      child: Slider(
                        value: _position.inMilliseconds.toDouble().clamp(0.0, _duration.inMilliseconds.toDouble()),
                        min: 0,
                        max: _duration.inMilliseconds.toDouble() > 0 
                            ? _duration.inMilliseconds.toDouble() 
                            : 1.0,
                        onChanged: (value) {
                          _audioPlayer.seek(Duration(milliseconds: value.toInt()));
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_position),
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: widget.color.withValues(alpha: 0.8),
                            ),
                          ),
                          Text(
                            _duration.inMilliseconds > 0 
                                ? _formatDuration(_duration) 
                                : (_isPlaying ? '...' : _formatDuration(Duration.zero)),
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: widget.color.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
