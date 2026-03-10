import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  print('Loading Env...');
  final envVars = await _loadEnv('.env');
  final url = envVars['SUPABASE_URL']!;
  final anonKey = envVars['SUPABASE_ANON_KEY']!;

  print('Connecting to Supabase...');
  await Supabase.initialize(url: url, anonKey: anonKey);
  final db = Supabase.instance.client;

  print('Testing Profiles for free users...');
  try {
    final limitRes = await db
        .from('profiles')
        .select('id, email, scrolls_count, daily_free_scrolls')
        .limit(3);
    print(limitRes);

    print('\nCalling use_scroll RPC directly for first user...');
    final rpcRes =
        await db.rpc('use_scroll', params: {'user_id': limitRes[0]['id']});
    print('RPC Result: $rpcRes');

    final afterRes = await db
        .from('profiles')
        .select('scrolls_count, daily_free_scrolls')
        .eq('id', limitRes[0]['id']);
    print('After RPC: $afterRes');
  } catch (e) {
    print('Error: $e');
  }

  exit(0);
}

Future<Map<String, String>> _loadEnv(String path) async {
  final file = File(path);
  final lines = await file.readAsLines();
  final varMap = <String, String>{};
  for (var line in lines) {
    if (line.trim().isEmpty || line.startsWith('#')) continue;
    final parts = line.split('=');
    if (parts.length >= 2) {
      final key = parts[0].trim();
      final value = parts.sublist(1).join('=').trim();
      varMap[key] = value;
    }
  }
  return varMap;
}
