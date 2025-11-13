import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isActive;
  final bool isOutline;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isActive = true,
    this.isOutline = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: isActive ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isOutline
              ? const Color(0xFFECFAFA)
              : (isActive ? AppColors.primary : AppColors.lightGrey),
          foregroundColor: isOutline
              ? AppColors.primary
              : (isActive ? AppColors.white : AppColors.grey),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: isOutline
                ? const BorderSide(color: AppColors.primary, width: 0.8)
                : BorderSide.none,
          ),
          padding: const EdgeInsets.all(12),
        ),
        child: Text(
          text,
          style: AppTextStyles.bodyText.copyWith(
            color: isOutline
                ? AppColors.primary
                : (isActive ? AppColors.white : AppColors.grey),
          ),
        ),
      ),
    );
  }
}
