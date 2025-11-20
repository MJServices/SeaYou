import 'package:flutter/material.dart';

/// Connection Level Modal - Shows connection progress
class ConnectionLevelModal extends StatelessWidget {
  final String contactName;
  final int connectionPercentage;

  const ConnectionLevelModal({
    super.key,
    required this.contactName,
    this.connectionPercentage = 75,
  });

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
    return Row(
      children: [
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 20,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3E3E3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              FractionallySizedBox(
                widthFactor: connectionPercentage / 100,
                child: Container(
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0AC5C5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Text(
          '$connectionPercentage%',
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF151515),
          ),
        ),
      ],
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
