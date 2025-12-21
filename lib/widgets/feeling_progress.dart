import 'package:flutter/material.dart';

class FeelingProgress extends StatelessWidget {
  final int percent;
  final String? title;
  final bool compact;

  const FeelingProgress({
    super.key,
    required this.percent,
    this.title,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final value = percent.clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              title!,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF151515),
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.only(bottom: compact ? 4 : 8),
          child: const Text(
            'Feeling',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF363636),
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Stack(
                clipBehavior: Clip.none, // Allow icons to overflow
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: compact ? 12 : 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3E3E3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: value / 100,
                    child: Container(
                      height: compact ? 12 : 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0AC5C5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        double w(double p) => constraints.maxWidth * (p / 100);
                        final iconSize = compact ? 14.0 : 18.0;
                        return Stack(
                          clipBehavior: Clip.none, // Allow icons to overflow
                          children: [
                          // 25% - Quote
                          Positioned(
                            left: w(25) - iconSize / 2,
                            top: -(compact ? 10.0 : 14.0),
                            child: Semantics(
                              label: '25% - Quote Unlocked',
                              selected: value >= 25,
                              child: Icon(
                                Icons.format_quote,
                                size: iconSize,
                                color: value >= 25
                                    ? const Color(0xFF151515)
                                    : const Color(0xFFBDBDBD),
                              ),
                            ),
                          ),
                          // 50% - Music Note
                          Positioned(
                            left: w(50) - iconSize / 2,
                            top: -(compact ? 10.0 : 14.0),
                            child: Semantics(
                              label: '50% - Voice Message Unlocked',
                              selected: value >= 50,
                              child: Icon(
                                Icons.music_note,
                                size: iconSize,
                                color: value >= 50
                                    ? const Color(0xFF151515)
                                    : const Color(0xFFBDBDBD),
                              ),
                            ),
                          ),
                          // 75% - Gift
                          Positioned(
                            left: w(75) - iconSize / 2,
                            top: -(compact ? 10.0 : 14.0),
                            child: Semantics(
                              label: '75% - Intimate Question Unlocked',
                              selected: value >= 75,
                              child: Icon(
                                Icons.card_giftcard,
                                size: iconSize,
                                color: value >= 75
                                    ? const Color(0xFF151515)
                                    : const Color(0xFFBDBDBD),
                              ),
                            ),
                          ),
                          // 100% - Heart
                          Positioned(
                            left: w(100) - iconSize / 2,
                            top: -(compact ? 10.0 : 14.0),
                            child: Semantics(
                              label: '100% - Photo Reveal Available',
                              selected: value >= 100,
                              child: Icon(
                                Icons.favorite,
                                size: iconSize,
                                color: value >= 100
                                    ? const Color(0xFF151515)
                                    : const Color(0xFFBDBDBD),
                              ),
                            ),
                          ),
                        ]);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$value%',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: compact ? 12 : 16,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF151515),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
