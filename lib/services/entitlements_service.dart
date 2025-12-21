import 'package:supabase_flutter/supabase_flutter.dart' as sf;

class EntitlementsService {
  final sf.SupabaseClient _supabase;
  EntitlementsService({sf.SupabaseClient? supabase})
      : _supabase = supabase ?? sf.Supabase.instance.client;

  Future<String> getTier(String userId) async {
    try {
      final rec = await _supabase
          .from('entitlements')
          .select('tier, expires_at')
          .eq('user_id', userId)
          .maybeSingle();
      if (rec != null) {
        final expires = rec['expires_at'] as String?;
        if (expires != null && DateTime.tryParse(expires)?.isBefore(DateTime.now()) == true) {
          return 'free';
        }
        return rec['tier'] as String? ?? 'free';
      }
      final prof = await _supabase
          .from('profiles')
          .select('tier')
          .eq('id', userId)
          .maybeSingle();
      return (prof?['tier'] as String?) ?? 'free';
    } catch (_) {
      return 'free';
    }
  }

  Future<bool> isPremium(String userId) async {
    final t = await getTier(userId);
    return t == 'premium' || t == 'elite';
  }

  Future<bool> isElite(String userId) async {
    final t = await getTier(userId);
    return t == 'elite';
  }
}

