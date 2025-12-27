import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/warm_gradient_background.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_text_styles.dart';
import '../../widgets/custom_button.dart';
import '../../services/database_service.dart';

/// Edit Quote Screen - Allows user to edit their secret quote/desire
class EditQuoteScreen extends StatefulWidget {
  const EditQuoteScreen({super.key});

  @override
  State<EditQuoteScreen> createState() => _EditQuoteScreenState();
}

class _EditQuoteScreenState extends State<EditQuoteScreen> {
  final TextEditingController _quoteController = TextEditingController();
  final DatabaseService _databaseService = DatabaseService();
  final SupabaseClient _supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  bool _isSaving = false;

  String? _errorMessage;

  bool get isFormValid =>
      _quoteController.text.trim().isNotEmpty && !_isSaving;

  @override
  void initState() {
    super.initState();
    _loadCurrentQuote();
  }

  Future<void> _loadCurrentQuote() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final profile = await _databaseService.getProfile(userId);
      if (profile != null && mounted) {
        setState(() {
          _quoteController.text = profile['secret_desire'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading quote: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load quote';
        });
      }
    }
  }

  Future<void> _saveQuote() async {
    if (!isFormValid) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('No user logged in');
      }

      final quote = _quoteController.text.trim();
      
      // Validate quote is not empty
      if (quote.isEmpty) {
        throw Exception('Quote cannot be empty');
      }

      await _databaseService.updateSecretDesire(userId, quote);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quote updated successfully!'),
          backgroundColor: Color(0xFF0AC5C5),
          duration: Duration(seconds: 2),
        ),
      );

      // Navigate back
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error saving quote: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _quoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WarmGradientBackground(
        child: Stack(
          children: [
            // Decorative ellipse
            Positioned(
              top: -100,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            // Main content
            SafeArea(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: SvgPicture.asset(
                            'assets/icons/arrow_left.svg',
                            width: 24,
                            height: 24,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Edit my quote',
                          style: AppTextStyles.displayText.copyWith(
                            color: AppColors.black,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 16),

                                // Title
                                Text(
                                  'Secret Desire',
                                  style: AppTextStyles.displayText.copyWith(
                                    fontSize: 20,
                                    color: AppColors.black,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Description
                                const Text(
                                  'This will be anonymous to everyone.',
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 12,
                                    color: Color(0xFF737373),
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Quote input
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: TextField(
                                    controller: _quoteController,
                                    maxLines: 8,
                                    maxLength: 2000,
                                    style: AppTextStyles.bodyText.copyWith(
                                      color: AppColors.black,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Share your secret desire...',
                                      hintStyle: AppTextStyles.bodyText.copyWith(
                                        color: AppColors.grey,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: const EdgeInsets.all(16),
                                      counterStyle: const TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 12,
                                        color: Color(0xFF737373),
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 8),

                                // Character count indicator
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${_quoteController.text.length}/2000',
                                      style: const TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 12,
                                        color: Color(0xFF737373),
                                      ),
                                    ),
                                  ],
                                ),

                                if (_errorMessage != null) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.red.shade200),
                                    ),
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 14,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 32),

                                // Save button
                                CustomButton(
                                  text: 'Save',
                                  onPressed: _saveQuote,
                                  isActive: isFormValid && !_isSaving,
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
