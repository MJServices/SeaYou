import 'package:supabase_flutter/supabase_flutter.dart' as sf;
import 'package:flutter/foundation.dart';

class EntitlementsService {
  final sf.SupabaseClient _supabase;
  EntitlementsService({sf.SupabaseClient? supabase})
      : _supabase = supabase ?? sf.Supabase.instance.client;

  static final Map<String, bool> _isPremiumCache = {};

  static void setPremiumOrWomanCache(String userId, bool access) {
    _isPremiumCache[userId] = access;
  }

  static bool? isPremiumOrWomanSync(String userId) {
    return _isPremiumCache[userId];
  }

  static void clearCache() {
    _isPremiumCache.clear();
  }

  Future<String> getTier(String userId) async {
    try {
      // 1. Check Profiles table (including gender, tier, and is_premium)
      final profJson = await _supabase
          .from('profiles')
          .select('gender, tier, is_premium')
          .eq('id', userId)
          .maybeSingle();

      if (profJson != null) {
        final gender = (profJson['gender'] as String?)?.toLowerCase() ?? '';
        if (gender == 'woman' || gender == 'female' || gender == 'femme') {
          return 'premium';
        }
      }

      final profileIsPremium = profJson?['is_premium'] as bool? ?? false;
      final profileTier = profJson?['tier'] as String? ?? 'free';

      // 2. Check Entitlements table
      final rec = await _supabase
          .from('entitlements')
          .select('tier, expires_at')
          .eq('user_id', userId)
          .maybeSingle();
      if (rec != null) {
        final expires = rec['expires_at'] as String?;
        if (expires != null &&
            DateTime.tryParse(expires)?.isBefore(DateTime.now()) == true) {
          // Entitlement record exists but is expired → definitively no access.
          // Do NOT fall back to profiles.is_premium here; the expired record
          // is authoritative proof that the subscription ended.
          return 'free';
        }
        return rec['tier'] as String? ?? 'free';
      }

      // 3. No entitlements record found. Since women are handled in step 1,
      // any user reaching here is male/non-binary/unknown. Without an active
      // entitlement record, they must be free.
      if (profileIsPremium || profileTier != 'free') {
        // Self-healing: Reset stale database columns asynchronously to keep profiles sync'd
        _supabase.from('profiles').update({
          'is_premium': false,
          'tier': 'free',
        }).eq('id', userId).then((_) {
          debugPrint('🧹 Self-healed stale profiles premium status for user $userId');
        }).catchError((err) {
          debugPrint('Error cleaning up stale profiles columns: $err');
        });
      }
      return 'free';
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
      // getTier() already checks gender (women → 'premium') AND entitlements.
      // A single call is sufficient — avoids redundant DB queries.
      final tier = await getTier(userId);
      final result = tier == 'premium' || tier == 'elite';
      _isPremiumCache[userId] = result;
      return result;
    } catch (_) {
      return false;
    }
  }

  Future<void> grantEntitlement(
      String userId, String tier, String? purchaseToken) async {
    try {
      // 1. Update profiles table tier
      await _supabase.from('profiles').update({
        'tier': tier,
        'is_premium': tier == 'premium' || tier == 'elite'
      }).eq('id', userId);

      // 2. Upsert into entitlements table
      final now = DateTime.now();
      final expiresAt = now
          .add(const Duration(days: 30))
          .toIso8601String(); // Standard 30 days for testing

      await _supabase.from('entitlements').upsert({
        'user_id': userId,
        'tier': tier,
        'expires_at': expiresAt,
        'updated_at': now.toIso8601String(),
      });

      debugPrint('✅ Entitlement granted: $tier for user $userId');
    } catch (e) {
      debugPrint('❌ Error granting entitlement: $e');
      rethrow;
    }
  }
}
