import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'animated_waveform.dart';

class VoiceChatModal extends StatefulWidget {
  final bool isReceived;
  final VoidCallback? onReply;
  final String duration;
  final String? audioUrl;

  const VoiceChatModal({
    super.key,
    this.isReceived = true,
    this.onReply,
    this.duration = '00:12:19',
    this.audioUrl,
  });

  @override
  State<VoiceChatModal> createState() => _VoiceChatModalState();
}

class _VoiceChatModalState extends State<VoiceChatModal> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _playerStateSubscription;

  @override
  void initState() {
    super.initState();
    debugPrint('🎵 VoiceChatModal initialized with audioUrl: ${widget.audioUrl}, duration: ${widget.duration}');
    _initializeAudio();
  }

  Future<void> _initializeAudio() async {
    if (widget.audioUrl != null && widget.audioUrl!.isNotEmpty) {
      try {
        debugPrint('🎵 Loading audio from: ${widget.audioUrl}');
        
        // Set player mode to media
        await _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
        await _audioPlayer.setReleaseMode(ReleaseMode.stop);
        await _audioPlayer.setVolume(1.0);
        await _audioPlayer.setPlaybackRate(_playbackSpeed);
        
        debugPrint('🎵 Setting audio source...');
        
        // Set the source
        await _audioPlayer.setSourceUrl(widget.audioUrl!);
        
        debugPrint('🎵 Audio source set successfully');
        
        // Listen to duration changes
        _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
          setState(() {
            _totalDuration = duration;
          });
          debugPrint('🎵 Audio duration loaded: ${_formatDuration(duration)}');
        });

        // Listen to position changes
        _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
          setState(() {
            _currentPosition = position;
          });
        });

        // Listen to player state changes
        _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
          setState(() {
            _isPlaying = state == PlayerState.playing;
          });
          
          debugPrint('🎵 Player state: $state');
          
          // Auto-reset when finished
          if (state == PlayerState.completed) {
            setState(() {
              _isPlaying = false;
              _currentPosition = Duration.zero;
            });
            _audioPlayer.seek(Duration.zero);
          }
        });
        
        debugPrint('🎵 Audio player initialized successfully');
      } catch (e, stackTrace) {
        debugPrint('❌ Error loading audio: $e');
        debugPrint('Stack trace: $stackTrace');
      }
    } else {
      debugPrint('⚠️ No audio URL provided');
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.resume();
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')} : ${minutes.toString().padLeft(2, '0')} : ${seconds.toString().padLeft(2, '0')}';
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
                onTap: () async {
                  setState(() {
                    _playbackSpeed = speed;
                  });
                  await _audioPlayer.setPlaybackRate(speed);
                  if (mounted) Navigator.pop(context);
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
    return Stack(
      children: [
        // Background with gradient and bottle
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.5),
                radius: 1.2,
                colors: [
                  Color(0xFF0AC5C5),
                  Color(0xFFF5E6D3),
                ],
                stops: [0.0, 1.0],
              ),
            ),
            child: Center(
              child: Opacity(
                opacity: 0.15,
                child: Image.asset(
                  'assets/images/fill bottle.png',
                  width: 200,
                  height: 400,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
        
        // Modal content
        Align(
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
                  _formatDuration(_currentPosition),
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
        ),
      ],
    );
  }
}
