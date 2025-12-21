import 'package:flutter/foundation.dart';
import 'database_service.dart';

class FeelingState {
  final int percent;
  final Map<String, dynamic>? unlockState;
  final String? title;

  const FeelingState({
    required this.percent,
    this.unlockState,
    this.title,
  });
}

class FeelingController extends ValueNotifier<FeelingState> {
  final DatabaseService _db = DatabaseService();

  FeelingController() : super(const FeelingState(percent: 0));

  void setInitial({required int percent, String? title}) {
    value = FeelingState(percent: percent, title: title);
  }

  void subscribe(String conversationId) {
    _db.subscribeConversation(conversationId).listen((row) {
      final p = (row['feeling_percent'] ?? value.percent) as int;
      final t = (row['title'] ?? value.title) as String?;
      value = FeelingState(
        percent: p,
        unlockState: _calculateUnlockState(p),
        title: t,
      );
    });
  }

  Future<void> increment(String conversationId, {int amount = 1}) async {
    final current = value.percent;
    if (current >= 100) return;

    int next = current + amount;
    if (next > 100) next = 100;

    await _db.updateFeelingPercent(conversationId, next);
  }

  Map<String, dynamic> _calculateUnlockState(int percent) {
    return {
      'basic_content': percent >= 25,
      'intermediate_content': percent >= 50,
      'sexy_questions': percent >= 75,
      'face_reveal': percent >= 100,
    };
  }
}
