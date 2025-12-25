import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bottle.dart';
import '../models/conversation.dart';
import '../models/chat_message.dart';
import '../models/intimate_question.dart';

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
    String? secretDesire,
    String? secretAudioUrl,
  }) async {
    try {
      debugPrint('Creating profile for user: $userId');
      debugPrint('Email: $email');
      debugPrint('Full Name: $fullName');
      debugPrint('Age: $age');
      debugPrint('City: $city');

      final response = await _supabase.from('profiles').upsert({
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
        'secret_desire': secretDesire,
        'secret_audio_url': secretAudioUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');
      
      debugPrint('✅ Profile upsert response: $response');

      debugPrint('Profile created successfully!');
    } catch (e) {
      debugPrint('Error creating profile: $e');
      debugPrint('Error type: ${e.runtimeType}');
      rethrow; // Re-throw to let the UI handle it
    }
  }


  // --- Freemium/Premium Logic ---

  /// Check if user can send a bottle today (Free: max 3). 
  Future<bool> canSendBottleToday(String userId, bool isPremium) async {
    if (isPremium) return true;

    try {
      final res = await _supabase.from('profiles').select('bottles_sent_today, last_bottle_sent_date').eq('id', userId).single();
      
      final int count = res['bottles_sent_today'] ?? 0;
      final String? dateStr = res['last_bottle_sent_date'];
      
      if (dateStr == null) return true;

      final lastDate = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now().toLocal();

      // Check if it's a new day
      if (lastDate.year != now.year || lastDate.month != now.month || lastDate.day != now.day) {
        // Reset counter
        await _supabase.from('profiles').update({
          'bottles_sent_today': 0,
          'last_bottle_sent_date': now.toIso8601String(),
        }).eq('id', userId);
        return true;
      }

      return count < 3;
    } catch (e) {
      debugPrint('Error checking bottle limit: $e');
      return true; // Fail safe
    }
  }

  /// Increment bottle sent count
  Future<void> incrementDailyBottles(String userId) async {
    try {
      final res = await _supabase.from('profiles').select('bottles_sent_today, last_bottle_sent_date').eq('id', userId).single();
      
      final int count = res['bottles_sent_today'] ?? 0;
      final String? dateStr = res['last_bottle_sent_date'];
      final now = DateTime.now();

      bool isNewDay = true;
      if (dateStr != null) {
        final lastDate = DateTime.parse(dateStr).toLocal();
        final nowLocal = now.toLocal();
        if (lastDate.year == nowLocal.year && lastDate.month == nowLocal.month && lastDate.day == nowLocal.day) {
          isNewDay = false;
        }
      }

      int newCount = isNewDay ? 1 : count + 1;
      
      await _supabase.from('profiles').update({
        'bottles_sent_today': newCount,
        'last_bottle_sent_date': now.toIso8601String(),
      }).eq('id', userId);

    } catch (e) {
      debugPrint('Error increments daily bottles: $e');
    }
  }

  /// Check if premium user reached weekly validation limit (3 messages)
  Future<bool> canSendMessageThisWeek(String userId) async {
    try {
      final res = await _supabase.from('profiles').select('messages_sent_week, last_message_sent_week_start').eq('id', userId).single();
      
      final int count = res['messages_sent_week'] ?? 0;
      final String? dateStr = res['last_message_sent_week_start'];
      final now = DateTime.now();

      // Check if week passed (7 days since start)
      if (dateStr == null || now.difference(DateTime.parse(dateStr)).inDays >= 7) {
        // Reset
        await _supabase.from('profiles').update({
          'messages_sent_week': 0,
          'last_message_sent_week_start': now.toIso8601String(),
        }).eq('id', userId);
        return true;
      }

      return count < 3;
    } catch (e) {
      debugPrint('Error checking weekly limit: $e');
      // If error (e.g. column missing), allow it to avoid blocking user completely until db updated
      return true;
    }
  }

  /// Increment weekly message count
  Future<void> incrementWeeklyMessages(String userId) async {
    try {
      final res = await _supabase.from('profiles').select('messages_sent_week, last_message_sent_week_start').eq('id', userId).single();
      
      final int count = res['messages_sent_week'] ?? 0;
      final String? dateStr = res['last_message_sent_week_start'];
      final now = DateTime.now();
      
      bool reset = false;
      if (dateStr == null || now.difference(DateTime.parse(dateStr)).inDays >= 7) {
        reset = true;
      }

      await _supabase.from('profiles').update({
        'messages_sent_week': reset ? 1 : count + 1,
        'last_message_sent_week_start': reset ? now.toIso8601String() : dateStr,
      }).eq('id', userId);
    } catch (e) {
      debugPrint('Error incrementing weekly messages: $e');
    }
  }

  // Update profile
  Future<void> updateProfile(String userId, Map<String, dynamic> data) async {
    await _supabase.from('profiles').update(data).eq('id', userId);
  }

  /// Update user bio/about
  Future<void> updateBio(String userId, String bio) async {
    try {
      await _supabase.from('profiles').update({
        'about': bio,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
      debugPrint('✅ Bio updated successfully');
    } catch (e) {
      debugPrint('❌ Error updating bio: $e');
      rethrow;
    }
  }

  /// Update sexual orientation
  Future<void> updateSexualOrientation(
    String userId,
    List<String> orientations,
    bool showOrientation,
  ) async {
    try {
      await _supabase.from('profiles').update({
        'sexual_orientation': orientations,
        'show_orientation': showOrientation,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
      debugPrint('✅ Sexual orientation updated successfully');
    } catch (e) {
      debugPrint('❌ Error updating sexual orientation: $e');
      rethrow;
    }
  }

  /// Update interests
  Future<void> updateInterests(String userId, List<String> interests) async {
    try {
      await _supabase.from('profiles').update({
        'interests': interests,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
      debugPrint('✅ Interests updated successfully');
    } catch (e) {
      debugPrint('❌ Error updating interests: $e');
      rethrow;
    }
  }

  /// Update full name
  Future<void> updateFullName(String userId, String fullName) async {
    try {
      await _supabase.from('profiles').update({
        'full_name': fullName,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
      debugPrint('✅ Full name updated successfully');
    } catch (e) {
      debugPrint('❌ Error updating full name: $e');
      rethrow;
    }
  }

  // Get profile with robust photo check
  Future<Map<String, dynamic>?> getProfile(String userId) async {
    final response = await _supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
        
    // Fallback: if avatar_url is missing, check profile_photos table
    if (response != null && (response['avatar_url'] == null || (response['avatar_url'] as String).isEmpty)) {
      try {
        final photos = await _supabase
          .from('profile_photos')
          .select('url')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1);
          
        if (photos != null && (photos as List).isNotEmpty) {
           final url = photos[0]['url'] as String;
           debugPrint('FOUND FALLBACK PHOTO: $url');
           // Inject into response so UI works immediately
           response['avatar_url'] = url;
           
           // Self-repair: update profiles table in background
           _supabase.from('profiles').update({'avatar_url': url}).eq('id', userId).then((_) {
             debugPrint('Self-repaired profiles.avatar_url');
           }).catchError((err) {
             debugPrint('Failed to self-repair profiles: $err');
           });
        }
      } catch (e) {
        debugPrint('Error fetching fallback photo: $e');
      }
    }
    
    return response;
  }

  // Upload avatar
  Future<String?> uploadAvatar(String userId, File imageFile) async {
    try {
      final String fileExt = imageFile.path.split('.').last;
      final String path =
          '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await _supabase.storage.from('avatars').upload(
            path,
            imageFile,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final String publicUrl =
          _supabase.storage.from('avatars').getPublicUrl(path);
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

  /// Get count of unreplied bottles (for homepage display)
  Future<int> getUnrepliedBottlesCount(String userId) async {
    try {
      debugPrint('🔍 Getting unreplied bottles count for: $userId');
      final response = await _supabase
          .from('received_bottles')
          .select('*')
          .eq('receiver_id', userId)
          .or('is_replied.eq.false,is_replied.is.null'); // Handle NULL as unreplied

      final count = (response as List).length;
      debugPrint('✅ Found $count unreplied bottles');
      return count;
    } catch (e) {
      debugPrint('❌ Error getting unreplied bottles count: $e');
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
  Future<List<ReceivedBottle>> getRecentReceivedBottles(String userId,
      {int limit = 3}) async {
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
  Future<List<SentBottle>> getRecentSentBottles(String userId,
      {int limit = 3}) async {
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

  // Get single received bottle
  Future<ReceivedBottle?> getReceivedBottle(String bottleId) async {
    try {
      final response = await _supabase
          .from('received_bottles')
          .select()
          .eq('id', bottleId)
          .maybeSingle();

      if (response == null) return null;
      return ReceivedBottle.fromJson(response);
    } catch (e) {
      debugPrint('Error getting received bottle: $e');
      return null;
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
      await _supabase.from('received_bottles').update({
        'is_read': true,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', bottleId);
    } catch (e) {
      debugPrint('Error marking bottle as read: $e');
    }
  }

  /// Mark a received bottle as replied
  Future<void> markBottleAsReplied(String bottleId) async {
    try {
      await _supabase.from('received_bottles').update({
        'is_replied': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', bottleId);
      debugPrint('✅ Bottle marked as replied: $bottleId');
    } catch (e) {
      debugPrint('❌ Error marking bottle as replied: $e');
      // Don't rethrow - this is non-critical
    }
  }

  /// Mark a sent bottle as replied (when recipient responds)
  Future<void> markSentBottleAsReplied(String sentBottleId) async {
    try {
      await _supabase.from('sent_bottles').update({
        'has_reply': true,
        'status': 'read',
        'read_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', sentBottleId);
      debugPrint('✅ Sent bottle marked as replied: $sentBottleId');
    } catch (e) {
      debugPrint('❌ Error marking sent bottle as replied: $e');
      // Don't rethrow - this is non-critical
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

      final response = await _supabase
          .from('sent_bottles')
          .insert({
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
          })
          .select()
          .single();

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
      final response = await _supabase
          .from('received_bottles')
          .insert({
            'receiver_id': receiverId,
            'sender_id': senderId,
            'sent_bottle_id': bottleId, // Link to original sent bottle
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
          })
          .select()
          .single();

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

  Future<void> insertImageMetadata({
    required String ownerId,
    required String bucket,
    required String path,
    required String url,
    String? contentType,
    int? size,
    int? width,
    int? height,
    String? entityType,
    String? entityId,
    String visibility = 'public',
  }) async {
    try {
      await _supabase.from('images').insert({
        'owner_id': ownerId,
        'bucket': bucket,
        'path': path,
        'url': url,
        'content_type': contentType,
        'size': size,
        'width': width,
        'height': height,
        'entity_type': entityType,
        'entity_id': entityId,
        'visibility': visibility,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error inserting image metadata: $e');
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
    bool? consentPhotoReveal,
    String? secretQuote,
    String? voiceClipUrl,
  }) async {
    try {
      final data = <String, dynamic>{
        'user_id': userId,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (acceptFromGender != null) {
        data['accept_from_gender'] = acceptFromGender;
      }
      if (acceptFromAgeMin != null) {
        data['accept_from_age_min'] = acceptFromAgeMin;
      }
      if (acceptFromAgeMax != null) {
        data['accept_from_age_max'] = acceptFromAgeMax;
      }
      if (maxBottlesPerDay != null) {
        data['max_bottles_per_day'] = maxBottlesPerDay;
      }
      if (notifyOnBottleReceived != null) {
        data['notify_on_bottle_received'] = notifyOnBottleReceived;
      }
      if (notifyOnBottleRead != null) {
        data['notify_on_bottle_read'] = notifyOnBottleRead;
      }
      if (consentPhotoReveal != null) {
        data['consent_photo_reveal'] = consentPhotoReveal;
      }
      if (secretQuote != null) {
        data['secret_quote'] = secretQuote;
      }
      if (voiceClipUrl != null) {
        data['voice_clip_url'] = voiceClipUrl;
      }

      await _supabase.from('user_preferences').upsert(data);
      debugPrint('User preferences updated');
    } catch (e) {
      debugPrint('Error updating user preferences: $e');
      rethrow;
    }
  }

  Future<String?> uploadVoiceClip(String userId, File clipFile) async {
    try {
      final String ext = clipFile.path.split('.').last;
      final String path =
          '$userId/voice_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _supabase.storage.from('voice_clips').upload(path, clipFile,
          fileOptions: const FileOptions(upsert: false));
      final url = _supabase.storage.from('voice_clips').getPublicUrl(path);
      return url;
    } catch (e) {
      debugPrint('Error uploading voice clip: $e');
      return null;
    }
  }

  // ==================== CONVERSATIONS & MESSAGES (STUBS) ====================

  Future<List<Conversation>> getUserConversations(String userId) async {
    try {
      final response = await _supabase
          .from('conversations')
          .select()
          .or('user_a_id.eq.$userId,user_b_id.eq.$userId')
          .order('updated_at', ascending: false);
      
      return (response as List)
          .map((json) => Conversation.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting conversations: $e');
      return [];
    }
  }

  Future<Conversation?> getConversation(String conversationId) async {
    try {
      final response = await _supabase
          .from('conversations')
          .select()
          .eq('id', conversationId)
          .maybeSingle();
      
      if (response == null) return null;
      return Conversation.fromJson(response);
    } catch (e) {
      debugPrint('Error getting conversation: $e');
      return null;
    }
  }

  /// Create a new conversation between two users
  Future<String> createConversation({
    required String userAId,
    required String userBId,
    String? title,
  }) async {
    try {
      // Check if conversation already exists between these users
      final existing = await _supabase
          .from('conversations')
          .select()
          .or('and(user_a_id.eq.$userAId,user_b_id.eq.$userBId),and(user_a_id.eq.$userBId,user_b_id.eq.$userAId)')
          .maybeSingle();
      
      if (existing != null) {
        debugPrint('Conversation already exists: ${existing['id']}');
        return existing['id'] as String;
      }

      // Create new conversation
      final response = await _supabase
          .from('conversations')
          .insert({
            'user_a_id': userAId,
            'user_b_id': userBId,
            'title': title,
            'feeling_percent': 0,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      
      debugPrint('✅ Conversation created: ${response['id']}');
      return response['id'] as String;
    } catch (e) {
      debugPrint('❌ Error creating conversation: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      if (e is PostgrestException) {
        debugPrint('❌ PostgreSQL error code: ${e.code}');
        debugPrint('❌ PostgreSQL error message: ${e.message}');
        debugPrint('❌ PostgreSQL error details: ${e.details}');
        debugPrint('❌ PostgreSQL error hint: ${e.hint}');
      }
      rethrow; // Propagate error to caller so it's visible in UI
    }
  }

  Future<void> renameConversation({
    required String conversationId,
    required String title,
  }) async {
    try {
      await _supabase.from('conversations').update({
        'title': title,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', conversationId);
    } catch (e) {
      debugPrint('Error renaming conversation: $e');
    }
  }

  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String type,
    String? text,
    String? mediaUrl,
    int? duration,
    String? mood,
  }) async {
    try {
      final Map<String, dynamic> messageData = {
        'conversation_id': conversationId,
        'sender_id': senderId,
        'type': type,
        'text': text,
        'media_url': mediaUrl,
        'created_at': DateTime.now().toIso8601String(),
        'is_read': false,
        'mood': mood,
      };

      // Only include duration if it's not null, preventing errors if column doesn't exist yet
      if (duration != null) {
        messageData['duration'] = duration;
      }

      await _supabase.from('messages').insert(messageData);

      // Update conversation last message
      String lastMsg = text ?? (type == 'image' ? 'Picture' : 'Voice Message');
      await _supabase.from('conversations').update({
        'last_message': lastMsg,
        'last_message_time': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', conversationId);
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  Future<void> sendQuestion({
    required String conversationId,
    required String senderId,
    required String text,
    required String qaGroupId,
  }) async {
    try {
      await _supabase.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': senderId,
        'type': 'text',
        'text': text,
        'qa_group_id': qaGroupId,
        'is_question': true,
        'feeling_delta': 2,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error sending question: $e');
    }
  }

  Future<void> sendAnswer({
    required String conversationId,
    required String senderId,
    required String text,
    required String qaGroupId,
  }) async {
    try {
      await _supabase.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': senderId,
        'type': 'text',
        'text': text,
        'qa_group_id': qaGroupId,
        'is_answer': true,
        'feeling_delta': 3,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error sending answer: $e');
    }
  }

  Future<String?> createOutboxMessage({
    required String senderId,
    required String text,
    int minAge = 18,
    int maxAge = 100,
    int maxDistanceKm = 100,
    String targetGender = 'everyone',
  }) async {
    try {
      final rec = await _supabase
          .from('messages_outbox')
          .insert({
            'sender_id': senderId,
            'text': text,
            'min_age': minAge,
            'max_age': maxAge,
            'max_distance_km': maxDistanceKm,
            'target_gender': targetGender,
          })
          .select()
          .single();
      return rec['id'] as String?;
    } catch (e) {
      debugPrint('Error creating outbox message: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> listMatchesForUser(String userId) async {
    try {
      final res = await _supabase
          .from('matches')
          .select()
          .eq('recipient_id', userId)
          .order('assigned_at', ascending: false);
      return (res as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error listing matches: $e');
      return [];
    }
  }

  Future<int> triggerMatching({String? outboxId}) async {
    try {
      if (outboxId != null) {
        final res = await _supabase
            .rpc('process_outbox_one', params: {'outbox_id': outboxId});
        return (res as int?) ?? 0;
      } else {
        final res = await _supabase.rpc('process_outbox');
        return (res as int?) ?? 0;
      }
    } catch (e) {
      debugPrint('Error triggering matching: $e');
      return 0;
    }
  }

  Future<List<ChatMessage>> getMessages(String conversationId) async {
    try {
      final res = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);
      
      final currentUserId = _supabase.auth.currentUser?.id;
      return (res as List)
          .map((json) => ChatMessage.fromJson(json, currentUserId: currentUserId))
          .toList();
    } catch (e) {
      debugPrint('Error loading messages: $e');
      return [];
    }
  }

  Future<void> updateFeelingPercent(String conversationId, int newPercent) async {
    try {
      await _supabase.from('conversations').update({
        'feeling_percent': newPercent,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', conversationId);
    } catch (e) {
      debugPrint('Error updating feeling percent: $e');
    }
  }

  /// Calculate feeling points based on message content
  int calculateFeelingPoints({
    required String type,
    String? text,
    int? duration,
  }) {
    switch (type) {
      case 'text':
        final length = text?.length ?? 0;
        if (length < 20) return 1;   // Short message (was 1, keep same)
        if (length < 100) return 1;  // Medium message (was 2, now 1)
        return 2;                    // Long, thoughtful message (was 3, now 2)
      
      case 'voice':
        final seconds = duration ?? 0;
        if (seconds < 10) return 2;  // Short voice (was 3, now 2)
        if (seconds < 30) return 2;  // Medium voice (was 4, now 2)
        return 3;                    // Long voice message (was 5, now 3)
      
      case 'image':
        final captionLength = text?.length ?? 0;
        if (captionLength < 20) return 1;  // Image without caption (was 2, now 1)
        return 2;                          // Image with caption (was 4, now 2)
      
      default:
        return 1;
    }
  }

  /// Check if user has already answered intimate questions
  Future<bool> hasAnsweredIntimateQuestions({
    required String conversationId,
    required String userId,
  }) async {
    try {
      final response = await _supabase
          .from('intimate_questions')
          .select('id')
          .eq('conversation_id', conversationId)
          .eq('user_id', userId)
          .maybeSingle();
      return response != null;
    } catch (e) {
      debugPrint('Error checking intimate questions: $e');
      return false;
    }
  }

  /// Save intimate questions (one time only)
  Future<void> saveIntimateQuestions({
    required String conversationId,
    required String userId,
    String? question1,
    String? question2,
    String? question3,
  }) async {
    try {
      await _supabase.from('intimate_questions').insert({
        'conversation_id': conversationId,
        'user_id': userId,
        'question_1': question1,
        'question_2': question2,
        'question_3': question3,
      });
      debugPrint('✅ Intimate questions saved');
    } catch (e) {
      debugPrint('❌ Error saving intimate questions: $e');
      rethrow;
    }
  }

  /// Get intimate questions for a conversation
  Future<List<IntimateQuestion>> getIntimateQuestions(String conversationId) async {
    try {
      final response = await _supabase
          .from('intimate_questions')
          .select()
          .eq('conversation_id', conversationId);
      
      return (response as List)
          .map((json) => IntimateQuestion.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting intimate questions: $e');
      return [];
    }
  }

  Stream<Map<String, dynamic>> subscribeMessages(String conversationId) {
    try {
      final controller = StreamController<Map<String, dynamic>>();
      final channel = _supabase.channel('messages_$conversationId');
      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            callback: (payload) {
              final newRec = payload.newRecord;
              if (newRec['conversation_id'] == conversationId) {
                controller.add(newRec.cast<String, dynamic>());
              }
            },
          )
          .subscribe();

      return controller.stream;
    } catch (e) {
      debugPrint('Error subscribing to messages: $e');
      return const Stream.empty();
    }
  }

  Stream<Map<String, dynamic>> subscribeConversation(String conversationId) {
    try {
      final controller = StreamController<Map<String, dynamic>>();
      final channel = _supabase.channel('conversations_$conversationId');
      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'conversations',
            callback: (payload) {
              final newRec = payload.newRecord;
              if (newRec['id'] == conversationId) {
                controller.add(newRec.cast<String, dynamic>());
              }
            },
          )
          .subscribe();

      return controller.stream;
    } catch (e) {
      debugPrint('Error subscribing to conversation: $e');
      return const Stream.empty();
    }
  }

  // ==================== TIERS ====================

  Future<String> getUserTier(String userId) async {
    try {
      final rec = await _supabase
          .from('profiles')
          .select('tier')
          .eq('id', userId)
          .maybeSingle();
      final tier = (rec?['tier'] as String?) ?? 'free';
      return tier;
    } catch (e) {
      debugPrint('Error getting user tier: $e');
      return 'free';
    }
  }

  // ==================== SECRET SOULS (MIXED CONTENT) ====================

  /// Fetch Secret Souls content (Manual Aggregation)
  Future<List<Map<String, dynamic>>> getSecretSoulsContent({
    String? contentType, // null = all, 'photo', 'audio', 'quote'
    required int page,
    int pageSize = 20,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      List<Map<String, dynamic>> items = [];

      // 1. Fetch Quotes (if all or quote)
      if (contentType == null || contentType == 'quote') {
        final quotes = await _supabase
            .from('profiles')
            .select('id, secret_desire, created_at')
            .not('secret_desire', 'is', null)
            .neq('id', currentUserId ?? '')
            // We can't implement perfect pagination with mixed sources easily without a backend View.
            // But we can approximate by fetching a chunk.
            .order('created_at', ascending: false)
            .limit(pageSize);

        items.addAll((quotes as List).map((q) => {
          'id': q['id'], // Use user_id as content ID for profile-based content
          'user_id': q['id'],
          'content_type': 'quote',
          'quote_text': q['secret_desire'],
          'created_at': q['created_at'],
        }));
      }

      // 2. Fetch Audio (if all or audio)
      if (contentType == null || contentType == 'audio') {
        final audios = await _supabase
            .from('profiles')
            .select('id, secret_audio_url, created_at')
            .not('secret_audio_url', 'is', null)
            .neq('id', currentUserId ?? '')
            .order('created_at', ascending: false)
            .limit(pageSize);

        items.addAll((audios as List).map((a) => {
          'id': a['id'], 
          'user_id': a['id'],
          'content_type': 'audio',
          'audio_url': a['secret_audio_url'],
          'created_at': a['created_at'],
        }));
      }

      // 3. Fetch Photos (if all or photo)
      if (contentType == null || contentType == 'photo') {
        final photos = await _supabase
            .from('profile_photos')
            .select('id, user_id, url, created_at')
            // Temporarily ignore show_in_secret_souls filter to debug missing photos
            //.eq('show_in_secret_souls', true) 
            .neq('user_id', currentUserId ?? '')
            .order('created_at', ascending: false)
            .limit(pageSize);

        items.addAll((photos as List).map((p) => {
          'id': p['id'],
          'user_id': p['user_id'],
          'content_type': 'photo',
          'photo_url': p['url'],
          'created_at': p['created_at'],
        }));
      }

      // Shuffle or Sort
      // Simple sort by created_at desc
      items.sort((a, b) {
        final da = DateTime.tryParse(a['created_at'].toString()) ?? DateTime.now();
        final db = DateTime.tryParse(b['created_at'].toString()) ?? DateTime.now();
        return db.compareTo(da);
      });

      // Simple client-side pagination simulation
      // Since we fetch 'pageSize' of EACH type, we have enough items.
      // If we page through this, we might see duplicates if we don't track offsets per type.
      // However, for a user "Exploring", seeing a mix is more important than strict unique pagination order.
      // We'll return the whole mixed batch for now as the "page".
      
      return items;
    } catch (e) {
      debugPrint('Error loading Secret Souls content (manual): $e');
      return [];
    }
  }

  /// Start anonymous conversation from Secret Souls content
  Future<String?> startSecretSoulsConversation({
    required String contentId,
    required String requesterId,
    required String ownerId,
    String? initialMessage,
  }) async {
    debugPrint('--- startSecretSoulsConversation ---');
    debugPrint('requesterId: $requesterId');
    debugPrint('ownerId: $ownerId');

    try {
      // 1. Check for existing conversation
      debugPrint('Checking for existing conversation...');
      final existing = await _supabase
          .from('conversations')
          .select('id')
          .eq('user_a_id', requesterId)
          .eq('user_b_id', ownerId)
          .maybeSingle();

      if (existing != null) {
        debugPrint('Found existing conversation: ${existing['id']}');
        return existing['id'] as String;
      }

      debugPrint('No existing conversation found. Creating new one...');
      
      // 2. Create conversation with correct schema
      final response = await _supabase.from('conversations').insert({
        'user_a_id': requesterId,
        'user_b_id': ownerId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'title': 'Secret Souls',
        'mask_a': 'Secret',
        'mask_b': 'Soul',
      }).select('id').single();

      final convId = response['id'] as String;
      debugPrint('Created conversation: $convId');

      // Send initial message if provided
      if (initialMessage != null && initialMessage.isNotEmpty) {
        debugPrint('Sending initial message: $initialMessage');
        await sendMessage(
          conversationId: convId,
          senderId: requesterId,
          type: 'text',
          text: initialMessage,
        );
      }

      // Send notification
      await _supabase.from('notifications').insert({
        'user_id': ownerId,
        'type': 'secret_souls_message',
        'title': 'New Secret Souls Message',
        'message': 'Someone wants to connect with you anonymously',
        'data': {'conversation_id': convId, 'content_id': contentId},
        'created_at': DateTime.now().toIso8601String(),
      });

      return convId;
    } catch (e) {
      debugPrint('ERROR starting Secret Souls conversation: $e');
      return null;
    }
  }

  // Legacy method - kept for backward compatibility
  Future<List<Map<String, dynamic>>> getSecretSoulsPhotos({
    required int page,
    int pageSize = 30,
  }) async {
    return getSecretSoulsContent(
      contentType: 'photo',
      page: page,
      pageSize: pageSize,
    );
  }

  Future<void> setPhotoGalleryVisibility({
    required String photoId,
    required bool visible,
  }) async {
    try {
      await _supabase
          .from('profile_photos')
          .update({'show_in_secret_souls': visible}).eq('id', photoId);
    } catch (e) {
      debugPrint('Error updating photo visibility: $e');
    }
  }

  Future<void> setPhotoFlags({
    required String photoId,
    bool? isFirstFace,
    bool? isVisibleInSecretSouls,
    bool? isHidden,
    num? aiFaceScore,
  }) async {
    try {
      final Map<String, dynamic> update = {};
      if (isFirstFace != null) update['is_first_face_photo'] = isFirstFace;
      if (isVisibleInSecretSouls != null) {
        update['is_visible_in_secret_souls'] = isVisibleInSecretSouls;
        update['show_in_secret_souls'] =
            isVisibleInSecretSouls; // backward compat
      }
      if (isHidden != null) update['is_hidden'] = isHidden;
      if (aiFaceScore != null) update['ai_face_score'] = aiFaceScore;
      if (update.isEmpty) return;
      await _supabase.from('profile_photos').update(update).eq('id', photoId);
    } catch (e) {
      debugPrint('Error setting photo flags: $e');
    }
  }

  Future<String?> uploadGalleryPhoto(String userId, File imageFile) async {
    try {
      final String ext = imageFile.path.split('.').last;
      final String path =
          '$userId/gallery_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _supabase.storage.from('face_photos').upload(path, imageFile,
          fileOptions: const FileOptions(upsert: false));
      final url = _supabase.storage.from('face_photos').getPublicUrl(path);
      await _supabase.from('profile_photos').insert({
        'user_id': userId,
        'url': url,
        'is_face': false,
        'show_in_secret_souls': false,
        'created_at': DateTime.now().toIso8601String(),
      });
      return url;
    } catch (e) {
      debugPrint('Error uploading gallery photo: $e');
      return null;
    }
  }

  Future<String?> uploadFacePhoto(String userId, File imageFile) async {
    try {
      final String ext = imageFile.path.split('.').last;
      final String path =
          '$userId/face_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _supabase.storage.from('face_photos').upload(path, imageFile,
          fileOptions: const FileOptions(upsert: false));
      final signedUrl =
          _supabase.storage.from('face_photos').getPublicUrl(path);
      await _supabase
          .from('profiles')
          .update({'face_photo_url': signedUrl}).eq('id', userId);
      return signedUrl;
    } catch (e) {
      debugPrint('Error uploading face photo: $e');
      return null;
    }
  }

  Future<Map<String, String>?> uploadFirstFacePhotoAndInsert({
    required String userId,
    required File imageFile,
  }) async {
    try {
      debugPrint('Starting uploadFirstFacePhotoAndInsert for user: $userId');
      final String ext = imageFile.path.split('.').last;
      final String path =
          '$userId/face_${DateTime.now().millisecondsSinceEpoch}.$ext';
      
      debugPrint('Uploading to storage: $path');
      await _supabase.storage.from('face_photos').upload(path, imageFile,
          fileOptions: const FileOptions(upsert: false));
          
      final publicUrl =
          _supabase.storage.from('face_photos').getPublicUrl(path);
      debugPrint('Upload success. Public URL: $publicUrl');
      
      debugPrint('Inserting into profile_photos...');
      final rec = await _supabase
          .from('profile_photos')
          .insert({
            'user_id': userId,
            'url': publicUrl,
            'is_face': true,
            'is_first_face_photo': false,
            'show_in_secret_souls': false,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      debugPrint('Inserted into profile_photos. Record ID: ${rec['id']}');

      debugPrint('Updating profiles table...');
      await _supabase
          .from('profiles')
          .update({'avatar_url': publicUrl}).eq('id', userId);
      debugPrint('Profiles table updated.');

      return {
        'photo_id': rec['id'] as String,
        'url': publicUrl,
      };
    } catch (e) {
      debugPrint('ERROR in uploadFirstFacePhotoAndInsert: $e');
      return null;
    }
  }

  /// Delete a photo from storage and database
  Future<void> deletePhoto({
    required String photoId,
    required String userId,
    required String photoUrl,
  }) async {
    try {
      // 1. Delete from storage if it's hosted by us
      // We need to parse the path from the URL
      // Example URL: .../storage/v1/object/public/gallery_photos/USERID/gallery_TIMESTAMP.jpg
      
      // Basic check if it's a supabase URL
      if (photoUrl.contains('supabase')) {
        final uri = Uri.parse(photoUrl);
        // Extract path after /public/
        // This logic depends on the exact URL structure
        // A safer way: if we stored the 'path' in the DB, we could use that.
        // But we didn't store 'path' in profile_photos, only 'url'.
        // So we'll try to extract the filename relative to the bucket.
        
        String? extractPath(String fullUrl, String bucketObj) {
            final split = fullUrl.split('$bucketObj/');
            if (split.length > 1) return split[1];
            return null;
        }

        String? path;
        String? bucket;

        if (photoUrl.contains('/gallery_photos/')) {
           bucket = 'gallery_photos';
           path = extractPath(photoUrl, 'gallery_photos');
        } else if (photoUrl.contains('/face_photos/')) {
           bucket = 'face_photos';
           path = extractPath(photoUrl, 'face_photos');
        }

        if (bucket != null && path != null) {
            await _supabase.storage.from(bucket).remove([path]);
        }
      }

      // 2. Delete from database
      await _supabase.from('profile_photos').delete().eq('id', photoId);
      
    } catch (e) {
      debugPrint('Error deleting photo: $e');
      rethrow;
    }
  }

  /// Set a photo as the Main Photo (avatar)
  Future<void> setMainPhoto({
    required String userId,
    required String photoUrl,
    required String photoId,
  }) async {
    try {
      // 1. Update profiles table
      await _supabase.from('profiles').update({
        'avatar_url': photoUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
      
      // 2. Optionally verify consistency in profile_photos 
      // (e.g., if we had an is_main flag, we would toggle it here)
      
    } catch (e) {
      debugPrint('Error setting main photo: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> listUserPhotos(String userId) async {
    try {
      final res = await _supabase
          .from('profile_photos')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (res as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error listing user photos: $e');
      return [];
    }
  }

  // ==================== FANTASIES ====================

  Future<String?> createFantasy(String userId, String text) async {
    try {
      final rec = await _supabase
          .from('fantasies')
          .insert({
            'user_id': userId,
            'text': text,
            'is_active': true,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      return rec['id'] as String?;
    } catch (e) {
      debugPrint('Error creating fantasy: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> listFantasies({
    required int page,
    int pageSize = 30,
  }) async {
    try {
      final from = page * pageSize;
      final to = from + pageSize - 1;
      final response = await _supabase
          .from('fantasies')
          .select()
          .eq('is_active', true)
          .range(from, to)
          .order('created_at', ascending: false);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error listing fantasies: $e');
      return [];
    }
  }

  Future<void> reportFantasy({
    required String fantasyId,
    required String reporterId,
    required String reason,
  }) async {
    try {
      await _supabase.from('fantasy_reports').insert({
        'fantasy_id': fantasyId,
        'reporter_id': reporterId,
        'reason': reason,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error reporting fantasy: $e');
    }
  }

  // ==================== ELITE ANONYMOUS DM ====================

  Future<String?> startAnonymousFantasyConversation({
    required String fantasyId,
    required String requesterId,
    required String ownerId,
  }) async {
    try {
      final rec = await _supabase
          .from('conversations')
          .insert({
            'user_a_id': requesterId,
            'user_b_id': ownerId,
            'title': 'Anonymous fantasy',
            'is_anonymous_elite': true,
            'fantasy_id': fantasyId,
            'mask_a': 'Voyager',
            'mask_b': 'Muse',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      return rec['id'] as String?;
    } catch (e) {
      debugPrint('Error starting anonymous fantasy conversation: $e');
      return null;
    }
  }

  Future<void> sendMessageAnonymous({
    required String conversationId,
    required String senderId,
    required String text,
  }) async {
    await sendMessage(
      conversationId: conversationId,
      senderId: senderId,
      type: 'text',
      text: text,
    );
  }

}
