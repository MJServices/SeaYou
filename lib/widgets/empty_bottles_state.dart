import 'package:flutter/material.dart';

class EmptyBottlesState extends StatelessWidget {
  final String type; // 'received' or 'sent'

  const EmptyBottlesState({
    super.key,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final isReceived = type == 'received';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Empty bottle image
        Image.asset(
          'assets/images/empty-bottle.png',
          width: 200,
          height: 200,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 24),
        // Message
        Text(
          isReceived
              ? 'No bottles received yet'
              : 'No bottles sent yet',
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF151515),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          isReceived
              ? 'Your bottle messages will appear here\nwhen someone sends you one'
              : 'Send your first bottle message\nto connect with someone',
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF737373),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
