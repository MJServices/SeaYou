import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_service.dart';

/// PresenceService - Tracks user online status by updating last_active periodically
class PresenceService with WidgetsBindingObserver {
  static final PresenceService instance = PresenceService._internal();
  PresenceService._internal();

  final DatabaseService _db = DatabaseService();
  final SupabaseClient _supabase = Supabase.instance.client;
  Timer? _heartbeatTimer;
  bool _isInitialized = false;

  void init() {
    if (_isInitialized) return;
    _isInitialized = true;
    WidgetsBinding.instance.addObserver(this);
    _startHeartbeat();
    _updateActivity(); // Initial update
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopHeartbeat();
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
      debugPrint('📡 Presence: Updating last_active for $userId');
      await _db.updateLastActive(userId);
    }
  }
}
