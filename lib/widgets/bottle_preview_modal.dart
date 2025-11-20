import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Bottle Preview Modal - Shows preview before sending
class BottlePreviewModal extends StatelessWidget {
  final String mood;
  final String message;
  final VoidCallback onSend;
  final VoidCallback onSaveAsDraft;

  const BottlePreviewModal({
    super.key,
    required this.mood,
    required this.message,
    required this.onSend,
    required this.onSaveAsDraft,
  });

  List<Color> get _moodGradientColors {
    switch (mood.toLowerCase()) {
      case 'dreamy':
        return [
          const Color(0xFFC7CEEA), // Start: lighter color at top
          const Color(0xFF9B98E6), // End: darker color at bottom
        ];
      case 'curious':
        return [
          const Color(0xFFFFC700),
          const Color(0xFFD89736),
        ];
      case 'calm':
        return [
          const Color(0xFF9ECFD4),
          const Color(0xFF65ADA9),
        ];
      case 'playful':
        return [
          const Color(0xFFFF9F9B),
          const Color(0xFFFF6D68),
        ];
      default:
        return [
          const Color(0xFFC7CEEA),
          const Color(0xFF9B98E6),
        ];
    }
  }

  Color get _textColor {
    switch (mood.toLowerCase()) {
      case 'dreamy':
        return const Color(0xFF3B0143);
      case 'curious':
        return const Color(0xFF3A2C02);
      case 'calm':
        return const Color(0xFF151515);
      case 'playful':
        return const Color(0xFF151515);
      default:
        return const Color(0xFF3B0143);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0x33000000),
      ),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Text(
                    'Preview',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF151515),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
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
                ],
              ),

              const SizedBox(height: 12),

              // Message preview
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: _moodGradientColors,
                    stops: const [0.0, 0.56],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(16),
                child: Text(
                  message,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: _textColor,
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onSaveAsDraft,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFAFA),
                          border: Border.all(
                            color: const Color(0xFF0AC5C5),
                            width: 0.8,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: const Text(
                          'Save as Drafts',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0AC5C5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: onSend,
                    child: Container(
                      width: 88,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0AC5C5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: const Text(
                        'Send',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottle Sent Modal - Confirmation after sending
class BottleSentModal extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onSendNew;

  const BottleSentModal({
    super.key,
    required this.onClose,
    required this.onSendNew,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0x33000000),
      ),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success icon
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/success_icon.png'),
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Title
              const Text(
                'Your bottle has been sent!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF151515),
                ),
              ),

              const SizedBox(height: 4),

              // Description
              const Text(
                'Wait for someone to retrieve it across the sea and send one to you',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF151515),
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 12),

              // Action buttons
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: onClose,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3E3E3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: const Text(
                              'Close',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF737373),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: onSendNew,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF0AC5C5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: const Text(
                              'Send a new bottle',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reply Sent Modal - Confirmation after sending a reply
class ReplySentModal extends StatefulWidget {
  final VoidCallback onCreate;

  const ReplySentModal({
    super.key,
    required this.onCreate,
  });

  @override
  State<ReplySentModal> createState() => _ReplySentModalState();
}

class _ReplySentModalState extends State<ReplySentModal> {
  final TextEditingController _usernameController = TextEditingController();
  bool _canCreate = false;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(() {
      setState(() {
        _canCreate = _usernameController.text.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0x33000000),
      ),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success icon
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/success_icon.png'),
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Title
              const Text(
                'Your reply has been sent',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF151515),
                ),
              ),

              const SizedBox(height: 4),

              // Description
              const Text(
                'A chat has been opened for you both and you can now send messages till you unlock a connection with the other person.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF151515),
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 16),

              // Divider
              Container(
                height: 1,
                color: const Color(0xFFE3E3E3),
              ),

              const SizedBox(height: 16),

              // Username section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create a temporary username',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF151515),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Create a temporary username for the other person that act as a differentiator before you unlock a connection.',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF151515),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Username input
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _canCreate
                            ? const Color(0xFF0AC5C5)
                            : const Color(0xFF737373),
                        width: 0.8,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        hintText: 'Create a username e.g Spring',
                        hintStyle: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF737373),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF363636),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Create button
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _canCreate ? widget.onCreate : null,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _canCreate
                                  ? const Color(0xFF0AC5C5)
                                  : const Color(0xFFE3E3E3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'Create',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: _canCreate
                                    ? Colors.white
                                    : const Color(0xFF737373),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
