import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  test('Check User Database State', () async {
    await dotenv.load(fileName: '.env');

    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_KEY'] ?? '',
    );

    final supabase = Supabase.instance.client;

    // We need an auth context. Maybe easier to just print profiles
    final authResp = await supabase.auth.signInWithPassword(
      email: 'test@example.com', // Need email...
      password: 'test',
    );
    print('SIGNED IN');
  });
}
