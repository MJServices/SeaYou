import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bottle.dart';
import '../models/conversation.dart';
import '../models/chat_message.dart';
import '../models/intimate_question.dart';
import '../models/naughty_question.dart';

class DatabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Local broadcast for profile updates to ensure high reactivity
  static final StreamController<Map<String, dynamic>> _profileUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get profileUpdateBroadcast =>
      _profileUpdateController.stream;

  // Create a new profile
  Future<void> createProfile({
    required String userId,
    required String email,
    required String fullName,
    required int age,
    required int birthYear,
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
    String? secretQuote,
    String? secretAudioUrl,
    String? gender,
    String? department,
    String? tier,
    bool? isPremium,
  }) async {
    try {
      debugPrint('Creating profile for user: $userId');
      debugPrint('Email: $email');
      debugPrint('Full Name: $fullName');
      debugPrint('Age: $age');
      debugPrint('Birth Year: $birthYear');
      debugPrint('City: $city');

      final response = await _supabase.from('profiles').upsert({
        'id': userId,
        'email': email,
        'full_name': fullName,
        'age': age,
        'birth_year': birthYear,
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
        'secret_quote': secretQuote,
        'secret_audio_url': secretAudioUrl,
        'gender': gender,
        'department': department,
        'tier': tier,
        'is_premium': isPremium,
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

  // Submit help center request to database instead of email
  Future<void> submitSupportRequest({
    required String userId,
    required String email,
    required String subject,
    required String message,
  }) async {
    try {
      await _supabase.from('support_requests').insert({
        'user_id': userId,
        'email': email,
        'subject': subject,
        'message': message,
        'status': 'open',
      });
      debugPrint('✅ Support request submitted successfully');
    } catch (e) {
      debugPrint('❌ Error submitting support request: $e');
      rethrow;
    }
  }

  // --- Freemium/Premium Logic ---

  /// Check if user has available scrolls (Premium daily free or purchased)
  Future<bool> hasAvailableScrolls(String userId) async {
    try {
      await _refreshDailyScrolls(userId);
      
      final res = await _supabase
          .from('profiles')
          .select('daily_free_scrolls, scrolls_count')
          .eq('id', userId)
          .single();

      final int dailyFree = res['daily_free_scrolls'] ?? 0;
      final int regularScrolls = res['scrolls_count'] ?? 0;

      return (dailyFree + regularScrolls) > 0;
    } catch (e) {
      debugPrint('Error checking scrolls: $e');
      return false;
    }
  }

  /// Refreshes the daily free scrolls to 3 if it is a new day or if not yet set
  Future<void> _refreshDailyScrolls(String userId) async {
    try {
      final res = await _supabase
          .from('profiles')
          .select('last_scroll_refreshed_date')
          .eq('id', userId)
          .single();

      final String? dateStr = res['last_scroll_refreshed_date'];
      final now = DateTime.now();
      final String nowDay = "${now.toUtc().year}-${now.toUtc().month.toString().padLeft(2, '0')}-${now.toUtc().day.toString().padLeft(2, '0')}";
      
      final String? lastRefreshedDay = dateStr != null 
          ? DateTime.parse(dateStr).toUtc().toIso8601String().substring(0, 10) 
          : null;

      if (lastRefreshedDay == null || lastRefreshedDay != nowDay) {
        debugPrint('📅 Refreshing daily scrolls for $userId ($nowDay)...');
        await _supabase.from('profiles').update({
          'daily_free_scrolls': 3,
          'last_scroll_refreshed_date': now.toUtc().toIso8601String(),
        }).eq('id', userId);
        debugPrint('✅ Daily scrolls reset to 3');
      }
    } catch (e) {
      debugPrint('Error refreshing daily scrolls: $e');
    }
  }

  /// Get total available scrolls (daily free + purchased)
  Future<int> getAvailableScrollsCount(String userId) async {
    try {
      await _refreshDailyScrolls(userId);
      
      final res = await _supabase
          .from('profiles')
          .select('daily_free_scrolls, scrolls_count')
          .eq('id', userId)
          .single();
      return (res['daily_free_scrolls'] ?? 0) + (res['scrolls_count'] ?? 0);
    } catch (e) {
      debugPrint('Error getting scrolls count: $e');
      return 0;
    }
  }

  /// Deduct 1 scroll (Prefers daily_free_scrolls first, then scrolls_count).
  /// This calls our Postgres RPC function `use_scroll`.
  Future<bool> deductScroll(String userId) async {
    try {
      final response =
          await _supabase.rpc('use_scroll', params: {'user_id': userId});
      return response == true;
    } catch (e) {
      debugPrint('Error deducting scroll: $e');
      return false;
    }
  }

  /// Check if user can send a bottle today (redirects to scroll check).
  Future<bool> canSendBottleToday(String userId, bool isPremium) async {
    return hasAvailableScrolls(userId);
  }

  /// Increment bottle sent count
  Future<void> incrementDailyBottles(String userId) async {
    try {
      final res = await _supabase
          .from('profiles')
          .select('bottles_sent_today, last_bottle_sent_date')
          .eq('id', userId)
          .single();

      final int count = res['bottles_sent_today'] ?? 0;
      final String? dateStr = res['last_bottle_sent_date'];
      final now = DateTime.now();

      bool isNewDay = true;
      if (dateStr != null) {
        final lastDate = DateTime.parse(dateStr).toLocal();
        final nowLocal = now.toLocal();
        if (lastDate.year == nowLocal.year &&
            lastDate.month == nowLocal.month &&
            lastDate.day == nowLocal.day) {
          isNewDay = false;
        }
      }

      int newCount = isNewDay ? 1 : count + 1;

      await _supabase.from('profiles').update({
        'bottles_sent_today': newCount,
        'last_bottle_sent_date': now.toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      debugPrint('Error incrementing daily bottles: $e');
    }
  }

  /// Check if premium user reached weekly validation limit (3 messages)
  Future<bool> canSendMessageThisWeek(String userId) async {
    try {
      final res = await _supabase
          .from('profiles')
          .select('messages_sent_week, last_message_sent_week_start, gender, tier')
          .eq('id', userId)
          .single();

      // 1. Check for Premium or Woman logic (Unlimited messages)
      final gender = (res['gender'] as String?)?.toLowerCase() ?? '';
      final tier = res['tier'] as String? ?? 'free';
      final isPremiumOrWoman = gender == 'woman' || 
                             gender == 'female' || 
                             gender == 'femme' ||
                             tier == 'premium' || 
                             tier == 'elite';
                             
      if (isPremiumOrWoman) return true;

      // 2. Otherwise check weekly limit
      final int count = res['messages_sent_week'] ?? 0;
      final String? dateStr = res['last_message_sent_week_start'];
      final now = DateTime.now();

      // Check if week passed (7 days since start)
      if (dateStr == null ||
          now.difference(DateTime.parse(dateStr)).inDays >= 7) {
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
      return true;
    }
  }

  /// Add parchments (credits) by reducing the weekly message count
  /// This gives the user more "available slots" for messages
  Future<void> addParchments(String userId, int amount) async {
    try {
      debugPrint('🎁 Adding $amount parchments to user $userId');
      final res = await _supabase
          .from('profiles')
          .select('scrolls_count')
          .eq('id', userId)
          .single();
      final int currentCount = res['scrolls_count'] ?? 0;

      // Increase the scrolls_count (parchment balance)
      final newCount = currentCount + amount;

      await _supabase.from('profiles').update({
        'scrolls_count': newCount,
      }).eq('id', userId);
      debugPrint('✅ Parchment balance updated to $newCount');
    } catch (e) {
      debugPrint('❌ Error adding parchments: $e');
      rethrow;
    }
  }

  /// Increment weekly message count
  Future<void> incrementWeeklyMessages(String userId) async {
    try {
      final res = await _supabase
          .from('profiles')
          .select('messages_sent_week, last_message_sent_week_start')
          .eq('id', userId)
          .single();

      final int count = res['messages_sent_week'] ?? 0;
      final String? dateStr = res['last_message_sent_week_start'];
      final now = DateTime.now();

      bool reset = false;
      if (dateStr == null ||
          now.difference(DateTime.parse(dateStr)).inDays >= 7) {
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

  /// Update user's secret quote/desire
  Future<void> updateSecretDesire(String userId, String secretDesire) async {
    try {
      await _supabase.from('profiles').update({
        'secret_desire': secretDesire,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      debugPrint('📝 DB: Updated secret_desire to: "$secretDesire"');

      // Trigger broadcast for reactive updates
      final updatedProfile = await getProfile(userId);
      if (updatedProfile != null) {
        _profileUpdateController.add(updatedProfile);
        debugPrint('📡 DB: Broadcasted profile update for $userId');
      }

      debugPrint('✅ Secret desire updated successfully');
    } catch (e) {
      debugPrint('❌ Error updating secret desire: $e');
      rethrow;
    }
  }

  /// Update user's secret quote
  Future<void> updateSecretQuote(String userId, String secretQuote) async {
    try {
      await _supabase.from('profiles').update({
        'secret_quote': secretQuote,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      debugPrint('📝 DB: Updated secret_quote to: "$secretQuote"');

      // Trigger broadcast for reactive updates
      final updatedProfile = await getProfile(userId);
      if (updatedProfile != null) {
        _profileUpdateController.add(updatedProfile);
        debugPrint('📡 DB: Broadcasted profile update for $userId');
      }

      debugPrint('✅ Secret quote updated successfully');
    } catch (e) {
      debugPrint('❌ Error updating secret quote: $e');
      rethrow;
    }
  }

  /// Update user's secret audio message
  Future<void> updateSecretAudio(String userId, String audioUrl) async {
    try {
      await _supabase.from('profiles').update({
        'secret_audio_url': audioUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      debugPrint('📝 DB: Updated secret_audio_url to: $audioUrl');

      // Trigger broadcast for reactive updates
      final updatedProfile = await getProfile(userId);
      if (updatedProfile != null) {
        _profileUpdateController.add(updatedProfile);
        debugPrint('📡 DB: Broadcasted profile update for $userId');
      }

      debugPrint('✅ Secret audio updated successfully');
    } catch (e) {
      debugPrint('❌ Error updating secret audio: $e');
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

  /// Update user location
  Future<void> updateLocation(String userId, double lat, double lng) async {
    try {
      await _supabase.from('profiles').update({
        'lat': lat,
        'lng': lng,
        'last_active': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
      debugPrint('✅ Location updated successfully: $lat, $lng');
    } catch (e) {
      debugPrint('❌ Error updating location: $e');
      rethrow;
    }
  }

  // Get profile with robust photo check and local cache
  Future<Map<String, dynamic>?> getProfile(String userId, {bool useCache = true}) async {
    if (useCache && _profileCache.containsKey(userId)) {
      return _profileCache[userId];
    }

    final response = await _supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (response == null) return null;
    
    // Update cache
    _profileCache[userId] = response;

    // Fallback: if avatar_url is missing, check profile_photos table
    if (response['avatar_url'] == null ||
        (response['avatar_url'] as String).isEmpty) {
      try {
        final photos = await _supabase
            .from('profile_photos')
            .select('url')
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(1);

        if ((photos as List).isNotEmpty) {
          final url = photos[0]['url'] as String;
          debugPrint('FOUND FALLBACK PHOTO: $url');
          // Inject into response so UI works immediately
          response['avatar_url'] = url;

          // Self-repair: update profiles table in background
          _supabase
              .from('profiles')
              .update({'avatar_url': url})
              .eq('id', userId)
              .then((_) {
                debugPrint('Self-repaired profiles.avatar_url');
              })
              .catchError((err) {
                debugPrint('Failed to self-repair profiles: $err');
              });
        }
      } catch (e) {
        debugPrint('Error fetching fallback photo: $e');
      }
    }

    return response;
  }

  /// Get a real-time stream of the user's profile
  Stream<Map<String, dynamic>?> profileStream(String userId) {
    // Combine storage stream with local updates for maximum reactivity
    final supabaseStream = _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((data) => data.isNotEmpty ? data.first : null);

    final controller = StreamController<Map<String, dynamic>?>();

    // Listen to Supabase
    final sub1 = supabaseStream.listen(
      (data) => controller.add(data),
      onError: (e) => controller.addError(e),
    );

    // Listen to local updates
    final sub2 = _profileUpdateController.stream
        .where((data) => data['id'] == userId)
        .listen(
          (data) => controller.add(data),
          onError: (e) => controller.addError(e),
        );

    controller.onCancel = () {
      sub1.cancel();
      sub2.cancel();
    };

    return controller.stream;
  }

  /// Get a real-time stream of the user's gallery photos
  Stream<List<Map<String, dynamic>>> userPhotosStream(String userId) {
    return _supabase
        .from('profile_photos')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false);
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

      final blockedIds = await getBlockedUserIds(userId);

      var query = _supabase
          .from('received_bottles')
          .select('id')
          .eq('receiver_id', userId)
          .or('is_replied.eq.false,is_replied.is.null'); // Handle NULL as unreplied

      if (blockedIds.isNotEmpty) {
        query = query.not('sender_id', 'in', blockedIds);
      }

      final response = await query;

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
      // 1. Get bidirectional blocked user IDs
      final blockedIds = await getBlockedUsers(userId);
      final blockerIds = await getBlockers(userId);
      final allBlocked = {...blockedIds, ...blockerIds}.toList();

      var query =
          _supabase.from('received_bottles').select().eq('receiver_id', userId);

      if (allBlocked.isNotEmpty) {
        query = query.not('sender_id', 'in', allBlocked);
      }

      final response =
          await query.order('created_at', ascending: false).limit(limit);

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
      // 1. Get bidirectional blocked user IDs
      final blockedIds = await getBlockedUsers(userId);
      final blockerIds = await getBlockers(userId);
      final allBlocked = {...blockedIds, ...blockerIds}.toList();

      var query =
          _supabase.from('sent_bottles').select().eq('sender_id', userId);

      if (allBlocked.isNotEmpty) {
        // Exclude bottles where the matched recipient is blocked
        query = query.not('matched_recipient_id', 'in', allBlocked);
      }

      final response =
          await query.order('created_at', ascending: false).limit(limit);

      return (response as List)
          .map((json) => SentBottle.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting recent sent bottles: $e');
      return [];
    }
  }

  // Get all received bottles with sender details
  Future<List<ReceivedBottle>> getAllReceivedBottles(String userId) async {
    try {
      // 1. Get bidirectional blocked user IDs
      final blockedIds = await getBlockedUsers(userId);
      final blockerIds = await getBlockers(userId);
      final allBlocked = {...blockedIds, ...blockerIds}.toList();

      var query =
          _supabase.from('received_bottles').select().eq('receiver_id', userId);

      if (allBlocked.isNotEmpty) {
        query = query.not('sender_id', 'in', allBlocked);
      }

      final response = await query.order('created_at', ascending: false);

      final bottles = (response as List)
          .map((json) => ReceivedBottle.fromJson(json))
          .toList();

      if (bottles.isEmpty) return [];

      // Fetch sender profiles in batch
      final senderIds = bottles
          .map((b) => b.senderId)
          .where((id) => id != null)
          .toSet()
          .toList();

      if (senderIds.isEmpty) return bottles;

      final Map<String, Map<String, dynamic>> senderInfoMap = {};
      try {
        final profilesResponse = await _supabase
            .from('profiles')
            .select('id, full_name, birth_year, department')
            .inFilter('id', senderIds);

        final currentYear = DateTime.now().year;
        for (final p in (profilesResponse as List)) {
          final id = p['id'] as String;
          final fullName = p['full_name'] as String? ?? 'Someone';
          final birthYear = p['birth_year'] as int?;
          final department = p['department'] as String?;

          final nickname = fullName.split(' ').first;
          final age = birthYear != null ? currentYear - birthYear : null;

          senderInfoMap[id] = {
            'nickname': nickname,
            'age': age,
            'department': department,
          };
        }
      } catch (e) {
        debugPrint('⚠️ Error fetching sender profiles: $e');
      }

      // Merge sender info into bottles
      return bottles.map((b) {
        if (b.senderId != null && senderInfoMap.containsKey(b.senderId)) {
          final info = senderInfoMap[b.senderId]!;
          return b.copyWith(
            senderNickname: info['nickname'],
            senderAge: info['age'],
            senderDepartment: info['department'],
          );
        }
        return b.copyWith(senderNickname: 'Someone');
      }).toList();
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
      // 1. Get bidirectional blocked user IDs
      final blockedIds = await getBlockedUsers(userId);
      final blockerIds = await getBlockers(userId);
      final allBlocked = {...blockedIds, ...blockerIds}.toList();

      var query =
          _supabase.from('sent_bottles').select().eq('sender_id', userId);

      if (allBlocked.isNotEmpty) {
        query = query.not('matched_recipient_id', 'in', allBlocked);
      }

      final response = await query.order('created_at', ascending: false);

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

  /// Check if the current user has already replied to a bottle
  Future<bool> hasRepliedToBottle(String userId, String bottleId) async {
    try {
      final response = await _supabase
          .from('received_bottles')
          .select('is_replied')
          .eq('receiver_id', userId)
          .eq('id', bottleId)
          .maybeSingle();

      return response?['is_replied'] ?? false;
    } catch (e) {
      debugPrint('Error checking if bottle is replied: $e');
      return false;
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
    int? targetMinAge,
    int? targetMaxAge,
    List<String>? targetGender,
    int? targetDistanceKm,
    List<String>? targetDepartments,
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
            'target_min_age': targetMinAge,
            'target_max_age': targetMaxAge,
            'target_gender': targetGender,
            'target_distance_km': targetDistanceKm,
            'target_departments': targetDepartments,
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

  /// Send a direct bottle to a specific user (Targeted Bottle)
  /// Returns the bottle ID if successful
  Future<String?> sendDirectBottle({
    required String senderId,
    required String receiverId,
    required String contentType,
    String? message,
    String? audioUrl,
    String? photoUrl,
    String? caption,
    String? mood,
    String? replyToContentType,
    String? replyToContent,
    String? replyPrefix, // Pass translated prefix like "Replying to bio: "
  }) async {
    try {
      debugPrint('--- sendDirectBottle ---');
      debugPrint('Sender: $senderId, Receiver: $receiverId');

      // 0. Check if blocked (bidirectional)
      if (await isRelationBlocked(senderId, receiverId)) {
        debugPrint('🚫 Cannot send bottle: block relationship exists');
        return null;
      }

      // Append reply context to message since columns don't exist
      String finalMessage = message ?? '';
      if (replyToContent != null && replyToContent.isNotEmpty) {
        final prefix = replyPrefix ??
            (replyToContentType == 'bio'
                ? 'Replying to bio: '
                : 'Replying to: ');
        finalMessage = '$prefix"$replyToContent"\n\n$finalMessage';
      }

      // 1. Create Sent Bottle
      // Targeted bottles are implicitly 'delivered' immediately
      final sentBottle = await _supabase
          .from('sent_bottles')
          .insert({
            'sender_id': senderId,
            'content_type': contentType,
            'message': finalMessage,
            'audio_url': audioUrl,
            'photo_url': photoUrl,
            'caption': caption,
            'mood': mood,
            'status': 'delivered', // Directly delivered
            'matched_recipient_id': receiverId,
            'is_delivered': true,
            'has_reply': false,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final bottleId = sentBottle['id'] as String;
      debugPrint('✅ Created sent bottle: $bottleId');

      // 2. Create Received Bottle for the recipient
      await _supabase.from('received_bottles').insert({
        'receiver_id': receiverId,
        'sender_id': senderId,
        'sent_bottle_id': bottleId,
        'content_type': contentType,
        'message': finalMessage,
        'audio_url': audioUrl,
        'photo_url': photoUrl,
        'caption': caption,
        'mood': mood,
        // 'reply_to_content_type': replyToContentType, // Column does not exist
        // 'reply_to_content': replyToContent,         // Column does not exist
        'match_score': 100, // Direct match
        'is_read': false,
        'is_replied': false,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'matched_at': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ Created received bottle for recipient');

      // 3. Send Notification
      try {
        await _supabase.from('notifications').insert({
          'user_id': receiverId,
          'type': 'new_bottle',
          'title': 'New Bottle Received',
          'message': 'Someone sent you a bottle!',
          'data': {'bottle_id': bottleId},
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('⚠️ Notification failed: $e');
      }

      return bottleId;
    } catch (e) {
      debugPrint('❌ Error sending direct bottle: $e');
      return null;
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

  /// Increment bottle sent count
  Future<void> incrementBottlesSent(String userId) async {
    try {
      await _supabase.rpc('increment_bottles_sent', params: {
        'user_id': userId,
      });
    } catch (e) {
      debugPrint('Error incrementing bottle count: $e');
    }
  }

  /// Get current scroll count
  Future<int> getScrollCount(String userId) async {
    try {
      final res = await _supabase
          .from('profiles')
          .select('scrolls_count')
          .eq('id', userId)
          .single();
      return res['scrolls_count'] ?? 0;
    } catch (e) {
      debugPrint('Error fetching scroll count: $e');
      return 0;
    }
  }

  /// Use one scroll
  Future<bool> useScroll(String userId) async {
    try {
      final res = await _supabase.rpc('use_scroll', params: {
        'user_id': userId,
      });
      return res as bool? ?? false;
    } catch (e) {
      debugPrint('Error using scroll: $e');
      return false;
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
    // Step 1: Insert the block record — this is the ONLY critical step.
    // If this fails, we rethrow so the UI can show the error.
    try {
      await _supabase.from('user_blocks').insert({
        'blocker_id': blockerId,
        'blocked_id': blockedId,
        'created_at': DateTime.now().toIso8601String(),
      });
      debugPrint('✅ User $blockedId blocked by $blockerId');
    } catch (e) {
      debugPrint('❌ Error inserting block record: $e');
      rethrow; // Only rethrow on the critical step
    }

    // Steps 2-5: Non-critical cleanup. Failures here are logged but NOT rethrown.
    // The block already exists, so UI should show success regardless.

    // 2. Delete mutual conversations
    try {
      await _supabase.from('conversations').delete().or(
          'and(user_a_id.eq.$blockerId,user_b_id.eq.$blockedId),and(user_a_id.eq.$blockedId,user_b_id.eq.$blockerId)');
      debugPrint('✅ Deleted mutual conversations between $blockerId and $blockedId');
    } catch (e) {
      debugPrint('⚠️ Could not delete conversations (non-fatal): $e');
    }

    // 3. Delete received bottles between the two users
    try {
      await _supabase.from('received_bottles').delete().or(
          'and(receiver_id.eq.$blockerId,sender_id.eq.$blockedId),and(receiver_id.eq.$blockedId,sender_id.eq.$blockerId)');
      debugPrint('✅ Deleted mutual received bottles');
    } catch (e) {
      debugPrint('⚠️ Could not delete received bottles (non-fatal): $e');
    }

    // 4. Delete sent bottles
    try {
      await _supabase.from('sent_bottles').delete().or(
          'and(matched_recipient_id.eq.$blockerId,sender_id.eq.$blockedId),and(matched_recipient_id.eq.$blockedId,sender_id.eq.$blockerId)');
      debugPrint('✅ Deleted mutual sent bottles');
    } catch (e) {
      debugPrint('⚠️ Could not delete sent bottles (non-fatal): $e');
    }

    // 5. Delete orphaned matches
    try {
      await _supabase.from('matches').delete().or(
          'and(recipient_id.eq.$blockerId,sender_id.eq.$blockedId),and(recipient_id.eq.$blockedId,sender_id.eq.$blockerId)');
      debugPrint('✅ Deleted mutual matches');
    } catch (e) {
      debugPrint('⚠️ Could not delete matches (non-fatal): $e');
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

  Future<bool> isBlocked(String blockerId, String blockedId) {
    return isUserBlocked(blockerId: blockerId, blockedId: blockedId);
  }

  /// Get list of users who have blocked the given user (Incoming blocks)
  Future<List<String>> getBlockers(String userId) async {
    try {
      final response = await _supabase
          .from('user_blocks')
          .select('blocker_id')
          .eq('blocked_id', userId);

      return (response as List)
          .map((item) => item['blocker_id'] as String)
          .toList();
    } catch (e) {
      debugPrint('Error getting blockers: $e');
      return [];
    }
  }

  /// Check if there is ANY block relationship between two users (Bidirectional)
  /// Returns true if u1 blocked u2 OR u2 blocked u1
  Future<bool> isRelationBlocked(String u1, String u2) async {
    try {
      final response = await _supabase
          .from('user_blocks')
          .select('id')
          .or('and(blocker_id.eq.$u1,blocked_id.eq.$u2),and(blocker_id.eq.$u2,blocked_id.eq.$u1)')
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('Error checking relation block: $e');
      // Fallback: Check individually
      final blocked1 = await isUserBlocked(blockerId: u1, blockedId: u2);
      final blocked2 = await isUserBlocked(blockerId: u2, blockedId: u1);
      return blocked1 || blocked2;
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
      debugPrint('🔍 getUserConversations called for userId: $userId');

      final response = await _supabase
          .from('conversations')
          .select()
          .or('user_a_id.eq.$userId,user_b_id.eq.$userId')
          .order('updated_at', ascending: false);

      final blockedIds = await getBlockedUserIds(userId);
      
      final conversations = (response as List)
          .map((json) => Conversation.fromJson(json))
          .where((conv) {
        final otherId = conv.getOtherUserId(userId);
        return !blockedIds.contains(otherId);
      }).toList();

      if (conversations.isEmpty) return [];

      // Batch Fetch: Profiles and Unread Counts
      final convIds = conversations.map((c) => c.id).toList();
      final otherUserIds = conversations
          .map((c) => c.getOtherUserId(userId))
          .toSet()
          .toList();

      // Execute queries in parallel
      final results = await Future.wait([
        // 1. Fetch unread counts
        _supabase
            .from('messages')
            .select('conversation_id')
            .inFilter('conversation_id', convIds)
            .eq('is_read', false)
            .neq('sender_id', userId),
            
        // 2. Fetch profiles
        _supabase
            .from('profiles')
            .select('id, full_name, avatar_url, gender, tier')
            .inFilter('id', otherUserIds),
      ]);

      final unreadMsgs = results[0] as List;
      final profilesRaw = results[1] as List;

      // Map counts
      final Map<String, int> unreadCounts = {};
      for (var msg in unreadMsgs) {
        final cId = msg['conversation_id'] as String;
        unreadCounts[cId] = (unreadCounts[cId] ?? 0) + 1;
      }

      // Map profiles
      final Map<String, Map<String, dynamic>> profileMap = {
        for (var p in profilesRaw) p['id'] as String: p as Map<String, dynamic>
      };

      // Update conversation objects with counts and profile data (if we added it to model)
      // Actually, since we need to stick to the model, we can return the conversations
      // but the UI will still need the profile.
      // OPTIMIZATION: We can "inject" the profile into a cache or return a wrapper.
      // For now, let's keep it simple: the UI will still call getProfile, 
      // BUT we will implement a simple Memoization/Cache in DatabaseService for profiles.
      
      for (var i = 0; i < conversations.length; i++) {
        final c = conversations[i];
        final otherId = c.getOtherUserId(userId);
        
        // Cache the profile we just fetched to avoid subsequent N+1 calls
        if (profileMap.containsKey(otherId)) {
          _profileCache[otherId] = profileMap[otherId]!;
        }

        if (unreadCounts.containsKey(c.id)) {
          conversations[i] = c.copyWith(
            unreadCount: unreadCounts[c.id]!,
          );
        }
      }

      return conversations;
    } catch (e) {
      debugPrint('❌ Error getting conversations: $e');
      return [];
    }
  }

  // Simple profile cache to prevent N+1 queries in lists
  final Map<String, Map<String, dynamic>> _profileCache = {};

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
      // 0. Check if blocked
      if (await isRelationBlocked(userAId, userBId)) {
        throw Exception('Blocked users cannot start conversations');
      }
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

  Future<void> renameConversation(String conversationId, String newName) async {
    try {
      await _supabase.from('conversations').update({
        'title': newName,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', conversationId);
      debugPrint('✅ Conversation renamed to: $newName');
    } catch (e) {
      debugPrint('❌ Error renaming conversation: $e');
      rethrow;
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
    int? feelingDelta,
    String? replyToId,
    String? lastMessageSummary,
  }) async {
    try {
      final Map<String, dynamic> messageData = {
        'conversation_id': conversationId,
        'sender_id': senderId,
        'type': type,
        'text': text,
        'media_url': mediaUrl,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'is_read': false,
        'mood': mood,
        'feeling_delta': feelingDelta,
        'reply_to_id': replyToId,
      };

      // Only include duration if it's not null, preventing errors if column doesn't exist yet
      if (duration != null) {
        messageData['duration'] = duration;
      }

      await _supabase.from('messages').insert(messageData);

      // Update conversation last message
      String lastMsg = lastMessageSummary ??
          text ??
          (type == 'image' ? 'Picture' : 'Voice Message');

      // Sanitization: If it contains the milestone separator, strip the content part
      if (lastMsg.contains('|--CONTENT--|')) {
        lastMsg = lastMsg.split('|--CONTENT--|')[0];
      }

      await _supabase.from('conversations').update({
        'last_message': lastMsg,
        'last_message_time': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
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
        'feeling_delta': 5,
        'created_at': DateTime.now().toUtc().toIso8601String(),
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
        'feeling_delta': 5,
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
          .map((json) =>
              ChatMessage.fromJson(json, currentUserId: currentUserId))
          .toList();
    } catch (e) {
      debugPrint('Error loading messages: $e');
      return [];
    }
  }

  Future<void> updateMessage(String messageId, String newText) async {
    try {
      await _supabase.from('messages').update({
        'text': newText,
        'updated_at': DateTime.now().toUtc().toIso8601String()
      }).eq('id', messageId);
      debugPrint('✅ Message updated: $messageId');
    } catch (e) {
      debugPrint('❌ Error updating message: $e');
      rethrow;
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await _supabase.from('messages').delete().eq('id', messageId);
      debugPrint('✅ Message deleted: $messageId');
    } catch (e) {
      debugPrint('❌ Error deleting message: $e');
      rethrow;
    }
  }

  /// Standard feeling increment for a successful exchange.
  /// Currently fixed at 5% as per user requirement.
  int calculateFeelingPoints({
    required String type,
    String? text,
    int? duration,
  }) {
    return 5;
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

  /// Get IDs of users the current user has already replied to or has a conversation with
  Future<List<String>> getRepliedPartnerIds(String userId) async {
    try {
      final Set<String> partnerIds = {};

      // 1. Get partners from conversations
      final convs = await _supabase
          .from('conversations')
          .select('user_a_id, user_b_id')
          .or('user_a_id.eq.$userId,user_b_id.eq.$userId');

      for (final c in (convs as List)) {
        if (c['user_a_id'] != userId) partnerIds.add(c['user_a_id'] as String);
        if (c['user_b_id'] != userId) partnerIds.add(c['user_b_id'] as String);
      }

      // 2. Get recipients from bottles I sent
      final sentByMe = await _supabase
          .from('sent_bottles')
          .select('receiver_id, matched_recipient_id')
          .eq('sender_id', userId)
          .or('receiver_id.not.is.null,matched_recipient_id.not.is.null');

      for (final b in (sentByMe as List)) {
        if (b['receiver_id'] != null) {
          partnerIds.add(b['receiver_id'] as String);
        }
        if (b['matched_recipient_id'] != null) {
          partnerIds.add(b['matched_recipient_id'] as String);
        }
      }

      // 3. Get senders from bottles I received
      final receivedByMe = await _supabase
          .from('received_bottles')
          .select('sender_id')
          .eq('receiver_id', userId);

      for (final b in (receivedByMe as List)) {
        if (b['sender_id'] != null) {
          partnerIds.add(b['sender_id'] as String);
        }
      }

      // 4. Get senders from bottles that were matched to me but not yet in received_bottles
      final matchedToMe = await _supabase
          .from('sent_bottles')
          .select('sender_id')
          .eq('matched_recipient_id', userId);

      for (final b in (matchedToMe as List)) {
        if (b['sender_id'] != null) {
          partnerIds.add(b['sender_id'] as String);
        }
      }

      return partnerIds.toList();
    } catch (e) {
      debugPrint('Error getting replied partner IDs: $e');
      return [];
    }
  }

  /// Get intimate questions for a conversation
  Future<List<IntimateQuestion>> getIntimateQuestions(
      String conversationId) async {
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
      debugPrint(
          '🔌 Setting up realtime subscription for conversation: $conversationId');
      final controller = StreamController<Map<String, dynamic>>();
      final channel = _supabase.channel('messages_$conversationId');

      channel
          .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'conversation_id',
          value: conversationId,
        ),
        callback: (payload) {
          debugPrint('🔔 Realtime message event: ${payload.eventType}');

          Map<String, dynamic> data;
          if (payload.eventType == PostgresChangeEvent.delete) {
            data = Map<String, dynamic>.from(payload.oldRecord);
          } else {
            data = Map<String, dynamic>.from(payload.newRecord);
          }

          // Include the event type so the UI knows what happened
          data['event_type'] = payload.eventType.name;
          controller.add(data);
        },
      )
          .subscribe((status, error) {
        debugPrint('📡 Message subscription status: $status');
        if (error != null) {
          debugPrint('❌ Message subscription error: $error');
        }
      });

      return controller.stream;
    } catch (e) {
      debugPrint('❌ Error subscribing to messages: $e');
      return const Stream.empty();
    }
  }

  Stream<Map<String, dynamic>> subscribeConversation(String conversationId) {
    try {
      debugPrint(
          '🔌 Setting up realtime subscription for conversation updates: $conversationId');
      final controller = StreamController<Map<String, dynamic>>();
      final channel = _supabase.channel('conversations_update_$conversationId');
      channel
          .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'conversations',
        callback: (payload) {
          final newRec = payload.newRecord;
          if (newRec['id'] == conversationId) {
            debugPrint(
                '🔥 Conversation UPDATE received via client-side filter!');
            debugPrint('   Feeling: ${newRec['feeling_percent']}');
            controller.add(newRec.cast<String, dynamic>());
          }
        },
      )
          .subscribe((status, error) {
        debugPrint('📡 Conversation subscription status: $status');
        if (error != null) debugPrint('❌ Subscription error: $error');
      });

      return controller.stream;
    } catch (e) {
      debugPrint('Error subscribing to conversation: $e');
      return const Stream.empty();
    }
  }

  Stream<Map<String, dynamic>> subscribeProfile(String userId) {
    try {
      debugPrint('🔌 Setting up realtime subscription for profile: $userId');
      final controller = StreamController<Map<String, dynamic>>();
      final channel = _supabase.channel('profile_$userId');

      channel
          .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'profiles',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: userId,
        ),
        callback: (payload) {
          debugPrint('🔔 Profile update received via realtime!');
          controller.add(payload.newRecord.cast<String, dynamic>());
        },
      )
          .subscribe((status, error) {
        debugPrint('📡 Profile subscription status: $status');
        if (error != null) debugPrint('❌ Profile subscription error: $error');
      });

      return controller.stream;
    } catch (e) {
      debugPrint('❌ Error subscribing to profile: $e');
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
      debugPrint(
          '🔍 SecretSouls: getSecretSoulsContent START (type: $contentType, page: $page)');
      final currentUserId = _supabase.auth.currentUser?.id;
      List<Map<String, dynamic>> items = [];

      final int start = page * pageSize;
      final int end = start + pageSize - 1;

      // 1. Get blocked users and existing contacts (Bidirectional by default)
      final blockedIdsSet = await getBlockedUserIds(currentUserId ?? '');
      final contactIdsSet = await getRepliedPartnerIds(currentUserId ?? '');
      final excludedIds = {...blockedIdsSet, ...contactIdsSet};
      debugPrint('🔍 SecretSouls: Excluded IDs: ${excludedIds.length}');

      // 1.1 Get current user's preferences for reciprocal matching
      final viewerProfile = await getProfile(currentUserId ?? '');
      final String? viewerGender = viewerProfile?['gender']; // 'male', 'female', 'nonbinary'
      final String? viewerInterestedIn = viewerProfile?['interested_in']; // 'Men', 'Women', 'Non-binary', 'Everyone'

      debugPrint('🔍 SecretSouls: Viewer gender=$viewerGender, interestedIn=$viewerInterestedIn');

      // Helper: Does the viewer want to see this creator's content?
      // Only the viewer's preference matters here — this is a public discovery screen.
      // The creator's interested_in is irrelevant for what others can see about them.
      bool isCompatible(String? creatorGender, String? creatorInterestedIn) {
        final vInterest = viewerInterestedIn ?? 'Everyone';
        if (vInterest == 'Everyone') return true;
        if (vInterest == 'Men' && creatorGender == 'male') return true;
        if (vInterest == 'Women' && creatorGender == 'female') return true;
        if (vInterest == 'Non-binary' && creatorGender == 'nonbinary') return true;
        // If gender not set, include it (don't exclude unspecified)
        if (creatorGender == null) return true;
        return false;
      }

      // 2. Fetch Quotes/Bios (if all, quote, or bio)
      if (contentType == null ||
          contentType == 'quote' ||
          contentType == 'bio') {
        debugPrint(
            '🔍 SecretSouls: Fetching quotes/bios (range: $start-$end)...');

        try {
          var profileQuery = _supabase
              .from('profiles')
              .select(
                  'id, secret_quote, about, city, department, full_name, age, created_at, gender, interested_in')
              .or('secret_quote.not.is.null,about.not.is.null')
              .order('created_at', ascending: false)
              .range(start, end);

          final profileItems = await profileQuery;
          debugPrint(
              '🔍 SecretSouls: Raw profile items fetched: ${(profileItems as List).length}');

          for (final q in (profileItems as List)) {
            if (q['id'] == currentUserId) continue;
            if (excludedIds.contains(q['id'])) continue;

            // Reciprocal Matching Check
            if (!isCompatible(q['gender'], q['interested_in'])) continue;

            String? quoteText;
            String? bioText;
            String idSuffix = 'about';

            if (q['secret_quote'] != null &&
                q['secret_quote'].toString().isNotEmpty) {
              quoteText = q['secret_quote'];
              idSuffix = 'quote';
            }

            if (q['about'] != null && q['about'].toString().isNotEmpty) {
              bioText = q['about'];
            }

            // If user explicitly asked for BIO, only add if bio exists
            if (contentType == 'bio') {
              if (bioText != null) {
                items.add({
                  'id': '${q['id']}_bio',
                  'user_id': q['id'],
                  'content_type': 'bio',
                  'bio_text': bioText,
                  'city': q['city'],
                  'department': q['department'],
                  'full_name': q['full_name'],
                  'age': q['age'],
                  'created_at': q['created_at'],
                });
              }
            }
            // If user asked for QUOTE or ALL, handle as before
            else {
              // Priority: Desire > Quote > About (as a quote)
              final finalQuote = quoteText ?? bioText;
              if (finalQuote != null) {
                items.add({
                  'id': '${q['id']}_$idSuffix',
                  'user_id': q['id'],
                  'content_type': 'quote',
                  'quote_text': finalQuote,
                  'city': q['city'],
                  'department': q['department'],
                  'full_name': q['full_name'],
                  'age': q['age'],
                  'created_at': q['created_at'],
                });
              }
            }
          }
        } catch (e) {
          debugPrint('❌ ERROR fetching profile content: $e');
        }

        // Fetches from fantasies table removed.
        // Fantasies should exclusively appear in the Door of Desires, not Secret Souls.
      }

      // 2.1 Fetch from secret_souls_content table (Mixed Content)
      try {
        debugPrint(
            '🔍 SecretSouls: Fetching from secret_souls_content (range: $start-$end)...');
        var sscQuery = _supabase
            .from('secret_souls_content')
            .select('id, user_id, content_type, photo_url, audio_url, quote_text, created_at')
            .eq('is_visible', true)
            .neq('user_id', currentUserId ?? '');

        if (contentType != null) {
          sscQuery = sscQuery.eq('content_type', contentType);
        }

        final sscItems = await sscQuery
            .order('created_at', ascending: false)
            .range(start, end);

        debugPrint(
            '🔍 SecretSouls: Raw secret_souls_content fetched: ${(sscItems as List).length}');

        if ((sscItems as List).isNotEmpty) {
          // Batch-fetch profiles for all user_ids to avoid N+1 queries
          final userIds = sscItems.map((s) => s['user_id'] as String).toSet().toList();
          final profilesData = await _supabase
              .from('profiles')
              .select('id, city, department, full_name, age, avatar_url, gender, interested_in')
              .filter('id', 'in', userIds);

          final Map<String, Map<String, dynamic>> profileMap = {
            for (var p in (profilesData as List)) p['id'] as String: p as Map<String, dynamic>
          };

          for (final s in sscItems) {
            if (excludedIds.contains(s['user_id'])) continue;

            final profile = profileMap[s['user_id']];

            // Matching check (viewer-side only)
            if (!isCompatible(profile?['gender'], profile?['interested_in'])) continue;

            // Check if this gallery photo is the main profile picture
            final bool isMain = s['content_type'] == 'photo' &&
                s['photo_url'] != null &&
                s['photo_url'] == profile?['avatar_url'];

            items.add({
              'id': 'ssc_${s['id']}',
              'user_id': s['user_id'],
              'content_type': s['content_type'],
              'photo_url': s['photo_url'],
              'audio_url': s['audio_url'],
              'quote_text': s['quote_text'],
              'is_main_profile_picture': isMain,
              'city': profile?['city'],
              'department': profile?['department'],
              'full_name': profile?['full_name'],
              'age': profile?['age'],
              'created_at': s['created_at'],
            });
          }
        }
      } catch (e) {
        debugPrint('❌ ERROR fetching secret_souls_content: $e');
      }

      // 3. Fetch Audio (if all or audio)
      if (contentType == null || contentType == 'audio') {
        try {
          debugPrint('🔍 SecretSouls: Fetching audio (range: $start-$end)...');
          var query = _supabase
              .from('profiles')
              .select(
                  'id, secret_audio_url, city, department, full_name, age, created_at, gender, interested_in')
              .not('secret_audio_url', 'is', null)
              .order('created_at', ascending: false)
              .range(start, end);

          final itemsToFetch = await query;
          debugPrint(
              '🔍 SecretSouls: Raw audios fetched: ${(itemsToFetch as List).length}');

          final audios = (itemsToFetch as List).where((a) {
            if (a['id'] == currentUserId) return false;
            if (excludedIds.contains(a['id'])) return false;
            
            // Reciprocal Matching Check
            if (!isCompatible(a['gender'], a['interested_in'])) return false;

            return true;
          }).toList();
          debugPrint('🔍 SecretSouls: Filtered audios: ${audios.length}');

          items.addAll(audios.map((a) => {
                'id': 'aud_${a['id']}',
                'user_id': a['id'],
                'content_type': 'audio',
                'audio_url': a['secret_audio_url'],
                'city': a['city'],
                'department': a['department'],
                'full_name': a['full_name'],
                'age': a['age'],
                'created_at': a['created_at'],
              }));
        } catch (e) {
          debugPrint('❌ ERROR fetching audio: $e');
        }
      }

      // 4. Fetch Photos (if all or photo)
      if (contentType == null || contentType == 'photo') {
        try {
          debugPrint('🔍 SecretSouls: Fetching photos (range: $start-$end)...');
          var query = _supabase
              .from('profile_photos')
              .select(
                  'id, user_id, url, created_at, is_first_face_photo, profiles!inner(city, department, full_name, age, avatar_url, gender, interested_in)')
              .eq('show_in_secret_souls', true)
              .neq('user_id', currentUserId ?? '');

          if (excludedIds.isNotEmpty) {
            query = query.not('user_id', 'in', excludedIds.toList());
          }

          final photos = await query
              .order('created_at', ascending: false)
              .range(start, end);

          debugPrint(
              '🔍 SecretSouls: Raw photos fetched: ${(photos as List).length}');

          items.addAll((photos as List).where((p) {
            // Reciprocal Matching Check
            return isCompatible(p['profiles']?['gender'], p['profiles']?['interested_in']);
          }).map((p) => {
                'id': 'photo_${p['id']}',
                'user_id': p['user_id'],
                'content_type': 'photo',
                'photo_url': p['url'],
                'is_main_profile_picture': p['is_first_face_photo'] == true ||
                    p['url'] == p['profiles']?['avatar_url'],
                'city': p['profiles']?['city'],
                'department': p['profiles']?['department'],
                'full_name': p['profiles']?['full_name'],
                'age': p['profiles']?['age'],
                'created_at': p['created_at'],
              }));
        } catch (e) {
          debugPrint('❌ ERROR fetching photos: $e');
        }
      }
      // 5. Finalize and Sort
      items.sort((a, b) => (b['created_at'] ?? '')
          .toString()
          .compareTo((a['created_at'] ?? '').toString()));

      debugPrint(
          '🔍 SecretSouls: getSecretSoulsContent SUCCESS ($page, count: ${items.length})');
      return items;
    } catch (e) {
      debugPrint('❌ ERROR in getSecretSoulsContent: $e');
      if (e is PostgrestException) {
        debugPrint('   Postgrest code: ${e.code}');
        debugPrint('   Postgrest message: ${e.message}');
        debugPrint('   Postgrest details: ${e.details}');
      }
      return [];
    }
  }

  // ==================== NOTIFICATIONS / UNREAD ====================

  Future<void> markMessagesAsRead(String conversationId, String userId) async {
    try {
      // Mark all messages in this conversation addressed TO me as read
      // i.e. sender_id != userId
      await _supabase
          .from('messages')
          .update({'is_read': true})
          .eq('conversation_id', conversationId)
          .neq('sender_id', userId)
          .eq('is_read', false);

      debugPrint('✅ Marked messages as read for conversation: $conversationId');
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  Future<int> getUnreadMessageCount() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 0;

      // 1. Get my conversations
      final myConvs = await _supabase
          .from('conversations')
          .select('id')
          .or('user_a_id.eq.$userId,user_b_id.eq.$userId');

      if ((myConvs as List).isEmpty) return 0;

      final convIds = (myConvs as List).map((c) => c['id']).toList();

      // 2. Count unread messages (Manual fetch & count to match getUserConversations)
      final blockedIds = await getBlockedUserIds(userId);

      var query = _supabase
          .from('messages')
          .select('id')
          .inFilter('conversation_id', convIds)
          .eq('is_read', false)
          .neq('sender_id', userId);

      if (blockedIds.isNotEmpty) {
        query = query.not('sender_id', 'in', blockedIds);
      }

      final unreadMsgs = await query;

      final count = (unreadMsgs as List).length;
      debugPrint('🔔 Global unread count: $count');

      return count;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  Stream<int> get unreadCountStream async* {
    while (true) {
      yield await getUnreadMessageCount();
      await Future.delayed(const Duration(seconds: 3)); // Poll every 3s
    }
  }

  /// Start anonymous conversation from Secret Souls content
  /// Check if a conversation exists between two users
  Future<String?> getConversationId(String userA, String userB) async {
    try {
      // Check for A-B
      final existing1 = await _supabase
          .from('conversations')
          .select('id')
          .eq('user_a_id', userA)
          .eq('user_b_id', userB)
          .maybeSingle();

      if (existing1 != null) return existing1['id'] as String;

      // Check for B-A (if conversations are not strictly ordered, dependent on app logic)
      // Assuming ordered or checking both:
      final existing2 = await _supabase
          .from('conversations')
          .select('id')
          .eq('user_a_id', userB)
          .eq('user_b_id', userA)
          .maybeSingle();

      if (existing2 != null) return existing2['id'] as String;

      return null;
    } catch (e) {
      debugPrint('Error checking conversation existence: $e');
      return null;
    }
  }

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
        debugPrint(
            '⚠️ Found existing conversation: ${existing['id']} - returning null to prevent duplicate');
        return null;
      }

      debugPrint('No existing conversation found. Creating new one...');

      // 2. Create conversation with correct schema
      final response = await _supabase
          .from('conversations')
          .insert({
            'user_a_id': requesterId,
            'user_b_id': ownerId,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
            'title': 'Chamber of Secrets',
            'mask_a': 'Secret',
            'mask_b': 'Soul',
          })
          .select('id')
          .single();

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
          feelingDelta: 5,
        );
      }

      // Send notification (optional - don't fail if notifications table doesn't exist)
      try {
        await _supabase.from('notifications').insert({
          'user_id': ownerId,
          'type': 'secret_souls_message',
          'title': 'New Chamber Message',
          'message': 'Someone wants to connect with you anonymously',
          'data': {'conversation_id': convId, 'content_id': contentId},
          'created_at': DateTime.now().toIso8601String(),
        });
        debugPrint('✅ Notification sent successfully');
      } catch (notifError) {
        debugPrint(
            '⚠️ Could not send notification (table may not exist): $notifError');
        // Continue anyway - notification is optional
      }

      return convId;
    } catch (e) {
      debugPrint('ERROR starting Secret Souls conversation: $e');
      return null;
    }
  }

  /// Start anonymous conversation from Door of Desires fantasy
  Future<String?> startAnonymousFantasyConversation({
    required String fantasyId,
    required String requesterId,
    required String ownerId,
    String? initialMessage,
  }) async {
    debugPrint('--- startAnonymousFantasyConversation ---');
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

      // 2. Create conversation
      final response = await _supabase
          .from('conversations')
          .insert({
            'user_a_id': requesterId,
            'user_b_id': ownerId,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
            'title': 'Door of Desires',
            'mask_a': 'Desire',
            'mask_b': 'Fantasy',
          })
          .select('id')
          .single();

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
          feelingDelta: 5,
        );
      }

      // Send notification (optional - don't fail if notifications table doesn't exist)
      try {
        await _supabase.from('notifications').insert({
          'user_id': ownerId,
          'type': 'fantasy_message',
          'title': 'New Fantasy Message',
          'message': 'Someone wants to connect with you about your fantasy',
          'data': {'conversation_id': convId, 'fantasy_id': fantasyId},
          'created_at': DateTime.now().toIso8601String(),
        });
        debugPrint('✅ Notification sent successfully');
      } catch (notifError) {
        debugPrint(
            '⚠️ Could not send notification (table may not exist): $notifError');
        // Continue anyway - notification is optional
      }

      return convId;
    } catch (e) {
      debugPrint('ERROR starting Fantasy conversation: $e');
      return null;
    }
  }

  /// List fantasies for Door of Desires (Aggregated from profiles, fantasies, and secret_souls_content)
  Future<List<Map<String, dynamic>>> listFantasies({
    int page = 0,
    int pageSize = 20,
    bool includeSelf = false,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      final blockedIds = await getBlockedUserIds(currentUserId ?? '');
      final partnerIds = await getRepliedPartnerIds(currentUserId ?? '');
      final excludedIds = {...blockedIds, ...partnerIds}.toList();
      final List<Map<String, dynamic>> allItems = [];
      final Set<String> addedUserIds = {}; // Track users to avoid duplicates

      int start = page * pageSize;
      int end = (page + 1) * pageSize - 1;

      // 0. Get current user's preferences
      final viewerProfile = await getProfile(currentUserId ?? '');
      final String? viewerInterestedIn = viewerProfile?['interested_in'];

      // Helper: Does the viewer want to see this creator's content?
      // Only the viewer's preference matters here — this is a public discovery screen.
      bool isCompatible(String? creatorGender, String? creatorInterestedIn) {
        final vInterest = viewerInterestedIn ?? 'Everyone';
        if (vInterest == 'Everyone') return true;
        if (vInterest == 'Men' && creatorGender == 'male') return true;
        if (vInterest == 'Women' && creatorGender == 'female') return true;
        if (vInterest == 'Non-binary' && creatorGender == 'nonbinary') return true;
        // If gender not set, include it (don't exclude unspecified)
        if (creatorGender == null) return true;
        return false;
      }

      // 1. Fetch from fantasies table (Explicit fantasies)
      try {
        var fQuery = _supabase.from('fantasies').select(
            'id, user_id, text, created_at, profiles!inner(city, department, full_name, age, gender, interested_in)');

        if (!includeSelf) {
          fQuery = fQuery.neq('user_id', currentUserId ?? '');
        }

        if (excludedIds.isNotEmpty) {
          fQuery = fQuery.not('user_id', 'in', excludedIds);
        }

        final fantasyItems = await fQuery
            .order('created_at', ascending: false)
            .range(start, end);

        for (var f in (fantasyItems as List)) {
          final userId = f['user_id'];
          if (addedUserIds.contains(userId)) continue;

          // Reciprocal Matching Check
          if (!isCompatible(
              f['profiles']?['gender'], f['profiles']?['interested_in'])) {
            continue;
          }

          addedUserIds.add(userId);
          allItems.add({
            'id': 'fan_${f['id']}',
            'user_id': userId,
            'fantasy_text': f['text'],
            'type': 'fantasy',
            'city': f['profiles']?['city'],
            'department': f['profiles']?['department'],
            'full_name': f['profiles']?['full_name'],
            'age': f['profiles']?['age'],
            'created_at': f['created_at'],
          });
        }
      } catch (e) {
        debugPrint('❌ Error fetching fantasies table: $e');
      }

      // 2. Fetch from secret_souls_content (Fantasy type)
      try {
        var sscQuery = _supabase
            .from('secret_souls_content')
            .select(
                'id, user_id, content_type, quote_text, created_at, profiles!inner(city, department, full_name, age, gender, interested_in)')
            .eq('is_visible', true)
            .eq('content_type', 'fantasy');

        if (!includeSelf) {
          sscQuery = sscQuery.neq('user_id', currentUserId ?? '');
        }

        if (excludedIds.isNotEmpty) {
          sscQuery = sscQuery.not('user_id', 'in', excludedIds.toList());
        }

        final sscItems = await sscQuery
            .order('created_at', ascending: false)
            .range(start, end);

        for (var s in (sscItems as List)) {
          final userId = s['user_id'];
          if (addedUserIds.contains(userId)) continue;

          // Reciprocal Matching Check
          if (!isCompatible(
              s['profiles']?['gender'], s['profiles']?['interested_in'])) {
            continue;
          }

          addedUserIds.add(userId);
          allItems.add({
            'id': 'ssc_${s['id']}',
            'user_id': userId,
            'fantasy_text': s['quote_text'],
            'type': 'ssc_fantasy',
            'city': s['profiles']?['city'],
            'department': s['profiles']?['department'],
            'full_name': s['profiles']?['full_name'] ?? 'Secret Soul',
            'age': s['profiles']?['age'],
            'created_at': s['created_at'],
          });
        }
      } catch (e) {
        debugPrint('❌ Error fetching secret_souls_content fantasies: $e');
      }

      // 3. Fetch from profiles (secret_desire - fallback)
      try {
        var query = _supabase
            .from('profiles')
            .select(
                'id, secret_desire, city, department, full_name, age, created_at, gender, interested_in')
            .not('secret_desire', 'is', null);

        if (!includeSelf) {
          query = query.neq('id', currentUserId ?? '');
        }

        if (blockedIds.isNotEmpty) {
          query = query.not('id', 'in', blockedIds);
        }

        final profileItems =
            await query.order('created_at', ascending: false).range(start, end);

        for (var p in (profileItems as List)) {
          final userId = p['id'];
          if (addedUserIds.contains(userId)) continue;

          // Reciprocal Matching Check
          if (!isCompatible(p['gender'], p['interested_in'])) continue;

          addedUserIds.add(userId);
          allItems.add({
            'id': 'prof_${p['id']}',
            'user_id': userId,
            'fantasy_text': p['secret_desire'],
            'type': 'profile_desire',
            'city': p['city'],
            'department': p['department'],
            'full_name': p['full_name'],
            'age': p['age'],
            'created_at': p['created_at'],
          });
        }
      } catch (e) {
        debugPrint('❌ Error fetching profile desires: $e');
      }

      // 4. Sort aggregated results
      allItems.sort((a, b) => (b['created_at'] ?? '')
          .toString()
          .compareTo((a['created_at'] ?? '').toString()));

      return allItems.map((item) {
        return {
          'id': item['id'],
          'user_id': item['user_id'],
          'fantasy_text': item['fantasy_text'],
          'text': item['fantasy_text'], // Legacy support
          'profiles': {
            'city': item['city'],
            'department': item['department'],
            'full_name': item['full_name'] ?? 'Secret Soul',
            'age': item['age'],
          },
          'created_at': item['created_at'],
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Error listing fantasies: $e');
      return [];
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
        'show_in_secret_souls': true,
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
          .update({'avatar_url': signedUrl}).eq('id', userId);

      // Notify local listeners immediately
      _profileUpdateController.add({
        'id': userId,
        'avatar_url': signedUrl,
      });

      return signedUrl;
    } catch (e) {
      debugPrint('Error uploading face photo: $e');
      return null;
    }
  }

  Future<Map<String, String>?> uploadFirstFacePhotoAndInsert({
    required String userId,
    required File imageFile,
    bool showInSecretSouls = true, // User consent for Secret Room
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
            'show_in_secret_souls': showInSecretSouls,
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

      // Notify local listeners immediately
      _profileUpdateController.add({
        'id': userId,
        'avatar_url': publicUrl,
      });

      return {
        'photo_id': rec['id'] as String,
        'url': publicUrl,
      };
    } catch (e) {
      debugPrint('ERROR in uploadFirstFacePhotoAndInsert: $e');
      return null;
    }
  }

  Future<String?> uploadAudioClip({
    required String userId,
    required File audioFile,
  }) async {
    try {
      final String ext = audioFile.path.split('.').last;
      final String fileName =
          'secret_audio_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final String path = '$userId/$fileName';

      await _supabase.storage.from('voice_clips').upload(path, audioFile,
          fileOptions: const FileOptions(upsert: false));

      final url = _supabase.storage.from('voice_clips').getPublicUrl(path);
      return url;
    } catch (e) {
      debugPrint('Error uploading audio clip: $e');
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

      // Notify local listeners immediately
      _profileUpdateController.add({
        'id': userId,
        'avatar_url': photoUrl,
      });

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

  Future<void> updateFantasy(String fantasyId, String text) async {
    try {
      await _supabase
          .from('fantasies')
          .update({'text': text}).eq('id', fantasyId);
    } catch (e) {
      debugPrint('Error updating fantasy: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> listUserFantasies(String userId) async {
    try {
      final res = await _supabase
          .from('fantasies')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('Error listing user fantasies: $e');
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

  // ==================== ACCOUNT MANAGEMENT ====================

  /// Delete current user account
  /// Uses a PostgreSQL RPC function `delete_account`
  Future<void> deleteAccount() async {
    try {
      debugPrint('⚠️ Requesting account deletion via delete_account RPC...');
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated - cannot delete account');
      }
      
      // Attempt the deletion via RPC
      await _supabase.rpc('delete_account');
      
      debugPrint('✅ Account deletion request successful for user $userId');
      
      // Sign out immediately after deletion
      await _supabase.auth.signOut();
    } on PostgrestException catch (e) {
      debugPrint('❌ Postgres Error during deleteAccount(): ${e.message}');
      debugPrint('Details: ${e.details}');
      debugPrint('Hint: ${e.hint}');
      // Return a very specific error message so the UI can show it
      throw Exception('Database Error: ${e.message}${e.details != null ? " ($e.details)" : ""}');
    } catch (e) {
      debugPrint('❌ Unexpected error during deleteAccount(): $e');
      rethrow;
    }
  }

  // ==================== ELITE ANONYMOUS DM ====================

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
      feelingDelta: 5,
    );
  }

  // ==================== BLOCK USER ====================

  /// Get list of all blocked user IDs for a user (bidirectional)
  Future<List<String>> getBlockedUserIds(String userId) async {
    try {
      final blockedByMe = await getBlockedUsers(userId);
      final blockingMe = await getBlockers(userId);
      return {...blockedByMe, ...blockingMe}.toList();
    } catch (e) {
      debugPrint('❌ Error getting all blocked users: $e');
      return [];
    }
  }

  // ==================== EMAILS ====================

  /// Send a transactional email via Supabase Edge Function
  Future<void> sendEmail({
    required String to,
    required String subject,
    required String htmlBody,
  }) async {
    try {
      debugPrint('📧 Attempting to send email to $to via Edge Function...');

      await _supabase.functions.invoke(
        'send-email',
        body: {
          'to': to,
          'subject': subject,
          'html': htmlBody,
        },
      );

      debugPrint('✅ Email request sent successfully');
    } catch (e) {
      debugPrint('❌ Error sending email: $e');
      // Non-critical, so we don't rethrow, just log.
      // E.g. Function might not be deployed yet.
    }
  }

  // ==================== NAUGHTY QUESTIONS METHODS ====================

  /// Fetch all active naughty questions
  Future<List<NaughtyQuestion>> getNaughtyQuestions() async {
    try {
      final response = await _supabase
          .from('naughty_questions')
          .select()
          .order('display_order', ascending: true);

      return (response as List)
          .map((json) => NaughtyQuestion.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching naughty questions: $e');
      return [];
    }
  }

  /// Update conversation with selected naughty question and answer
  Future<void> updateNaughtyQuestion({
    required String conversationId,
    required String userId,
    int? questionId,
    String? answer,
  }) async {
    try {
      // 1. Get conversation to determine user side
      final conv = await _supabase
          .from('conversations')
          .select('user_a_id, user_b_id')
          .eq('id', conversationId)
          .single();

      final bool isUserA = conv['user_a_id'] == userId;
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (questionId != null) {
        // Save to the per-user question column so each user's choice is
        // independent and doesn't overwrite the other's pick.
        updates[isUserA
            ? 'user1_naughty_question_id'
            : 'user2_naughty_question_id'] = questionId;
      }

      if (answer != null) {
        updates[isUserA ? 'user1_naughty_answer' : 'user2_naughty_answer'] =
            answer;
      }

      await _supabase
          .from('conversations')
          .update(updates)
          .eq('id', conversationId);

      debugPrint(
          '✅ Conversation $conversationId updated with naughty question data');
    } catch (e) {
      debugPrint('❌ Error updating naughty question: $e');
      rethrow;
    }
  }
}
