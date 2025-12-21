import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';

class CustomTextField extends StatelessWidget {
  final String hintText;
  final TextEditingController? controller;
  final bool isActive;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  const CustomTextField({
    super.key,
    required this.hintText,
    this.controller,
    this.isActive = false,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.focusNode,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? AppColors.primary : AppColors.grey,
          width: 0.8,
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        keyboardType: keyboardType,
        maxLines: maxLines,
        maxLength: maxLength,
        onChanged: onChanged,
        style: AppTextStyles.bodyText.copyWith(
          color: isActive ? AppColors.darkGrey : AppColors.grey,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppTextStyles.bodyText,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(12),
          suffixIcon: suffixIcon,
          counterText: '', // Hide the counter text
        ),
      ),
    );
  }
}
