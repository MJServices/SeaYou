import 'package:flutter/material.dart';
import '../utils/app_text_styles.dart';
import '../utils/app_colors.dart';
import '../widgets/warm_gradient_background.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import 'home_screen.dart';
import '../services/database_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/received_bottles_viewer.dart';
import 'dart:async';

class OutboxComposeScreen extends StatefulWidget {
  const OutboxComposeScreen({super.key});

  @override
  State<OutboxComposeScreen> createState() => _OutboxComposeScreenState();
}

class _OutboxComposeScreenState extends State<OutboxComposeScreen> {
  final _textController = TextEditingController();
  double _distance = 50;
  RangeValues _age = const RangeValues(21, 40);
  String _gender = 'everyone';
  bool _loading = false;
  final _formKey = GlobalKey<FormState>();
  Timer? _ageDebounce;
  Timer? _distanceDebounce;
  final FocusNode _messageFocus = FocusNode(debugLabel: 'message');
  final FocusNode _ageFocus = FocusNode(debugLabel: 'age');
  final FocusNode _distanceFocus = FocusNode(debugLabel: 'distance');
  final FocusNode _genderFocus = FocusNode(debugLabel: 'gender');

  bool _validate() {
    final gOk = ['everyone', 'male', 'female', 'nonbinary'].contains(_gender);
    final msgOk = _textController.text.trim().isNotEmpty;
    final ageOk = _age.start.round() <= _age.end.round() && _age.start >= 18 && _age.end <= 80;
    final distOk = _distance.round() >= 10 && _distance.round() <= 200;
    return gOk && msgOk && ageOk && distOk;
  }

  Future<void> _submit() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    if (!_validate()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fix the form errors')));
      return;
    }
    setState(() => _loading = true);
    try {
      final db = DatabaseService();
      final id = await db.createOutboxMessage(
        senderId: userId,
        text: _textController.text.trim(),
        minAge: _age.start.round(),
        maxAge: _age.end.round(),
        maxDistanceKm: _distance.round(),
        targetGender: _gender,
      );
      final assigned = id != null ? await db.triggerMatching(outboxId: id) : 0;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(id != null ? 'Message queued · $assigned recipients assigned' : 'Failed to queue message'),
          action: id != null
              ? SnackBarAction(
                  label: 'Inbox',
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceivedBottlesViewer()));
                  },
                )
              : null,
        ),
      );
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WarmGradientBackground(
        child: SafeArea(
          child: Stack(children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Form(
                key: _formKey,
                child: FocusTraversalGroup(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _loading ? null : () => Navigator.pop(context),
                  child: Icon(Icons.arrow_back, color: _loading ? AppColors.black.withValues(alpha: 0.3) : AppColors.black),
                ),
                const SizedBox(height: 24),
                const Text('Compose Anonymous Message', style: AppTextStyles.displayText),
                const SizedBox(height: 16),
                Semantics(
                  label: 'Message',
                  textField: true,
                  child: CustomTextField(hintText: 'Your message', controller: _textController, isActive: !_loading, focusNode: _messageFocus),
                ),
                const SizedBox(height: 16),
                const Text('Age range', style: AppTextStyles.bodyText),
                Semantics(
                  label: 'Age range selector',
                  slider: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: RangeSlider(
                      values: _age,
                      min: 18,
                      max: 80,
                      divisions: 62,
                      onChanged: _loading
                          ? null
                          : (v) {
                              _ageDebounce?.cancel();
                              _age = v;
                              _ageDebounce = Timer(const Duration(milliseconds: 120), () {
                                if (mounted) setState(() {});
                              });
                            },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Max distance (km): ${_distance.round()}', style: AppTextStyles.bodyText),
                Semantics(
                  label: 'Distance selector',
                  slider: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Slider(
                      value: _distance,
                      min: 10,
                      max: 200,
                      divisions: 190,
                      onChanged: _loading
                          ? null
                          : (v) {
                              _distanceDebounce?.cancel();
                              _distance = v;
                              _distanceDebounce = Timer(const Duration(milliseconds: 120), () {
                                if (mounted) setState(() {});
                              });
                            },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Semantics(
                  label: 'Target gender',
                  button: true,
                  child: DropdownButton<String>(
                    value: _gender,
                    items: const [
                      DropdownMenuItem(value: 'everyone', child: Text('Everyone')),
                      DropdownMenuItem(value: 'male', child: Text('Male')),
                      DropdownMenuItem(value: 'female', child: Text('Female')),
                      DropdownMenuItem(value: 'nonbinary', child: Text('Non-binary')),
                    ],
                    onChanged: _loading ? null : (v) => setState(() => _gender = v ?? 'everyone'),
                  ),
                ),
                const SizedBox(height: 24),
                Semantics(
                  label: 'Queue message',
                  button: true,
                  child: CustomButton(text: 'Queue Message', isActive: !_loading, onPressed: _submit),
                ),
              ]),
                ),
              ),
            ),
            if (_loading)
              Container(color: Colors.black.withValues(alpha: 0.1), child: const Center(child: CircularProgressIndicator())),
          ]),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _ageDebounce?.cancel();
    _distanceDebounce?.cancel();
    _messageFocus.dispose();
    _ageFocus.dispose();
    _distanceFocus.dispose();
    _genderFocus.dispose();
    super.dispose();
  }
}
