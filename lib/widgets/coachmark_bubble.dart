import 'package:flutter/material.dart';

class CoachmarkBubble extends StatelessWidget {
  final String title;
  final String message;
  final String ctaText;
  final VoidCallback? onClose;
  final VoidCallback? onCta;

  const CoachmarkBubble({
    super.key,
    required this.title,
    required this.message,
    required this.ctaText,
    this.onClose,
    this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Semantics(
        label: title,
        container: true,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F1F),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Title + Close Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: onClose,
                        child: const Icon(
                          Icons.close,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Message Body
                  Text(
                    message,
                    style: const TextStyle(
                      color: Color(0xFFE0E0E0),
                      fontSize: 14,
                      height: 1.5,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                  const SizedBox(height: 20),
                  // CTA Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: onCta,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0AC5C5),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          ctaText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
