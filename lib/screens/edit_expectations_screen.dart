import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/warm_gradient_background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database_service.dart';
import '../i18n/app_localizations.dart';

class EditExpectationsScreen extends StatefulWidget {
  final Map<String, dynamic> userProfile;
  const EditExpectationsScreen({super.key, required this.userProfile});

  @override
  State<EditExpectationsScreen> createState() => _EditExpectationsScreenState();
}

class _EditExpectationsScreenState extends State<EditExpectationsScreen> {
  final Set<String> _selectedExpectations = {};
  String? _selectedGender;
  bool _isSaving = false;

  final List<String> expectations = [
    'A serious relationship',
    'A casual relationship',
    'To make friends',
    'I do not really know yet',
  ];

  final List<String> genders = [
    'Men',
    'Women',
    'Non-binary',
    'Everyone',
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    // Expectations are stored as comma-separated strings
    final String? currentExp = widget.userProfile['expectation'];
    if (currentExp != null && currentExp.isNotEmpty) {
      _selectedExpectations.addAll(currentExp.split(', ').map((e) => e.trim()));
    }

    _selectedGender = widget.userProfile['interested_in'];
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await DatabaseService().updateProfile(userId, {
        'expectation': _selectedExpectations.join(', '),
        'interested_in': _selectedGender,
      });

      if (mounted) {
        Navigator.pop(context, true); // Return true to signal data change
      }
    } catch (e) {
      debugPrint('Error saving expectations: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);

    return Scaffold(
      body: WarmGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                      ),
                      Text(
                        tr.tr('onboarding.expectations.title'),
                        style: AppTextStyles.displayText,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        tr.tr('onboarding.expectations.subtitle'),
                        style: AppTextStyles.bodyText,
                      ),
                      const SizedBox(height: 24),
                      ...expectations.map((exp) => _buildOption(exp, true)),
                      const SizedBox(height: 32),
                      Text(
                        tr.tr('onboarding.expectations.who_to_meet'),
                        style: AppTextStyles.displayText,
                      ),
                      const SizedBox(height: 24),
                      ...genders.map((gender) => _buildOption(gender, false)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: CustomButton(
                  text: _isSaving
                      ? tr.tr('common.processing')
                      : tr.tr('settings.save_button'),
                  isActive: _selectedExpectations.isNotEmpty &&
                      _selectedGender != null &&
                      !_isSaving,
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption(String text, bool isExpectation) {
    final tr = AppLocalizations.of(context);
    final isSelected = isExpectation
        ? _selectedExpectations.contains(text)
        : _selectedGender == text;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isExpectation) {
            if (_selectedExpectations.contains(text)) {
              _selectedExpectations.remove(text);
            } else {
              _selectedExpectations.add(text);
            }
          } else {
            _selectedGender = text;
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.background : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.grey,
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                isExpectation
                    ? tr.tr(
                        'onboarding.expectations.options.${text.toLowerCase().replaceAll(' ', '_')}')
                    : tr.tr(
                        'onboarding.expectations.genders.${text.toLowerCase().replaceAll(' ', '_')}'),
                style: AppTextStyles.bodyText.copyWith(
                  color: isSelected ? AppColors.darkGrey : AppColors.grey,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle,
                  color: AppColors.primary, size: 18),
          ],
        ),
      ),
    );
  }
}
