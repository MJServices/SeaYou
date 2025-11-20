import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';
import 'custom_button.dart';

/// Rate SeaYou Modal - Allows users to rate the app
class RateSeaYouModal extends StatefulWidget {
  const RateSeaYouModal({super.key});

  @override
  State<RateSeaYouModal> createState() => _RateSeaYouModalState();
}

class _RateSeaYouModalState extends State<RateSeaYouModal> {
  int _selectedRating = 0;
  final TextEditingController _feedbackController = TextEditingController();

  bool get isFormValid => _selectedRating > 0;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rate SeaYou',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF363636),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Rate your experience with SeaYou.',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF737373),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: SvgPicture.asset(
                    'assets/icons/xmark.svg',
                    width: 24,
                    height: 24,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFF151515),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Star Rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedRating = index + 1;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      index < _selectedRating
                          ? Icons.star
                          : Icons.star_border,
                      size: 40,
                      color: index < _selectedRating
                          ? const Color(0xFFFFC700)
                          : const Color(0xFFE3E3E3),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // Feedback Text Field
            TextField(
              controller: _feedbackController,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              style: AppTextStyles.bodyText.copyWith(
                color: _feedbackController.text.isNotEmpty
                    ? AppColors.darkGrey
                    : AppColors.grey,
              ),
              decoration: InputDecoration(
                hintText: 'Describe your experience with SeaYou',
                hintStyle: AppTextStyles.bodyText,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _feedbackController.text.isNotEmpty
                        ? AppColors.primary
                        : AppColors.grey,
                    width: 0.8,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _feedbackController.text.isNotEmpty
                        ? AppColors.primary
                        : AppColors.grey,
                    width: 0.8,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 0.8,
                  ),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 24),

            // Rate Button
            CustomButton(
              text: 'Rate',
              isActive: isFormValid,
              onPressed: isFormValid
                  ? () {
                      // Submit rating
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Thank you for your feedback!'),
                        ),
                      );
                      Navigator.pop(context);
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

