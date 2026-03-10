import 'package:supabase/supabase.dart';
import 'dart:io';
import 'dart:math';

void main() async {
  final supabase = SupabaseClient(
    'https://nenugkyvcewatuddrwvf.supabase.co',
    'sb_publishable_FJpEIk5UxIj73h-qrs99fA_1dlJO0LT',
  );

  final senderId = '00000000-0000-0000-0000-000000000000'; // Dummy ID

  try {
    var query = supabase
        .from('profiles')
        .select('id, full_name, interests, sexual_orientation, expectation, '
            'interested_in, last_active, bottles_received_today, is_active, receive_bottles, '
            'gender, birth_year, lat, lng, department')
        .neq('id', senderId)
        .eq('is_active', true)
        .eq('receive_bottles', true)
        .lt('bottles_received_today', 5)
        .gte(
            'last_active',
            DateTime.now()
                .subtract(const Duration(days: 30))
                .toIso8601String());

    final results = await query;
    print("RESULTS COUNT: \${results.length}");

    final senderProfile = {
      'interests': ['Music', 'Art'],
      'sexual_orientation': ['Straight'],
      'expectation': 'serious',
      'gender': 'female',
      'interested_in': 'men',
    };

    for (final recipient in results) {
      try {
        final score = _calculateMatchScore(senderProfile, recipient);
        print("User \${recipient['id']} matched OK with score: \$score.");
      } catch (e) {
        print("ERROR matching user \${recipient['id']}: \$e");
      }
    }
  } catch (e) {
    print("ERROR main query: \$e");
  }
}

int _calculateMatchScore(
  Map<String, dynamic> sender,
  Map<String, dynamic> recipient,
) {
  int score = 0;
  final _random = Random();

  // 1. Shared interests (0-50 points)
  final senderInterests = (sender['interests'] as List?)?.cast<String>() ?? [];
  final recipientInterests =
      (recipient['interests'] as List?)?.cast<String>() ?? [];

  final sharedInterests = senderInterests
      .where((interest) => recipientInterests.contains(interest))
      .length;
  score += (sharedInterests * 10).clamp(0, 50);

  // 2. Expectation alignment (0-30 points)
  final senderExpectation = sender['expectation'] as String? ?? '';
  final recipientExpectation = recipient['expectation'] as String? ?? '';

  if (senderExpectation == recipientExpectation) {
    score += 30;
  } else if (_areExpectationsCompatible(
      senderExpectation, recipientExpectation)) {
    score += 15;
  }

  // 3. Activity recency (0-20 points)
  final lastActive = recipient['last_active'] != null
      ? DateTime.parse(recipient['last_active'] as String)
      : DateTime.now().subtract(const Duration(days: 365));

  final hoursSinceActive = DateTime.now().difference(lastActive).inHours;
  if (hoursSinceActive < 24) {
    score += 20;
  } else if (hoursSinceActive < 72) {
    score += 10;
  } else if (hoursSinceActive < 168) {
    score += 5;
  }

  // 4. Balance factor (0-10 points)
  // Favor users who have received fewer bottles today
  final bottlesReceivedToday = recipient['bottles_received_today'] as int? ?? 0;
  if (bottlesReceivedToday == 0) {
    score += 10;
  } else if (bottlesReceivedToday == 1) {
    score += 5;
  }

  // 5. Randomization factor (0-10 points)
  // Add slight randomness to prevent always matching same users
  score += _random.nextInt(11);

  return score;
}

bool _areExpectationsCompatible(String exp1, String exp2) {
  // Define compatible expectations
  const compatiblePairs = {
    'serious': ['serious', 'long-term', 'relationship'],
    'casual': ['casual', 'friendship', 'fun', 'dating'],
    'friendship': ['friendship', 'casual', 'fun'],
    'long-term': ['long-term', 'serious', 'relationship'],
    'relationship': ['relationship', 'serious', 'long-term'],
  };

  return compatiblePairs[exp1.toLowerCase()]?.contains(exp2.toLowerCase()) ??
      false;
}
