import 'package:flutter/material.dart';

class CustomStatusBar extends StatelessWidget {
  final Color color;

  const CustomStatusBar({super.key, this.color = const Color(0xFF151515)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 21),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '9:41',
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Row(
            children: [
              Icon(Icons.signal_cellular_4_bar, size: 17, color: color),
              const SizedBox(width: 5),
              Icon(Icons.wifi, size: 17, color: color),
              const SizedBox(width: 5),
              Icon(Icons.battery_full, size: 24, color: color),
            ],
          ),
        ],
      ),
    );
  }
}
