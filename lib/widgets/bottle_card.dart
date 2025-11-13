import 'package:flutter/material.dart';

class BottleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool hasAudio;
  final bool hasImage;
  final Color backgroundColor;
  final VoidCallback onTap;

  const BottleCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.hasAudio = false,
    this.hasImage = false,
    this.backgroundColor = Colors.white,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE3E3E3),
          width: 0.8,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      size: 24,
                      color: const Color(0xFF151515),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF151515),
                        ),
                      ),
                    ),
                  ],
                ),
                if (hasAudio) ...[
                  const SizedBox(height: 8),
                  _buildAudioWaveform(),
                ],
                if (hasImage) ...[
                  const SizedBox(height: 8),
                  Container(
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: const Color(0xFFE3E3E3),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.image,
                        size: 32,
                        color: Color(0xFF737373),
                      ),
                    ),
                  ),
                ],
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                      color: Color(0xFF151515),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioWaveform() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        20,
        (index) => Container(
          width: 2,
          height: (index % 3 + 1) * 8.0,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: const Color(0xFF0AC5C5),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }
}
