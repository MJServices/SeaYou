import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/custom_button.dart';
import '../widgets/warm_gradient_background.dart';
import '../i18n/app_localizations.dart';
import '../models/naughty_question.dart';
import '../services/database_service.dart';

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
  final DatabaseService _db = DatabaseService();
  List<NaughtyQuestion> _availableQuestions = [];
  NaughtyQuestion? _selectedQuestion;
  final TextEditingController _answerController = TextEditingController();
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _questionDiscovered = false;
  int? _persistedQuestionId;

  @override
  void initState() {
    super.initState();
    _loadData();
    _answerController.addListener(() {
      setState(() {});
    });
  }

  Future<void> _loadData() async {
    try {
      // 1. Fetch available questions
      final List<NaughtyQuestion> questions = await _db.getNaughtyQuestions();

      // 2. Fetch conversation to check for per-user persisted choice
      final conv = await Supabase.instance.client
          .from('conversations')
          .select(
              'user1_naughty_question_id, user2_naughty_question_id, user1_naughty_answer, user2_naughty_answer, user_a_id, user_b_id')
          .eq('id', widget.conversationId)
          .single();

      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      final bool isUserA = conv['user_a_id'] == currentUserId;

      // Each user has their own chosen question id and answer
      final String? existingAnswer =
          isUserA ? conv['user1_naughty_answer'] : conv['user2_naughty_answer'];
      final int? myPersistedQuestionId = isUserA
          ? conv['user1_naughty_question_id'] as int?
          : conv['user2_naughty_question_id'] as int?;

      if (existingAnswer != null && existingAnswer.isNotEmpty) {
        _answerController.text = existingAnswer;
      }

      setState(() {
        _availableQuestions = questions;
        _persistedQuestionId = myPersistedQuestionId;

        // Automatically show already-chosen question (locked)
        if (_persistedQuestionId != null) {
          final existing = questions.firstWhere(
            (q) => q.id == _persistedQuestionId,
            orElse: () => questions.first,
          );
          _selectedQuestion = existing;
          _questionDiscovered = true;
        }

        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading naughty questions data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onScrollTapped(NaughtyQuestion question) async {
    if (_questionDiscovered) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('Not authenticated');

      // Persist the per-user choice immediately to the database
      await _db.updateNaughtyQuestion(
        conversationId: widget.conversationId,
        userId: currentUserId,
        questionId: question.id,
      );

      setState(() {
        _selectedQuestion = question;
        _questionDiscovered = true;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error persisting question choice: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${AppLocalizations.of(context).tr('errors.save_failed')}: $e'),
              backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitAnswer() async {
    if (_selectedQuestion == null || _answerController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(AppLocalizations.of(context).tr('errors.provide_answer')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('Not authenticated');

      await _db.updateNaughtyQuestion(
        conversationId: widget.conversationId,
        userId: currentUserId,
        answer: _answerController.text.trim(),
      );

      // 1. Send the selected question
      // We now use a more specific mood to allow for easier translation on the receiver side
      // Both users send their own question prompt to the chat.
      final mood = 'naughty_question_${_selectedQuestion!.id}';

      await _db.sendMessage(
        conversationId: widget.conversationId,
        senderId: currentUserId,
        type: 'text',
        mood: mood,
        text: _selectedQuestion!
            .questionText, // Still send English as fallback/storage
        feelingDelta: 0,
      );

      // 2. Send the user's specific answer
      await _db.sendMessage(
        conversationId: widget.conversationId,
        senderId: currentUserId,
        type: 'text', // Standard type to avoid constraint violation
        mood: 'naughty_answer', // Custom mood for UI logic
        text: _answerController.text.trim(),
        feelingDelta: 0,
      );

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
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Color(0xFF151515)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)
                            .tr('chat.naughty_question_selection_title'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF151515),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // Balance for back button
                  ],
                ),
              ),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            if (!_questionDiscovered) ...[
                              Text(
                                AppLocalizations.of(context)
                                    .tr('chat.naughty_question_main_title'),
                                style: const TextStyle(
                                  fontFamily: 'PlayfairDisplay',
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFFF4081),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                AppLocalizations.of(context)
                                    .tr('chat.naughty_question_subtitle'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 40),

                              // 3 Scrolls Row
                              if (_availableQuestions.isNotEmpty)
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: _availableQuestions
                                      .map((q) =>
                                          Expanded(child: _buildScroll(q)))
                                      .toList(),
                                )
                              else
                                Text(AppLocalizations.of(context)
                                    .tr('chat.naughty_question_no_questions')),
                              const SizedBox(height: 40),
                            ] else ...[
                              const SizedBox(height: 20),
                              // Revealed Question View
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _getCategoryColor(
                                                _selectedQuestion!.category)
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        AppLocalizations.of(context)
                                            .tr('chat.naughty_question_category_${_selectedQuestion!.category.toLowerCase()}')
                                            .toUpperCase(),
                                        style: TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: _getCategoryColor(
                                              _selectedQuestion!.category),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      AppLocalizations.of(context).tr(
                                          'surprise.q${_selectedQuestion!.id}'),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontFamily:
                                            'PlayfairDisplay', // Use Serif for question too?
                                        fontSize:
                                            22, // Larger font for question
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FontStyle.italic,
                                        color: Color(0xFF151515),
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 30),
                                    const Divider(),
                                    const SizedBox(height: 20),
                                    Text(
                                      AppLocalizations.of(context).tr(
                                          'chat.naughty_question_your_answer'),
                                      style: const TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF737373),
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _answerController,
                                      maxLines: 4,
                                      autofocus: _answerController.text.isEmpty,
                                      decoration: InputDecoration(
                                        hintText: AppLocalizations.of(context)
                                            .tr('chat.naughty_question_hint'),
                                        hintStyle: const TextStyle(
                                            color: Color(0xFFAFAFAF)),
                                        fillColor: const Color(0xFFF9F9F9),
                                        filled: true,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),
                              CustomButton(
                                text: _isSubmitting
                                    ? AppLocalizations.of(context)
                                        .tr('chat.naughty_question_submitting')
                                    : AppLocalizations.of(context)
                                        .tr('chat.naughty_question_submit'),
                                isActive:
                                    _answerController.text.trim().isNotEmpty &&
                                        !_isSubmitting,
                                onPressed: _submitAnswer,
                              ),
                              const SizedBox(height: 24),
                            ],
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'sweet':
        return const Color(0xFF9090FF); // Periwinkle/Blue-ish from screenshot
      case 'daring':
        return const Color(0xFFFFA500); // Orange
      case 'naughty':
        return const Color(0xFFFF00FF); // Magenta/Pink from screenshot
      default:
        return Colors.teal;
    }
  }

  Widget _buildScroll(NaughtyQuestion q) {
    final color = _getCategoryColor(q.category);

    return GestureDetector(
      onTap: () => _onScrollTapped(q),
      child: Column(
        children: [
          // Just the floating scroll image, no container/card background
          SizedBox(
            width: 80, // Size matched to screenshot
            height: 80,
            child: Image.asset(
              'assets/images/letter.png', // Switched to letter.png (likely the cleaner asset)
              fit: BoxFit.contain,
              errorBuilder: (ctx, err, stack) =>
                  Icon(Icons.history_edu, size: 60, color: color),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context).tr(
                'chat.naughty_question_category_${q.category.toLowerCase()}'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 16, // Verified from screenshot, looks slightly larger
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
