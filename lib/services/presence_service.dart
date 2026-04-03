import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_service.dart';
import '../main.dart';
import '../screens/splash_screen.dart';
import 'package:flutter/material.dart';

/// PresenceService - Tracks user online status by updating last_active periodically
class PresenceService with WidgetsBindingObserver {
  static final PresenceService instance = PresenceService._internal();
  PresenceService._internal();

  final DatabaseService _db = DatabaseService();
  final SupabaseClient _supabase = Supabase.instance.client;
  Timer? _heartbeatTimer;
  StreamSubscription<Map<String, dynamic>?>? _blockedCheckSub;
  bool _isInitialized = false;

  void init() {
    if (_isInitialized) return;
    _isInitialized = true;
    WidgetsBinding.instance.addObserver(this);
    _startHeartbeat();
    _updateActivity(); // Initial update
    _startBlockedCheck();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopHeartbeat();
    _stopBlockedCheck();
    _isInitialized = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startHeartbeat();
      _updateActivity();
    } else {
      _stopHeartbeat();
    }
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    // Update every 1 minute while app is in foreground
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updateActivity();
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _updateActivity() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) {
      debugPrint('📡 Presence: Updating last_active and checking status for $userId');
      
      // 1. Update activity
      await _db.updateLastActive(userId);

      // 2. Explicitly check block status as a fallback for the Realtime stream
      try {
        final res = await _supabase
            .from('profiles')
            .select('is_blocked')
            .eq('id', userId)
            .maybeSingle();
            
        if (res != null && res['is_blocked'] == true) {
          debugPrint('🚫 Presence (Heartbeat): USER IS BLOCKED! Triggering logout.');
          _handleBlockedUser();
        }
      } catch (e) {
        debugPrint('⚠️ Presence: Status check failed: $e');
      }
    }
  }

  void _startBlockedCheck() {
    _stopBlockedCheck();
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    debugPrint('🛡️ Presence: Starting blocked status check for $userId');
    _blockedCheckSub = _db.profileStream(userId).listen((profile) {
      if (profile != null && profile['is_blocked'] == true) {
        debugPrint('🚫 Presence: USER IS BLOCKED! Triggering immediate logout.');
        _handleBlockedUser();
      }
    });
  }

  void _stopBlockedCheck() {
    _blockedCheckSub?.cancel();
    _blockedCheckSub = null;
  }

  Future<void> _handleBlockedUser() async {
    try {
      // 1. Sign out
      await _supabase.auth.signOut();
      
      // 2. Clear local cache
      DatabaseService.clearCache();
      
      // 3. Stop services
      _stopHeartbeat();
      _stopBlockedCheck();

      // 4. Redirect to Splash (Login) screen
      // We use main.dart's navKey for top-level navigation from a service
      
      if (navKey.currentState != null) {
        navKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SplashScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('❌ Error handling blocked user logout: $e');
    }
  }
}
