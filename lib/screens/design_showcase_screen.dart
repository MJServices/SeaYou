import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Design Showcase Screen - Demonstrates all design assets from Figma
class DesignShowcaseScreen extends StatelessWidget {
  const DesignShowcaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Design System Showcase'),
        backgroundColor: const Color(0xFF0AC5C5),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection('Colors', _buildColors()),
          _buildSection('Icons - Navigation', _buildNavigationIcons()),
          _buildSection('Icons - Actions', _buildActionIcons()),
          _buildSection('Icons - Media', _buildMediaIcons()),
          _buildSection('Icons - Input', _buildInputIcons()),
          _buildSection('Typography', _buildTypography()),
          _buildSection('Buttons', _buildButtons()),
          _buildSection('Cards', _buildCards()),
          _buildSection('Images', _buildImages()),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF151515),
          ),
        ),
        const SizedBox(height: 16),
        content,
        const Divider(height: 32),
      ],
    );
  }

  Widget _buildColors() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildColorSwatch('Brand Teal', const Color(0xFF0AC5C5)),
        _buildColorSwatch('Dark BG', const Color(0xFF151515)),
        _buildColorSwatch('Light BG', const Color(0xFFF8F8F8)),
        _buildColorSwatch('Purple', const Color(0xFF4B2F6F)),
        _buildColorSwatch('Yellow', const Color(0xFFFBBF30)),
        _buildColorSwatch('Pink', const Color(0xFFFFA9EC)),
        _buildColorSwatch('Blue', const Color(0xFFB2EBFF)),
        _buildColorSwatch('Gray', const Color(0xFF737373)),
        _buildColorSwatch('iOS Blue', const Color(0xFF0088FF)),
      ],
    );
  }

  Widget _buildColorSwatch(String name, Color color) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: const TextStyle(fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildNavigationIcons() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildIcon('home_simple.svg', 'Home'),
        _buildIcon('chat_lines.svg', 'Chat'),
        _buildIcon('bell.svg', 'Bell'),
        _buildIcon('arrow_left.svg', 'Back'),
        _buildIcon('nav_arrow_down.svg', 'Down'),
      ],
    );
  }

  Widget _buildActionIcons() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildIcon('plus.svg', 'Plus'),
        _buildIcon('xmark.svg', 'Close'),
        _buildIcon('check.svg', 'Check'),
        _buildIcon('check_square.svg', 'Checkbox'),
        _buildIcon('search.svg', 'Search'),
      ],
    );
  }

  Widget _buildMediaIcons() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildIcon('camera.svg', 'Camera'),
        _buildIcon('microphone.svg', 'Mic'),
        _buildIcon('voice.svg', 'Voice'),
        _buildIcon('media_image.svg', 'Image'),
        _buildIcon('play.svg', 'Play'),
        _buildIcon('pause.svg', 'Pause'),
      ],
    );
  }

  Widget _buildInputIcons() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildIcon('eye_empty.svg', 'Show'),
        _buildIcon('eye_off.svg', 'Hide'),
      ],
    );
  }

  Widget _buildIcon(String asset, String label) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Center(
            child: SvgPicture.asset(
              'assets/icons/$asset',
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(
                Color(0xFF0AC5C5),
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTypography() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Heading Large',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Color(0xFF151515),
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Heading Medium',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF151515),
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Body Text - Regular',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Color(0xFF151515),
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Body Small',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF737373),
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Caption Text',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Color(0xFF737373),
          ),
        ),
      ],
    );
  }

  Widget _buildButtons() {
    return Column(
      children: [
        // Primary button
        Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF0AC5C5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Text(
              'Primary Button',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Secondary button
        Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFECFAFA),
            border: Border.all(
              color: const Color(0xFF0AC5C5),
              width: 0.8,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Text(
              'Secondary Button',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0AC5C5),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Floating action button
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF0AC5C5),
            borderRadius: BorderRadius.circular(40),
            boxShadow: const [
              BoxShadow(
                color: Color(0x331E1E1E),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.add,
            color: Colors.white,
            size: 32,
          ),
        ),
      ],
    );
  }

  Widget _buildCards() {
    return Column(
      children: [
        // Light card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFFCFCFC),
            border: Border.all(
              color: const Color(0xFFE3E3E3),
              width: 0.8,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Card Title',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF151515),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Card content goes here. This is a sample card with border and padding.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF737373),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Message bubble (sent)
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 250),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0AC5C5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Sent message bubble',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Message bubble (received)
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 250),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2C),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Received message bubble',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImages() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildImagePreview('empty bottle.png', 'Empty Bottle'),
        _buildImagePreview('fill bottle.png', 'Fill Bottle'),
        _buildImagePreview('profile_avatar.png', 'Avatar'),
        _buildImagePreview('photo_stamp.png', 'Photo Stamp'),
        _buildImagePreview('celebration.png', 'Celebration'),
        _buildImagePreview('letter.png', 'Letter'),
      ],
    );
  }

  Widget _buildImagePreview(String asset, String label) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/$asset',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(fontSize: 10),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
