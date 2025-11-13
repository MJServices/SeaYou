import 'package:flutter/material.dart';

class CustomStatusBar extends StatelessWidget {
  const CustomStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 21),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '9:41',
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          Row(
            children: [
              Icon(Icons.signal_cellular_4_bar, size: 17),
              SizedBox(width: 5),
              Icon(Icons.wifi, size: 17),
              SizedBox(width: 5),
              Icon(Icons.battery_full, size: 24),
            ],
          ),
        ],
      ),
    );
  }
}
