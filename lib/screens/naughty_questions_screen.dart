import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';
import '../widgets/custom_button.dart';
import '../widgets/warm_gradient_background.dart';
import '../models/naughty_question.dart';

class NaughtyQuestionsScreen extends StatefulWidget {
  final String conversationId;
  final VoidCallback onComplete;

  const NaughtyQuestionsScreen({
    super.key,
    required this.conversationId,
    required this.onComplete,
  });

  @override
  State<NaughtyQuestionsScreen> createState() => _NaughtyQuestionsScreenState();
}

class _NaughtyQuestionsScreenState extends State<NaughtyQuestionsScreen> {
  List<NaughtyQuestion> _questions = [];
  NaughtyQuestion? _selectedQuestion;
  final TextEditingController _answerController = TextEditingController();
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
    
    // Listen to text changes to update button state
    _answerController.addListener(() {
      setState(() {
        // This will trigger a rebuild when text changes
        // enabling/disabling the submit button in real-time
      });
    });
  }

  Future<void> _loadQuestions() async {
    try {
      final response = await Supabase.instance.client
          .from('naughty_questions')
          .select()
          .eq('is_active', true)
          .order('display_order');

      setState(() {
        _questions = (response as List)
            .map((json) => NaughtyQuestion.fromJson(json))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading questions: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitAnswer() async {
    if (_selectedQuestion == null || _answerController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a question and provide an answer'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('Not authenticated');

      // Get conversation to determine which user field to update
      final conversation = await Supabase.instance.client
          .from('conversations')
          .select('user_a_id, user_b_id, naughty_question_id')
          .eq('id', widget.conversationId)
          .single();

      final isUserA = conversation['user_a_id'] == currentUserId;
      final answerField = isUserA ? 'user1_naughty_answer' : 'user2_naughty_answer';

      // Update conversation with question and answer
      await Supabase.instance.client
          .from('conversations')
          .update({
            'naughty_question_id': _selectedQuestion!.id,
            answerField: _answerController.text.trim(),
          })
          .eq('id', widget.conversationId);

      if (mounted) {
        widget.onComplete();
      }
    } catch (e) {
      debugPrint('Error submitting answer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WarmGradientBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.white),
                )
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            const Text(
                              'Choose Your Question',
                              style: AppTextStyles.displayText,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Select one intimate question to answer. Your match will also answer their chosen question.',
                              style: AppTextStyles.bodyText.copyWith(
                                color: AppColors.darkGrey,
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Question Cards
                            ..._questions.map((question) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                onTap: () {
                                  debugPrint('🎯 Question tapped: ${question.questionText}');
                                  setState(() {
                                    _selectedQuestion = question;
                                  });
                                  debugPrint('✅ Selected question set: ${_selectedQuestion?.questionText}');
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: _selectedQuestion?.id == question.id
                                        ? AppColors.primary.withValues(alpha: 0.1)
                                        : AppColors.white,
                                    border: Border.all(
                                      color: _selectedQuestion?.id == question.id
                                          ? AppColors.primary
                                          : AppColors.grey,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _selectedQuestion?.id == question.id
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_unchecked,
                                        color: _selectedQuestion?.id == question.id
                                            ? AppColors.primary
                                            : AppColors.grey,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          question.questionText,
                                          style: AppTextStyles.bodyText.copyWith(
                                            color: AppColors.black,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )),
                            
                            const SizedBox(height: 24),
                            
                            // Answer Field
                            if (_selectedQuestion != null) ...[
                              Text(
                                'Your Answer',
                                style: AppTextStyles.bodyText.copyWith(
                                  color: AppColors.darkGrey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.primary,
                                    width: 0.8,
                                  ),
                                ),
                                child: TextField(
                                  controller: _answerController,
                                  maxLines: 4,
                                  maxLength: 500,
                                  style: AppTextStyles.bodyText,
                                  decoration: const InputDecoration(
                                    hintText: 'Type your answer here...',
                                    hintStyle: AppTextStyles.bodyText,
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.all(12),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    
                    // Submit Button
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: CustomButton(
                        text: _isSubmitting ? 'Submitting...' : 'Submit Answer',
                        isActive: _selectedQuestion != null && 
                                  _answerController.text.trim().isNotEmpty &&
                                  !_isSubmitting,
                        onPressed: _submitAnswer,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
