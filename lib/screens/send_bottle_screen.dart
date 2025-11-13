import 'package:flutter/material.dart';
import '../widgets/status_bar.dart';

class SendBottleScreen extends StatefulWidget {
  const SendBottleScreen({super.key});

  @override
  State<SendBottleScreen> createState() => _SendBottleScreenState();
}

class _SendBottleScreenState extends State<SendBottleScreen> {
  final TextEditingController _textController = TextEditingController();
  final String _selectedType = 'Text';
  String _selectedMood = 'Dreamy';
  bool _isFormValid = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_updateFormState);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _updateFormState() {
    setState(() {
      _isFormValid = _textController.text.trim().isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const CustomStatusBar(),
            const SizedBox(height: 18),
            _buildHeader(),
            const SizedBox(height: 24),
            _buildMoodSelector(),
            const SizedBox(height: 24),
            Expanded(
              child: _buildContent(),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF363636),
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: const Color(0xFF0AC5C5),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Text(
                  _selectedType,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF0AC5C5),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                  color: Color(0xFF0AC5C5),
                ),
              ],
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {},
            child: const Text(
              'Drafts',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0AC5C5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customize your mood:',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF737373),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildMoodChip('Dreamy', const Color(0xFF9B98E6)),
              const SizedBox(width: 8),
              _buildMoodChip('Curious', const Color(0xFFFFC700)),
              const SizedBox(width: 8),
              _buildMoodChip('Calm', const Color(0xFF9ECFD4)),
              const SizedBox(width: 8),
              _buildMoodChip('Playful', const Color(0xFFFF9F9B)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMoodChip(String mood, Color color) {
    final isSelected = _selectedMood == mood;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMood = mood;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color,
            width: 1,
          ),
        ),
        child: Text(
          mood,
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              maxLines: null,
              maxLength: 400,
              decoration: const InputDecoration(
                hintText: 'Start typing',
                hintStyle: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF363636),
                ),
                border: InputBorder.none,
                counterStyle: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF737373),
                ),
              ),
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF151515),
              ),
            ),
          ),
          const Text(
            'Max character length: 400',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF737373),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(0xFFE3E3E3),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _isFormValid
                    ? const Color(0xFF0AC5C5)
                    : const Color(0xFFE3E3E3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isFormValid ? _showPreview : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Center(
                      child: Text(
                        'Preview',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: _isFormValid
                              ? Colors.white
                              : const Color(0xFF737373),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPreview() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPreviewModal(),
    );
  }

  Widget _buildPreviewModal() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                'Preview',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF151515),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: _getMoodGradient(),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _textController.text,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.5,
                color: Color(0xFF151515),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFAFA),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF0AC5C5),
                      width: 0.8,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(
                          child: Text(
                            'Save as Drafts',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF0AC5C5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 88,
                decoration: BoxDecoration(
                  color: const Color(0xFF0AC5C5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _showSentModal();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(
                        child: Text(
                          'Send',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSentModal() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFECFAFA),
                ),
                child: const Icon(
                  Icons.check,
                  color: Color(0xFF0AC5C5),
                  size: 24,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Your bottle has been sent!',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF151515),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Wait for someone to retrieve it across the sea and send one to you',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF151515),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3E3E3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Center(
                              child: Text(
                                'Close',
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF737373),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0AC5C5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pop(context);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Center(
                              child: Text(
                                'Send a new bottle',
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  LinearGradient _getMoodGradient() {
    switch (_selectedMood) {
      case 'Dreamy':
        return const LinearGradient(
          begin: Alignment.center,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF9B98E6), Color(0xFFC7CEEA)],
        );
      case 'Curious':
        return const LinearGradient(
          begin: Alignment.center,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFC700), Color(0xFFD89736)],
        );
      case 'Calm':
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF9ECFD4), Color(0xFF65ADA9)],
        );
      case 'Playful':
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF9F9B), Color(0xFFFF6D68)],
        );
      default:
        return const LinearGradient(
          colors: [Color(0xFF9B98E6), Color(0xFFC7CEEA)],
        );
    }
  }
}
