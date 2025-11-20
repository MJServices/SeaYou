import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CustomKeyboard extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onSend;
  final bool showSendButton;

  const CustomKeyboard({
    super.key,
    required this.controller,
    this.onSend,
    this.showSendButton = true,
  });

  @override
  State<CustomKeyboard> createState() => _CustomKeyboardState();
}

class _CustomKeyboardState extends State<CustomKeyboard> {
  bool _isUpperCase = false;
  bool _isSymbolMode = false;

  final List<List<String>> _lowerCaseKeys = [
    ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
    ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'],
    ['z', 'x', 'c', 'v', 'b', 'n', 'm'],
  ];

  final List<List<String>> _upperCaseKeys = [
    ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
    ['Z', 'X', 'C', 'V', 'B', 'N', 'M'],
  ];

  final List<List<String>> _symbolKeys = [
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    ['-', '/', ':', ';', '(', ')', '\$', '&', '@', '"'],
    ['.', ',', '?', '!', '\''],
  ];

  void _onKeyTap(String key) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;

    final newText = text.replaceRange(
      selection.start,
      selection.end,
      key,
    );

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + key.length,
      ),
    );
  }

  void _onBackspace() {
    final text = widget.controller.text;
    final selection = widget.controller.selection;

    if (selection.start > 0) {
      final newText = text.replaceRange(
        selection.start - 1,
        selection.end,
        '',
      );

      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.start - 1,
        ),
      );
    }
  }

  void _onSpace() {
    _onKeyTap(' ');
  }

  @override
  Widget build(BuildContext context) {
    final keys = _isSymbolMode
        ? _symbolKeys
        : (_isUpperCase ? _upperCaseKeys : _lowerCaseKeys);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8F8F8),
        borderRadius: BorderRadius.vertical(top: Radius.circular(27)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Autocorrection bar (optional)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
            child: Row(
              children: [
                _buildAutocorrectButton('The'),
                const SizedBox(width: 20),
                Container(width: 1, height: 25, color: const Color(0xFFCCCCCC)),
                const SizedBox(width: 20),
                _buildAutocorrectButton('the'),
                const SizedBox(width: 20),
                Container(width: 1, height: 25, color: const Color(0xFFCCCCCC)),
                const SizedBox(width: 20),
                _buildAutocorrectButton('to'),
              ],
            ),
          ),

          const SizedBox(height: 13),

          // Keyboard rows
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.5),
            child: Column(
              children: [
                // Row 1
                _buildKeyRow(keys[0]),
                const SizedBox(height: 13),

                // Row 2
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildKeyRow(keys[1]),
                ),
                const SizedBox(height: 13),

                // Row 3 with shift and backspace
                Row(
                  children: [
                    _buildSpecialKey(
                      icon: Icons.arrow_upward,
                      onTap: () => setState(() => _isUpperCase = !_isUpperCase),
                      width: 45,
                      isActive: _isUpperCase,
                    ),
                    const SizedBox(width: 14.25),
                    Expanded(
                      child: _buildKeyRow(keys[2]),
                    ),
                    const SizedBox(width: 14.25),
                    _buildSpecialKey(
                      icon: Icons.backspace_outlined,
                      onTap: _onBackspace,
                      width: 45,
                    ),
                  ],
                ),
                const SizedBox(height: 13),

                // Row 4 with ABC, space, and send
                Row(
                  children: [
                    _buildSpecialKey(
                      text: _isSymbolMode ? '123' : 'ABC',
                      onTap: () =>
                          setState(() => _isSymbolMode = !_isSymbolMode),
                      width: 92.25,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildKey(' ', isSpace: true),
                    ),
                    const SizedBox(width: 6),
                    if (widget.showSendButton)
                      _buildSendButton()
                    else
                      _buildSpecialKey(
                        icon: Icons.keyboard_return,
                        onTap: () => _onKeyTap('\n'),
                        width: 92.25,
                        backgroundColor: const Color(0xFF0088FF),
                        textColor: Colors.white,
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Emoji and mic bar
          Padding(
            padding: const EdgeInsets.fromLTRB(36, 12, 39, 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.emoji_emotions_outlined, size: 26.92),
                  color: const Color(0xFF222B59).withValues(alpha: 0.63),
                  onPressed: () {},
                ),
                IconButton(
                  icon: SvgPicture.asset(
                    'assets/icons/microphone.svg',
                    width: 18.87,
                    height: 28.21,
                    colorFilter: ColorFilter.mode(
                      const Color(0xFF222B59).withValues(alpha: 0.63),
                      BlendMode.srcIn,
                    ),
                  ),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutocorrectButton(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4.6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'SF Pro',
          fontSize: 17,
          fontWeight: FontWeight.w400,
          color: Color(0xFF333333),
        ),
      ),
    );
  }

  Widget _buildKeyRow(List<String> keys) {
    return Row(
      children: keys.map((key) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3.25),
            child: _buildKey(key),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKey(String key, {bool isSpace = false}) {
    return GestureDetector(
      onTap: () => isSpace ? _onSpace() : _onKeyTap(key),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(8.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          key,
          style: const TextStyle(
            fontFamily: 'SF Compact',
            fontSize: 25,
            fontWeight: FontWeight.w400,
            color: Color(0xFF000000),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialKey({
    String? text,
    IconData? icon,
    required VoidCallback onTap,
    required double width,
    bool isActive = false,
    Color? backgroundColor,
    Color? textColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: 42,
        decoration: BoxDecoration(
          color: backgroundColor ?? const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(8.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: text != null
            ? Text(
                text,
                style: TextStyle(
                  fontFamily: 'SF Compact Rounded',
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  color: textColor ?? const Color(0xFF000000),
                ),
              )
            : Icon(
                icon,
                size: 23,
                color: textColor ?? const Color(0xFF000000),
              ),
      ),
    );
  }

  Widget _buildSendButton() {
    return GestureDetector(
      onTap: widget.onSend,
      child: Container(
        width: 92.25,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFF0088FF),
          borderRadius: BorderRadius.circular(8.5),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.arrow_upward,
          size: 19,
          color: Colors.white,
        ),
      ),
    );
  }
}
