import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late String supabaseUrl;
  late String anonKey;
  setUpAll(() async {
    supabaseUrl = Platform.environment['TEST_SUPABASE_URL'] ?? '';
    anonKey = Platform.environment['TEST_SUPABASE_ANON_KEY'] ?? '';
    if (supabaseUrl.isNotEmpty && anonKey.isNotEmpty) {
      await Supabase.initialize(url: supabaseUrl, anonKey: anonKey);
    }
  });

  group('Storage policies and signed URLs (smoke)', () {
    test('Signed URL can be generated for face_photos', () async {
      if (supabaseUrl.isEmpty || anonKey.isEmpty) {
        return; // skipped
      }
      final client = Supabase.instance.client;
      final facePath = Platform.environment['TEST_FACE_OBJECT_PATH'] ?? '';
      expect(facePath.isNotEmpty, true);
      final signed = await client.storage.from('face_photos').createSignedUrl(facePath, 60);
      expect(signed.isNotEmpty, true);
    });
  });
}
