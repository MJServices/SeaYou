import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Animated Waveform Widget - Matches Figma design
/// Shows animated bars that pulse during playback/recording
class AnimatedWaveform extends StatefulWidget {
  final bool isAnimating;
  final Color color;
  final int barCount;
  final double height;
  final double barWidth;
  final double spacing;

  const AnimatedWaveform({
    super.key,
    required this.isAnimating,
    this.color = const Color(0xFF0AC5C5),
    this.barCount = 30,
    this.height = 60,
    this.barWidth = 3,
    this.spacing = 2,
  });

  @override
  State<AnimatedWaveform> createState() => _AnimatedWaveformState();
}

class _AnimatedWaveformState extends State<AnimatedWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _barHeights = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addListener(() {
        if (mounted) {
          setState(() {});
        }
      });

    // Initialize bar heights with varied values
    _initializeBarHeights();

    if (widget.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(AnimatedWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating != oldWidget.isAnimating) {
      if (widget.isAnimating) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _initializeBarHeights() {
    _barHeights.clear();
    final random = math.Random(42); // Fixed seed for consistent pattern
    for (int i = 0; i < widget.barCount; i++) {
      // Create varied heights: 20%, 40%, 60%, 80%, 100%
      final heights = [0.3, 0.5, 0.7, 0.85, 1.0];
      _barHeights.add(heights[random.nextInt(heights.length)]);
    }
  }

  double _getBarHeight(int index) {
    if (!widget.isAnimating) {
      return _barHeights[index] * widget.height;
    }

    // Animated height with wave effect
    final baseHeight = _barHeights[index];
    final wave = math.sin((_controller.value * 2 * math.pi) + (index * 0.3));
    final animatedMultiplier =
        0.7 + (wave * 0.3); // Oscillate between 0.7 and 1.0
    return baseHeight * widget.height * animatedMultiplier;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(widget.barCount, (index) {
          return Container(
            width: widget.barWidth,
            height: _getBarHeight(index),
            margin: EdgeInsets.symmetric(horizontal: widget.spacing),
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(widget.barWidth / 2),
            ),
          );
        }),
      ),
    );
  }
}

/// Compact Waveform for smaller displays (like in preview)
class CompactWaveform extends StatelessWidget {
  final bool isAnimating;
  final Color color;

  const CompactWaveform({
    super.key,
    required this.isAnimating,
    this.color = const Color(0xFF0AC5C5),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedWaveform(
      isAnimating: isAnimating,
      color: color,
      barCount: 15,
      height: 40,
      barWidth: 3,
      spacing: 2,
    );
  }
}
