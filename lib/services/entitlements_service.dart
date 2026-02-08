import 'package:supabase_flutter/supabase_flutter.dart' as sf;

class EntitlementsService {
  final sf.SupabaseClient _supabase;
  EntitlementsService({sf.SupabaseClient? supabase})
      : _supabase = supabase ?? sf.Supabase.instance.client;

  Future<String> getTier(String userId) async {
    try {
      // 1. Check Gender (Women get premium features for free)
      final profJson = await _supabase
          .from('profiles')
          .select('gender, tier')
          .eq('id', userId)
          .maybeSingle();
      
      if (profJson != null) {
        final gender = (profJson['gender'] as String?)?.toLowerCase() ?? '';
        if (gender == 'woman' || gender == 'female') {
          return 'premium';
        }
      }

      // 2. Check Entitlements table
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

      // 3. Fallback to profile tier
      return (profJson?['tier'] as String?) ?? 'free';
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

  Future<bool> isPremiumOrWoman(String userId) async {
    try {
      // 1. Check Tier
      final tier = await getTier(userId);
      if (tier == 'premium' || tier == 'elite') return true;

      // 2. Check Gender (Women get premium features for free)
      final prof = await _supabase
          .from('profiles')
          .select('gender')
          .eq('id', userId)
          .maybeSingle();
      
      if (prof != null) {
        final gender = (prof['gender'] as String?)?.toLowerCase() ?? '';
        return gender == 'woman' || gender == 'female';
      }
      
      return false;
    } catch (_) {
      return false;
    }
  }
}

