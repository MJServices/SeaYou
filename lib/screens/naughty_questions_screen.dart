import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';
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
      
      // 2. Fetch conversation to check for persisted choice
      final conv = await Supabase.instance.client
          .from('conversations')
          .select('naughty_question_id, user1_naughty_answer, user2_naughty_answer, user_a_id, user_b_id')
          .eq('id', widget.conversationId)
          .single();

      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      final bool isUserA = conv['user_a_id'] == currentUserId;
      final String? existingAnswer = isUserA ? conv['user1_naughty_answer'] : conv['user2_naughty_answer'];
      
      if (existingAnswer != null && existingAnswer.isNotEmpty) {
        _answerController.text = existingAnswer;
      }

      int? persistedId = conv['naughty_question_id'];
      
      setState(() {
        _availableQuestions = questions;
        _persistedQuestionId = persistedId;
        if (persistedId != null) {
          _selectedQuestion = questions.firstWhere(
            (NaughtyQuestion q) => q.id == persistedId,
            orElse: () => questions.first,
          );
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

      // Persist the choice immediately
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
          SnackBar(content: Text('${AppLocalizations.of(context).tr('errors.save_failed')}: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitAnswer() async {
    if (_selectedQuestion == null || _answerController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).tr('errors.provide_answer')),
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

      // NEW: Persist in chat history
      // 1. Send the question (only if not already sent to this chat)
      final questionText = _selectedQuestion!.questionText;
      
      // We use a simple check to avoid duplicate question bubbles if both users answer
      final existingMsg = await Supabase.instance.client
          .from('messages')
          .select('id')
          .eq('conversation_id', widget.conversationId)
          .eq('mood', 'naughty_question') // Use mood instead of type
          .eq('text', questionText)
          .maybeSingle();

      if (existingMsg == null) {
        await _db.sendMessage(
          conversationId: widget.conversationId,
          senderId: currentUserId,
          type: 'text', // Standard type to avoid constraint violation
          mood: 'naughty_question', // Custom mood for UI logic
          text: questionText,
        );
      }

      // 2. Send the user's specific answer
      await _db.sendMessage(
        conversationId: widget.conversationId,
        senderId: currentUserId,
        type: 'text', // Standard type to avoid constraint violation
        mood: 'naughty_answer', // Custom mood for UI logic
        text: _answerController.text.trim(),
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
                      icon: const Icon(Icons.arrow_back, color: Color(0xFF151515)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(
                      child: Text(
                        'Intimate Discoveries',
                        textAlign: TextAlign.center,
                        style: TextStyle(
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
                        const Text(
                          'Naughty Question!',
                          style: TextStyle(
                            fontFamily: 'PlayfairDisplay', // Elegant serif font
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFF4081), // Softer Pink (PinkAccent)
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'You can only ask one question!\nChoose wisely!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
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
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: _availableQuestions.map((q) => Expanded(child: _buildScroll(q))).toList(),
                        )
                        else 
                        const Text('No questions available in database.'),
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
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getCategoryColor(_selectedQuestion!.category).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _selectedQuestion!.category.toUpperCase(),
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _getCategoryColor(_selectedQuestion!.category),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                _selectedQuestion!.questionText,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'PlayfairDisplay', // Use Serif for question too?
                                  fontSize: 22, // Larger font for question
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FontStyle.italic,
                                  color: const Color(0xFF151515),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 30),
                              const Divider(),
                              const SizedBox(height: 20),
                              const Text(
                                'YOUR ANSWER',
                                style: TextStyle(
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
                                  hintText: 'Share your thoughts...',
                                  hintStyle: const TextStyle(color: Color(0xFFAFAFAF)),
                                  fillColor: const Color(0xFFF9F9F9),
                                  filled: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        CustomButton(
                          text: _isSubmitting ? 'Submitting...' : 'Submit Answer',
                          isActive: _answerController.text.trim().isNotEmpty && !_isSubmitting,
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
              errorBuilder: (ctx, err, stack) => Icon(Icons.history_edu, size: 60, color: color),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            q.label,
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
