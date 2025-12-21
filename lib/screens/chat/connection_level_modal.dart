import 'package:flutter/material.dart';
import '../../services/audio_service.dart';
import '../../widgets/feeling_progress.dart';

/// Connection Level Modal - Shows connection progress
class ConnectionLevelModal extends StatefulWidget {
  final String contactName;
  final int connectionPercentage;

  const ConnectionLevelModal({
    super.key,
    required this.contactName,
    this.connectionPercentage = 75,
  });

  @override
  State<ConnectionLevelModal> createState() => _ConnectionLevelModalState();
}

class _ConnectionLevelModalState extends State<ConnectionLevelModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _progress = Tween<double>(
            begin: 0, end: widget.connectionPercentage.toDouble())
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.addStatusListener((status) async {
      if (status == AnimationStatus.completed && !_completed) {
        if (widget.connectionPercentage >= 100) {
          await GlobalAudioController.instance.playCompletionSfx();
        }
        setState(() {
          _completed = true;
        });
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 40),
          _buildProgressIndicator(),
          const SizedBox(height: 40),
          _buildUnlockItems(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      children: [
        Text(
          'Connection level',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF363636),
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Send messages to unlock connection.',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF737373),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        final value = (_progress.value.clamp(0, 100)).toInt();
        return FeelingProgress(percent: value);
      },
    );
  }

  Widget _buildUnlockItems() {
    return Column(
      children: [
        _buildUnlockItem('Message', true),
        const SizedBox(height: 12),
        _buildUnlockItem('Photo', true),
        const SizedBox(height: 12),
        _buildUnlockItem('Voice Chat', true),
        const SizedBox(height: 12),
        _buildUnlockItem('Any random thing', false),
      ],
    );
  }

  Widget _buildUnlockItem(String label, bool isUnlocked) {
    return Row(
      children: [
        Icon(
          isUnlocked ? Icons.check_circle : Icons.lock,
          size: 20,
          color: isUnlocked ? const Color(0xFF0AC5C5) : const Color(0xFF737373),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color:
                isUnlocked ? const Color(0xFF363636) : const Color(0xFF737373),
          ),
        ),
      ],
    );
  }
}
