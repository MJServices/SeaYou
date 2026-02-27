import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/warm_gradient_background.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_text_styles.dart';
import '../../widgets/custom_button.dart';
import '../../i18n/app_localizations.dart';
import '../../services/database_service.dart';

/// Edit Fantasy Screen - Allows user to edit their anonymous fantasy
class EditFantasyScreen extends StatefulWidget {
  const EditFantasyScreen({super.key});

  @override
  State<EditFantasyScreen> createState() => _EditFantasyScreenState();
}

class _EditFantasyScreenState extends State<EditFantasyScreen> {
  final TextEditingController _fantasyController = TextEditingController();
  final DatabaseService _databaseService = DatabaseService();
  final SupabaseClient _supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  bool _isSaving = false;
  String? _fantasyId;

  String? _errorMessage;

  bool get isFormValid =>
      _fantasyController.text.trim().length >= 10 && !_isSaving;

  @override
  void initState() {
    super.initState();
    _loadCurrentFantasy();
  }

  Future<void> _loadCurrentFantasy() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final fantasies = await _databaseService.listUserFantasies(userId);
      if (fantasies.isNotEmpty && mounted) {
        setState(() {
          final latest = fantasies.first;
          _fantasyController.text = latest['text'] ?? '';
          _fantasyId = latest['id'];
          _isLoading = false;
        });
      } else if (mounted) {
        // Fallback to secret_desire
        final profile = await _databaseService.getProfile(userId);
        if (profile != null && profile['secret_desire'] != null) {
          setState(() {
            _fantasyController.text = profile['secret_desire'];
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint('Error loading fantasy: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = AppLocalizations.of(context).tr('errors.load_fantasy_failed');
        });
      }
    }
  }

  Future<void> _saveFantasy() async {
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

      final text = _fantasyController.text.trim();
      
      if (_fantasyId != null) {
        await _databaseService.updateFantasy(_fantasyId!, text);
      } else {
        await _databaseService.createFantasy(userId, text);
      }

      await _databaseService.updateSecretDesire(userId, text);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).tr('profile.fantasy_updated')),
          backgroundColor: const Color(0xFF0AC5C5),
          duration: const Duration(seconds: 2),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error saving fantasy: $e');
      if (mounted) {
        setState(() {
          _errorMessage = AppLocalizations.of(context).tr('errors.save_fantasy_failed');
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _fantasyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WarmGradientBackground(
        child: Stack(
          children: [
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
                          AppLocalizations.of(context).tr('profile.edit_fantasy'),
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
                                  AppLocalizations.of(context).tr('profile.fantasy_label'),
                                  style: AppTextStyles.displayText.copyWith(
                                    fontSize: 20,
                                    color: AppColors.black,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Description
                                Text(
                                  AppLocalizations.of(context).tr('profile.fantasy_anonymous_hint'),
                                  style: const TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 12,
                                    color: Color(0xFF737373),
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Fantasy input
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: TextField(
                                    controller: _fantasyController,
                                    onChanged: (_) => setState(() {}),
                                    maxLines: 8,
                                    maxLength: 400,
                                    style: AppTextStyles.bodyText.copyWith(
                                      color: AppColors.black,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: AppLocalizations.of(context).tr('profile.fantasy_placeholder'),
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
                                  text: _isSaving ? AppLocalizations.of(context).tr('common.saving') : AppLocalizations.of(context).tr('common.confirm'),
                                  onPressed: isFormValid && !_isSaving ? _saveFantasy : null,
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
