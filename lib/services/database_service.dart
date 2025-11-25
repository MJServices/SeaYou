import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bottle.dart';

class DatabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Create a new profile
  Future<void> createProfile({
    required String userId,
    required String email,
    required String fullName,
    required int age,
    required String city,
    required String about,
    required List<String> sexualOrientation,
    required bool showOrientation,
    required String expectation,
    required String interestedIn,
    required List<String> interests,
    String? avatarUrl,
    String? language,
  }) async {
    try {
      debugPrint('Creating profile for user: $userId');
      debugPrint('Email: $email');
      debugPrint('Full Name: $fullName');
      debugPrint('Age: $age');
      debugPrint('City: $city');
      
      await _supabase.from('profiles').insert({
        'id': userId,
        'email': email,
        'full_name': fullName,
        'age': age,
        'city': city,
        'about': about,
        'sexual_orientation': sexualOrientation,
        'show_orientation': showOrientation,
        'expectation': expectation,
        'interested_in': interestedIn,
        'interests': interests,
        'avatar_url': avatarUrl,
        'language': language,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      
      debugPrint('Profile created successfully!');
    } catch (e) {
      debugPrint('Error creating profile: $e');
      debugPrint('Error type: ${e.runtimeType}');
      rethrow; // Re-throw to let the UI handle it
    }
  }

  // Update profile
  Future<void> updateProfile(String userId, Map<String, dynamic> data) async {
    await _supabase.from('profiles').update(data).eq('id', userId);
  }
  
  // Get profile
  Future<Map<String, dynamic>?> getProfile(String userId) async {
    final response = await _supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return response;
  }

  // Upload avatar
  Future<String?> uploadAvatar(String userId, File imageFile) async {
    try {
      final String fileExt = imageFile.path.split('.').last;
      final String path = '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      
      await _supabase.storage.from('avatars').upload(
        path,
        imageFile,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );
      
      final String publicUrl = _supabase.storage.from('avatars').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading avatar: $e');
      return null;
    }
  }

  // ==================== BOTTLE METHODS ====================

  // Get received bottles count
  Future<int> getReceivedBottlesCount(String userId) async {
    try {
      debugPrint('🔍 Getting received bottles count for: $userId');
      final response = await _supabase
          .from('received_bottles')
          .select('*')
          .eq('receiver_id', userId);
      
      final count = (response as List).length;
      debugPrint('✅ Found $count received bottles');
      return count;
    } catch (e) {
      debugPrint('❌ Error getting received bottles count: $e');
      return 0;
    }
  }

  // Get sent bottles count
  Future<int> getSentBottlesCount(String userId) async {
    try {
      final response = await _supabase
          .from('sent_bottles')
          .select('*')
          .eq('sender_id', userId);
      
      return (response as List).length;
    } catch (e) {
      debugPrint('Error getting sent bottles count: $e');
      return 0;
    }
  }

  // Get recent received bottles (limit for home page)
  Future<List<ReceivedBottle>> getRecentReceivedBottles(String userId, {int limit = 3}) async {
    try {
      final response = await _supabase
          .from('received_bottles')
          .select()
          .eq('receiver_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);
      
      return (response as List)
          .map((json) => ReceivedBottle.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting recent received bottles: $e');
      return [];
    }
  }

  // Get recent sent bottles (limit for home page)
  Future<List<SentBottle>> getRecentSentBottles(String userId, {int limit = 3}) async {
    try {
      final response = await _supabase
          .from('sent_bottles')
          .select()
          .eq('sender_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);
      
      return (response as List)
          .map((json) => SentBottle.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting recent sent bottles: $e');
      return [];
    }
  }

  // Get all received bottles
  Future<List<ReceivedBottle>> getAllReceivedBottles(String userId) async {
    try {
      final response = await _supabase
          .from('received_bottles')
          .select()
          .eq('receiver_id', userId)
          .order('created_at', ascending: false);
      
      return (response as List)
          .map((json) => ReceivedBottle.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting all received bottles: $e');
      return [];
    }
  }

  // Get all sent bottles
  Future<List<SentBottle>> getAllSentBottles(String userId) async {
    try {
      final response = await _supabase
          .from('sent_bottles')
          .select()
          .eq('sender_id', userId)
          .order('created_at', ascending: false);
      
      return (response as List)
          .map((json) => SentBottle.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting all sent bottles: $e');
      return [];
    }
  }

  // Mark bottle as read
  Future<void> markBottleAsRead(String bottleId) async {
    try {
      await _supabase
          .from('received_bottles')
          .update({'is_read': true, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', bottleId);
    } catch (e) {
      debugPrint('Error marking bottle as read: $e');
    }
  }

  // ==================== BOTTLE MATCHING METHODS ====================

  /// Create a new sent bottle
  Future<String?> createSentBottle({
    required String senderId,
    required String contentType,
    String? message,
    String? audioUrl,
    String? photoUrl,
    String? caption,
    String? mood,
  }) async {
    try {
      debugPrint('🔵 Creating sent bottle for sender: $senderId');
      debugPrint('🔵 Content type: $contentType');
      
      final response = await _supabase.from('sent_bottles').insert({
        'sender_id': senderId,
        'content_type': contentType,
        'message': message,
        'audio_url': audioUrl,
        'photo_url': photoUrl,
        'caption': caption,
        'mood': mood,
        'status': 'floating',
        'is_delivered': false,
        'has_reply': false,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).select().single();

      debugPrint('✅ Sent bottle created: ${response['id']}');
      return response['id'] as String;
    } catch (e) {
      debugPrint('❌ Error creating sent bottle: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      if (e is PostgrestException) {
        debugPrint('❌ Postgrest error code: ${e.code}');
        debugPrint('❌ Postgrest error message: ${e.message}');
        debugPrint('❌ Postgrest error details: ${e.details}');
      }
      rethrow; // Rethrow to see the actual error in the UI
    }
  }

  /// Create a received bottle for a recipient
  Future<String?> createReceivedBottle({
    required String bottleId,
    required String receiverId,
    required String senderId,
    required String contentType,
    String? message,
    String? audioUrl,
    String? photoUrl,
    String? caption,
    String? mood,
    int matchScore = 0,
  }) async {
    try {
      final response = await _supabase.from('received_bottles').insert({
        'receiver_id': receiverId,
        'sender_id': senderId,
        'content_type': contentType,
        'message': message,
        'audio_url': audioUrl,
        'photo_url': photoUrl,
        'caption': caption,
        'mood': mood,
        'is_read': false,
        'is_replied': false,
        'match_score': matchScore,
        'matched_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).select().single();

      debugPrint('✅ Received bottle created: ${response['id']}');
      return response['id'] as String;
    } catch (e) {
      debugPrint('❌ Error creating received bottle: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      if (e is PostgrestException) {
        debugPrint('❌ Postgrest error code: ${e.code}');
        debugPrint('❌ Postgrest error message: ${e.message}');
        debugPrint('❌ Postgrest error details: ${e.details}');
      }
      rethrow; // Don't silently fail - let the caller handle it
    }
  }

  /// Increment bottle counters for sender and receiver
  Future<void> incrementBottleCounters({
    required String senderId,
    required String receiverId,
  }) async {
    try {
      // Increment sender's sent count
      await _supabase.rpc('increment_bottles_sent', params: {
        'user_id': senderId,
      });

      // Increment receiver's received count
      await _supabase.rpc('increment_bottles_received', params: {
        'user_id': receiverId,
      });

      debugPrint('Bottle counters incremented');
    } catch (e) {
      debugPrint('Error incrementing bottle counters: $e');
    }
  }

  /// Update last active timestamp
  Future<void> updateLastActive(String userId) async {
    try {
      await _supabase.rpc('mark_profile_active', params: {
        'p_id': userId,
      });
    } catch (e) {
      debugPrint('Error updating last active: $e');
    }
  }

  // ==================== BLOCKING METHODS ====================

  /// Block a user
  Future<void> blockUser({
    required String blockerId,
    required String blockedId,
  }) async {
    try {
      await _supabase.from('user_blocks').insert({
        'blocker_id': blockerId,
        'blocked_id': blockedId,
        'created_at': DateTime.now().toIso8601String(),
      });
      debugPrint('User $blockedId blocked by $blockerId');
    } catch (e) {
      debugPrint('Error blocking user: $e');
      rethrow;
    }
  }

  /// Unblock a user
  Future<void> unblockUser({
    required String blockerId,
    required String blockedId,
  }) async {
    try {
      await _supabase
          .from('user_blocks')
          .delete()
          .eq('blocker_id', blockerId)
          .eq('blocked_id', blockedId);
      debugPrint('User $blockedId unblocked by $blockerId');
    } catch (e) {
      debugPrint('Error unblocking user: $e');
      rethrow;
    }
  }

  /// Get list of blocked users
  Future<List<String>> getBlockedUsers(String userId) async {
    try {
      final response = await _supabase
          .from('user_blocks')
          .select('blocked_id')
          .eq('blocker_id', userId);

      return (response as List)
          .map((item) => item['blocked_id'] as String)
          .toList();
    } catch (e) {
      debugPrint('Error getting blocked users: $e');
      return [];
    }
  }

  /// Check if user is blocked
  Future<bool> isUserBlocked({
    required String blockerId,
    required String blockedId,
  }) async {
    try {
      final response = await _supabase
          .from('user_blocks')
          .select('id')
          .eq('blocker_id', blockerId)
          .eq('blocked_id', blockedId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('Error checking if user is blocked: $e');
      return false;
    }
  }

  // ==================== USER PREFERENCES METHODS ====================

  /// Get user preferences
  Future<Map<String, dynamic>?> getUserPreferences(String userId) async {
    try {
      final response = await _supabase
          .from('user_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('Error getting user preferences: $e');
      return null;
    }
  }

  /// Create or update user preferences
  Future<void> upsertUserPreferences({
    required String userId,
    String? acceptFromGender,
    int? acceptFromAgeMin,
    int? acceptFromAgeMax,
    int? maxBottlesPerDay,
    bool? notifyOnBottleReceived,
    bool? notifyOnBottleRead,
  }) async {
    try {
      final data = <String, dynamic>{
        'user_id': userId,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (acceptFromGender != null) data['accept_from_gender'] = acceptFromGender;
      if (acceptFromAgeMin != null) data['accept_from_age_min'] = acceptFromAgeMin;
      if (acceptFromAgeMax != null) data['accept_from_age_max'] = acceptFromAgeMax;
      if (maxBottlesPerDay != null) data['max_bottles_per_day'] = maxBottlesPerDay;
      if (notifyOnBottleReceived != null) data['notify_on_bottle_received'] = notifyOnBottleReceived;
      if (notifyOnBottleRead != null) data['notify_on_bottle_read'] = notifyOnBottleRead;

      await _supabase.from('user_preferences').upsert(data);
      debugPrint('User preferences updated');
    } catch (e) {
      debugPrint('Error updating user preferences: $e');
      rethrow;
    }
  }
}
