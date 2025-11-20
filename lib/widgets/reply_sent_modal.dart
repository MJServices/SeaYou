import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ReplySentModal extends StatefulWidget {
  final VoidCallback onCreateUsername;

  const ReplySentModal({
    super.key,
    required this.onCreateUsername,
  });

  @override
  State<ReplySentModal> createState() => _ReplySentModalState();
}

class _ReplySentModalState extends State<ReplySentModal> {
  final TextEditingController _usernameController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: SvgPicture.asset(
                'assets/icons/check.svg',
                width: 48,
                height: 48,
                colorFilter: const ColorFilter.mode(
                  Color(0xFF4CAF50),
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            const Text(
              'Your reply has been sent',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Color(0xFF151515),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Description
            const Text(
              'A chat has been opened with this person. You can continue your conversation there.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF666666),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Divider
            Container(
              height: 1,
              color: const Color(0xFFE0E0E0),
            ),
            const SizedBox(height: 24),

            // Username Section
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Create a temporary username',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF151515),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This username will be visible to the person you\'re chatting with.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Color(0xFF666666),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),

            // Username Input
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                hintText: 'Enter username',
                hintStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF999999),
                ),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Color(0xFF151515),
              ),
            ),
            const SizedBox(height: 24),

            // Create Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  if (_usernameController.text.isNotEmpty) {
                    widget.onCreateUsername();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF151515),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  'Create',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
