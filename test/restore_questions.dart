import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  test('Seed Questions', () async {
    await dotenv.load(fileName: '.env');

    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    );
    final supabase = Supabase.instance.client;

    try {
      await supabase.from('naughty_questions').upsert([
        {
          'id': 1,
          'category': 'Sweet',
          'label': 'Sweet question',
          'question_text': 'If you could describe a "perfect atmosphere," what would it be?',
          'display_order': 1
        },
        {
          'id': 2,
          'category': 'Daring',
          'label': 'Daring question',
          'question_text': 'If I whisper something in your ear, would you prefer it to be sweet... or definitely not innocent?',
          'display_order': 2
        },
        {
          'id': 3,
          'category': 'Naughty',
          'label': 'Naughty question',
          'question_text': 'What can a partner do to leave you completely speechless?',
          'display_order': 3
        }
      ]);
      print('Questions restored successfully!');
    } catch (e) {
      print("Error restoring questions: $e");
    }
  });
}

