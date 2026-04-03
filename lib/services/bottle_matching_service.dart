import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_service.dart';

enum MatchLeniency {
  strict,
  balanced,
  relaxed,
  global,
}

/// Service for intelligent bottle matching algorithm
/// Matches bottles to compatible users based on preferences, interests, and activity
class BottleMatchingService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final DatabaseService _db = DatabaseService();
  final Random _random = Random();

  /// Main method to match a bottle to a compatible recipient
  /// Returns the recipient's user ID if match found, null otherwise
  Future<String?> matchBottle({
    required String bottleId,
    required String senderId,
  }) async {
    try {
      // 1. Get sender's profile
      final senderProfile = await _db.getProfile(senderId);
      if (senderProfile == null) {
        debugPrint('Sender profile not found');
        return null;
      }

      // 1.5. Fetch bottle details for targeting
      final bottle = await _supabase
          .from('sent_bottles')
          .select(
              'target_min_age, target_max_age, target_gender, target_departments')
          .eq('id', bottleId)
          .single();

      final int? minAge = bottle['target_min_age'];
      final int? maxAge = bottle['target_max_age'];
      final List<String> targetGender =
          (bottle['target_gender'] as List?)?.cast<String>() ?? [];
      final List<String> targetDepartments =
          (bottle['target_departments'] as List?)?.cast<String>() ?? [];

      // 2. Multi-stage matching with increasing leniency
      List<Map<String, dynamic>> eligibleUsers = [];
      MatchLeniency selectedLeniency = MatchLeniency.strict;

      final leniencyLevels = [
        MatchLeniency.strict,
        MatchLeniency.balanced,
        MatchLeniency.relaxed,
        MatchLeniency.global,
      ];

      for (final leniency in leniencyLevels) {
        debugPrint('🔍 Attempting matching with leniency: ${leniency.name}');
        eligibleUsers = await _getEligibleRecipients(
          senderId: senderId,
          senderProfile: senderProfile,
          minAge: minAge,
          maxAge: maxAge,
          targetGender: targetGender,
          targetDepartments: targetDepartments,
          leniency: leniency,
        );

        if (eligibleUsers.isNotEmpty) {
          selectedLeniency = leniency;
          debugPrint(
              '✅ Found ${eligibleUsers.length} users with ${leniency.name} leniency');
          break;
        }
      }

      if (eligibleUsers.isEmpty) {
        debugPrint('❌ No eligible recipients found even after global fallback');
        // Update status to pending
        await _supabase.from('sent_bottles').update({
          'status': 'pending',
        }).eq('id', bottleId);
        return null;
      }

      // 3. Score and rank users
      final scoredUsers = <Map<String, dynamic>>[];
      for (final user in eligibleUsers) {
        final score = _calculateMatchScore(senderProfile, user);
        scoredUsers.add({
          'userId': user['id'],
          'score': score,
          'profile': user,
        });
      }

      // Sort by score (highest first)
      scoredUsers
          .sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

      // 4. Select from top 3 matches (add randomness among best matches)
      final topMatches = scoredUsers.take(3).toList();
      final selectedMatch = topMatches[_random.nextInt(topMatches.length)];

      final recipientId = selectedMatch['userId'] as String;
      final matchScore = selectedMatch['score'] as int;

      debugPrint(
          'Matched bottle $bottleId to user $recipientId with score $matchScore (Leniency: ${selectedLeniency.name})');

      // 5. Update bottle with recipient info
      await _supabase.from('sent_bottles').update({
        'matched_recipient_id': recipientId,
        'match_score': matchScore,
        'status': 'matched',
      }).eq('id', bottleId);

      return recipientId;
    } catch (e) {
      debugPrint('Error matching bottle: $e');
      return null;
    }
  }

  /// Get list of eligible recipients based on sender's preferences and leniency level
  Future<List<Map<String, dynamic>>> _getEligibleRecipients({
    required String senderId,
    required Map<String, dynamic> senderProfile,
    int? minAge,
    int? maxAge,
    List<String> targetGender = const [],
    List<String> targetDepartments = const [],
    MatchLeniency leniency = MatchLeniency.strict,
  }) async {
    try {
      final lookingFor = senderProfile['interested_in'] as String? ?? 'everyone';
      final senderOrientation =
          senderProfile['sexual_orientation'] as List? ?? [];

      debugPrint(
          '📊 MATCHING: Sender interested_in=$lookingFor, orientation=$senderOrientation, leniency=${leniency.name}');

      // Adjust limits based on leniency
      int dailyLimit = 5;
      int activeDays = 30;

      if (leniency == MatchLeniency.balanced) {
        dailyLimit = 10;
        activeDays = 60;
      } else if (leniency == MatchLeniency.relaxed) {
        dailyLimit = 20;
        activeDays = 90;
      } else if (leniency == MatchLeniency.global) {
        dailyLimit = 50;
        activeDays = 180;
      }

      // Build query for eligible users
      var query = _supabase
          .from('profiles')
          .select('id, full_name, interests, sexual_orientation, expectation, '
              'interested_in, last_active, bottles_received_today, is_active, receive_bottles, '
              'gender, birth_year, lat, lng, department')
          .neq('id', senderId)
          .eq('is_active', true)
          .eq('receive_bottles', true)
          .lt('bottles_received_today', dailyLimit)
          .gte(
              'last_active',
              DateTime.now()
                  .subtract(Duration(days: activeDays))
                  .toIso8601String());

      final results = await query as List<dynamic>;
      debugPrint(
          '📊 MATCHING: Query (limit=$dailyLimit, days=$activeDays) returned ${results.length} active users');

      final filtered = results.where((user) {

        // 1. Gender Targeting (Strict always, as per user request)
        List<String> effectiveTargetGender = List.from(targetGender);
        if (effectiveTargetGender.isEmpty) {
          final lookingForString =
              (senderProfile['interested_in'] as String? ?? 'everyone')
                  .toLowerCase();

          if (lookingForString == 'men') {
            effectiveTargetGender = ['Man'];
          } else if (lookingForString == 'women') {
            effectiveTargetGender = ['Woman'];
          } else if (lookingForString == 'non-binary' || lookingForString == 'nonbinary') {
            effectiveTargetGender = ['Non-binary'];
          } else if (lookingForString == 'everyone') {
            effectiveTargetGender = ['Man', 'Woman', 'Non-binary'];
          }
        }

        if (effectiveTargetGender.isNotEmpty) {
          final userGender =
              (user['gender'] as String?)?.toLowerCase() ?? 'other';
          bool genderMatch = false;
          if (effectiveTargetGender.contains('Man') &&
              (userGender == 'male' ||
                  userGender == 'man' ||
                  userGender == 'homme')) {
            genderMatch = true;
          }
          if (effectiveTargetGender.contains('Woman') &&
              (userGender == 'female' ||
                  userGender == 'woman' ||
                  userGender == 'femme')) {
            genderMatch = true;
          }
          if (effectiveTargetGender.contains('Non-binary') &&
              (userGender == 'nonbinary' || userGender == 'non-binary')) {
            genderMatch = true;
          }

          if (!genderMatch) {
            return false;
          }
        }

        // 1.5. Reciprocal Matching (Does the recipient want to meet the sender?)
        // Ensure the sender's gender is acceptable to the recipient
        final recipientLookingFor =
            (user['interested_in'] as String? ?? 'everyone').toLowerCase();
        final senderGender =
            (senderProfile['gender'] as String?)?.toLowerCase() ?? 'other';

        bool reciprocalMatch = false;
        if (recipientLookingFor == 'everyone') {
          reciprocalMatch = true;
        } else if (recipientLookingFor.contains('men') &&
            (senderGender == 'male' ||
                senderGender == 'man' ||
                senderGender == 'homme')) {
          reciprocalMatch = true;
        } else if (recipientLookingFor.contains('women') &&
            (senderGender == 'female' ||
                senderGender == 'woman' ||
                senderGender == 'femme')) {
          reciprocalMatch = true;
        } else if (recipientLookingFor.contains('non-binary') ||
            recipientLookingFor.contains('nonbinary')) {
          if (senderGender == 'nonbinary' || senderGender == 'non-binary') {
            reciprocalMatch = true;
          }
        }

        if (!reciprocalMatch) {
          debugPrint(
              '⚠️ Reciprocal match failed: Recipient $recipientLookingFor, Sender was $senderGender');
          return false;
        }

        // 2. Age Targeting (Enforced at all leniency levels including global to prevent mismatching)
        if (minAge != null || maxAge != null) {
          final birthYear = user['birth_year'] as int?;
          if (birthYear == null) return false;

          final currentYear = DateTime.now().year;
          final age = currentYear - birthYear;

          if (minAge != null && age < minAge) return false;
          if (maxAge != null && age > maxAge) return false;
        }

        // 3. Department Targeting (STRICT always if specified, per user feedback)
        if (targetDepartments.isNotEmpty) {
          final userDepartment = user['department']?.toString();
          if (userDepartment == null ||
              !targetDepartments.any((d) => d.toString() == userDepartment)) {
            return false;
          }
        }

        return true;
      }).toList();

      debugPrint(
          '📊 MATCHING: After filters and leniency, ${filtered.length} eligible users');

      // Check for blocks
      final filteredWithoutBlocks =
          await _filterBlockedUsers(senderId, filtered);

      // Check for existing conversations
      final filteredWithoutExisting =
          await _filterExistingConversations(senderId, filteredWithoutBlocks);

      return filteredWithoutExisting.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error getting eligible recipients: $e');
      return [];
    }
  }

  /// Filter out blocked users
  Future<List<dynamic>> _filterBlockedUsers(
    String senderId,
    List<dynamic> users,
  ) async {
    try {
      // Get all blocks involving this sender
      final blocks = await _supabase
          .from('user_blocks')
          .select('blocker_id, blocked_id')
          .or('blocker_id.eq.$senderId,blocked_id.eq.$senderId');

      final blockedUserIds = <String>{};
      for (final block in blocks) {
        if (block['blocker_id'] == senderId) {
          blockedUserIds.add(block['blocked_id'] as String);
        } else {
          blockedUserIds.add(block['blocker_id'] as String);
        }
      }

      return users
          .where((user) => !blockedUserIds.contains(user['id']))
          .toList();
    } catch (e) {
      debugPrint('Error filtering blocked users: $e');
      return users;
    }
  }

  /// Filter out users who already have an active conversation or bottle history with the sender
  Future<List<dynamic>> _filterExistingConversations(
    String senderId,
    List<dynamic> users,
  ) async {
    try {
      final existingPartnerIds = await _db.getRepliedPartnerIds(senderId);

      return users
          .where((user) => !existingPartnerIds.contains(user['id']))
          .toList();
    } catch (e) {
      debugPrint('Error filtering existing partners: $e');
      return users;
    }
  }

  /// Calculate compatibility score between sender and recipient
  int _calculateMatchScore(
    Map<String, dynamic> sender,
    Map<String, dynamic> recipient,
  ) {
    int score = 0;

    // 1. Shared interests (0-50 points)
    final senderInterests =
        (sender['interests'] as List?)?.cast<String>() ?? [];
    final recipientInterests =
        (recipient['interests'] as List?)?.cast<String>() ?? [];

    final sharedInterests = senderInterests
        .where((interest) => recipientInterests.contains(interest))
        .length;
    score += (sharedInterests * 10).clamp(0, 50);

    // 2. Expectation alignment (0-30 points)
    final senderExpectation = sender['expectation'] as String? ?? '';
    final recipientExpectation = recipient['expectation'] as String? ?? '';

    if (senderExpectation == recipientExpectation) {
      score += 30;
    } else if (_areExpectationsCompatible(
        senderExpectation, recipientExpectation)) {
      score += 15;
    }

    // 3. Activity recency (0-20 points)
    final lastActive = recipient['last_active'] != null
        ? DateTime.parse(recipient['last_active'] as String)
        : DateTime.now().subtract(const Duration(days: 365));

    final hoursSinceActive = DateTime.now().difference(lastActive).inHours;
    if (hoursSinceActive < 24) {
      score += 20;
    } else if (hoursSinceActive < 72) {
      score += 10;
    } else if (hoursSinceActive < 168) {
      score += 5;
    }

    // 4. Balance factor (0-10 points)
    // Favor users who have received fewer bottles today
    final bottlesReceivedToday =
        recipient['bottles_received_today'] as int? ?? 0;
    if (bottlesReceivedToday == 0) {
      score += 10;
    } else if (bottlesReceivedToday == 1) {
      score += 5;
    }

    // 5. Randomization factor (0-10 points)
    // Add slight randomness to prevent always matching same users
    score += _random.nextInt(11);

    return score;
  }

  /// Check if two expectations are compatible
  bool _areExpectationsCompatible(String exp1, String exp2) {
    // Define compatible expectations
    const compatiblePairs = {
      'serious': ['serious', 'long-term', 'relationship'],
      'casual': ['casual', 'friendship', 'fun', 'dating'],
      'friendship': ['friendship', 'casual', 'fun'],
      'long-term': ['long-term', 'serious', 'relationship'],
      'relationship': ['relationship', 'serious', 'long-term'],
    };

    return compatiblePairs[exp1.toLowerCase()]?.contains(exp2.toLowerCase()) ??
        false;
  }

  /// Schedule bottle delivery (for "floating in sea" effect)
  /// Returns scheduled delivery time
  Future<DateTime> scheduleBottleDelivery({
    required String bottleId,
    required String senderId,
    required String recipientId,
  }) async {
    // Random delay between 1-5 minutes for realistic "floating" effect
    final delayMinutes = 1 + _random.nextInt(5);
    final scheduledTime = DateTime.now().add(Duration(minutes: delayMinutes));

    await _supabase.from('bottle_delivery_queue').insert({
      'sent_bottle_id': bottleId,
      'sender_id': senderId,
      'recipient_id': recipientId,
      'scheduled_delivery_at': scheduledTime.toIso8601String(),
      'delivered': false,
    });

    debugPrint('Bottle $bottleId scheduled for delivery at $scheduledTime');
    return scheduledTime;
  }

  /// Deliver bottles that are ready (scheduled time has passed)
  /// This should be called periodically (e.g., every minute)
  Future<void> deliverPendingBottles() async {
    try {
      // Get bottles ready for delivery
      final pendingBottles = await _supabase
          .from('bottle_delivery_queue')
          .select('*')
          .eq('delivered', false)
          .lte('scheduled_delivery_at', DateTime.now().toIso8601String());

      for (final queueItem in pendingBottles) {
        await _deliverBottle(queueItem);
      }
    } catch (e) {
      debugPrint('Error delivering pending bottles: $e');
    }
  }

  /// Deliver a single bottle
  Future<void> _deliverBottle(Map<String, dynamic> queueItem) async {
    try {
      final bottleId = queueItem['sent_bottle_id'] as String;
      final recipientId = queueItem['recipient_id'] as String;

      // Update sent bottle status
      await _supabase.from('sent_bottles').update({
        'status': 'delivered',
        'delivered_at': DateTime.now().toIso8601String(),
      }).eq('id', bottleId);

      // Mark delivery queue item as delivered
      await _supabase.from('bottle_delivery_queue').update({
        'delivered': true,
        'delivered_at': DateTime.now().toIso8601String(),
      }).eq('id', queueItem['id']);

      // Increment recipient's bottles_received_today counter
      await _supabase.rpc('increment_bottles_received', params: {
        'user_id': recipientId,
      });

      debugPrint('Bottle $bottleId delivered to $recipientId');
    } catch (e) {
      debugPrint('Error delivering bottle: $e');
    }
  }

  /// Automatically match pending bottles for a user who just became active
  /// This implements the "re-matching" logic for bottles that didn't find a match immediately
  Future<void> autoMatchPendingBottlesForUser(String recipientId) async {
    void log(String msg) {
      debugPrint('🔄 Background: $msg');
    }

    try {
      log('Checking for pending bottles for user $recipientId');
      
      // 1. Get recipient profile
      final recipientProfile = await _db.getProfile(recipientId);
      if (recipientProfile == null) {
        debugPrint('⏹️ Re-match: Profile not found for $recipientId');
        return;
      }

      if (recipientProfile['receive_bottles'] == false) {
        debugPrint('⏹️ Re-match: User has "receive_bottles" disabled');
        return;
      }

      // 2. Check daily limits
      final int receivedToday = recipientProfile['bottles_received_today'] ?? 0;
      final int limit = 5; 
      if (receivedToday >= limit) {
        debugPrint('⏹️ Re-match: User reached daily limit ($receivedToday/$limit)');
        return;
      }

      // 3. Query pending bottles (from others)
      // We look for both 'pending' and 'floating' status bottles. 
      // 'floating' is the default in the database for unmatched bottles.
      final pendingBottles = await _supabase
          .from('sent_bottles')
          .select('*')
          .inFilter('status', ['pending', 'floating'])
          .neq('sender_id', recipientId)
          .order('created_at', ascending: false)
          .limit(20);

      if (pendingBottles.isEmpty) {
        debugPrint('📭 Re-match: No pending/floating bottles found in sea');
        return;
      }

      debugPrint('🔍 Re-match: Analyzing ${pendingBottles.length} candidates...');

      int deliveredCount = 0;
      for (final bottle in pendingBottles) {
        if (deliveredCount >= (limit - receivedToday)) break;

        final String bottleId = bottle['id'];
        
        // 4. Check if this bottle was ALREADY delivered or matched to THIS user
        // even if it failed before, we check the queue for safety
        final existingMatch = await _supabase
            .from('bottle_delivery_queue')
            .select('id')
            .eq('sent_bottle_id', bottleId)
            .eq('recipient_id', recipientId)
            .maybeSingle();

        if (existingMatch != null) {
          log('SKIPPED: Already matched/delivered to this user via queue');
          continue;
        }

        // 5. Detailed compatibility check with logging
        final bool isCompatible = await _isRecipientCompatibleWithBottle(
          recipientProfile: recipientProfile,
          bottle: bottle,
          verbose: true, // Enable detailed debug logs
        );

        if (isCompatible) {
          debugPrint('🎯 Re-match SUCCESS! Delivering bottle $bottleId');
          
          await _deliverBottleInstantly(
            bottleId: bottleId,
            senderId: bottle['sender_id'],
            recipientId: recipientId,
            bottleData: bottle,
          );
          
          deliveredCount++;
        }
      }

      debugPrint('🏁 Re-match finished. Delivered: $deliveredCount');
    } catch (e) {
      debugPrint('❌ Error in auto-match: $e');
    }
  }

  /// Check if a recipient is compatible with a specific bottle's targeting
  Future<bool> _isRecipientCompatibleWithBottle({
    required Map<String, dynamic> recipientProfile,
    required Map<String, dynamic> bottle,
    bool verbose = false,
  }) async {
    final String bottleId = bottle['id'];
    final String senderId = bottle['sender_id'];

    void log(String msg) {
      if (verbose) debugPrint('   [Bottle $bottleId] $msg');
    }

    try {
      // 1. Fetch sender profile
      final senderProfile = await _db.getProfile(senderId);
      if (senderProfile == null) {
        log('REJECTED: Sender profile not found');
        return false;
      }

      // 2. Check blocks
      final blocks = await _supabase
          .from('user_blocks')
          .select('id')
          .or('blocker_id.eq.$senderId,blocked_id.eq.$senderId')
          .or('blocker_id.eq.${recipientProfile['id']},blocked_id.eq.${recipientProfile['id']}');
      
      if (blocks.isNotEmpty) {
        log('REJECTED: Block relationship exists');
        return false;
      }

      // 3. Check existing conversations or replies
      final existingPartners = await _db.getRepliedPartnerIds(senderId);
      if (existingPartners.contains(recipientProfile['id'])) {
        log('REJECTED: Already in contact');
        return false;
      }

      // 4. Normalization Helpers
      String normalizeGender(dynamic g) {
        final String s = (g?.toString() ?? '').toLowerCase();
        if (s == 'male' || s == 'man' || s == 'homme') return 'man';
        if (s == 'female' || s == 'woman' || s == 'femme') return 'woman';
        if (s == 'nonbinary' || s == 'non-binary' || s == 'nb') return 'non-binary';
        return s;
      }

      // 5. Gender Targeting (Sender -> Recipient)
      final List<String> targetGenders = (bottle['target_gender'] as List?)?.cast<String>() ?? [];
      final recipientGender = normalizeGender(recipientProfile['gender']);
      
      if (targetGenders.isNotEmpty) {
        bool genderMatch = false;
        for (final target in targetGenders) {
          if (normalizeGender(target) == recipientGender) {
            genderMatch = true;
            break;
          }
        }
        if (!genderMatch) {
          log('REJECTED: Recipient gender ($recipientGender) not in targeting $targetGenders');
          return false;
        }
      } else {
        // Fallback to sender's general preference
        final senderLookingFor = (senderProfile['interested_in']?.toString() ?? 'everyone').toLowerCase();
        bool lookingForMatch = false;
        if (senderLookingFor == 'everyone') {
          lookingForMatch = true;
        } else if (senderLookingFor.contains('men') && recipientGender == 'man') {
          lookingForMatch = true;
        } else if (senderLookingFor.contains('women') && recipientGender == 'woman') {
          lookingForMatch = true;
        } else if ((senderLookingFor.contains('non-binary') || senderLookingFor.contains('nonbinary')) && recipientGender == 'non-binary') {
          lookingForMatch = true;
        }
        
        if (!lookingForMatch) {
          log('REJECTED: Sender looking for "$senderLookingFor", Recipient is "$recipientGender"');
          return false;
        }
      }

      // 6. Reciprocal Matching (Recipient -> Sender)
      final recipientLookingFor = (recipientProfile['interested_in']?.toString() ?? 'everyone').toLowerCase();
      final senderGender = normalizeGender(senderProfile['gender']);
      
      bool reciprocalMatch = false;
      if (recipientLookingFor == 'everyone') {
        reciprocalMatch = true;
      } else if (recipientLookingFor.contains('men') && senderGender == 'man') {
        reciprocalMatch = true;
      } else if (recipientLookingFor.contains('women') && senderGender == 'woman') {
        reciprocalMatch = true;
      } else if ((recipientLookingFor.contains('non-binary') || recipientLookingFor.contains('nonbinary')) && senderGender == 'non-binary') {
        reciprocalMatch = true;
      }
      
      if (!reciprocalMatch) {
        log('REJECTED: Recipient looking for "$recipientLookingFor", Sender is "$senderGender"');
        return false;
      }

      // 7. Age targeting
      final int? minAge = bottle['target_min_age'];
      final int? maxAge = bottle['target_max_age'];
      if (minAge != null || maxAge != null) {
        final birthYear = recipientProfile['birth_year'] as int?;
        if (birthYear == null) {
          log('REJECTED: Recipient has no birth_year');
          return false;
        }
        final age = DateTime.now().year - birthYear;
        if (minAge != null && age < minAge) {
          log('REJECTED: Recipient age ($age) < target min ($minAge)');
          return false;
        }
        if (maxAge != null && age > maxAge) {
          log('REJECTED: Recipient age ($age) > target max ($maxAge)');
          return false;
        }
      }

      // 8. Department targeting
      final List<String> targetDepts = (bottle['target_departments'] as List?)?.cast<String>() ?? [];
      if (targetDepts.isNotEmpty) {
        // Robust string comparison for IDs
        final userDept = recipientProfile['department']?.toString();
        if (userDept == null) {
          log('REJECTED: Recipient has no department');
          return false;
        }
        
        final bool deptMatch = targetDepts.any((d) => d.toString() == userDept);
        if (!deptMatch) {
          log('REJECTED: Recipient dept ($userDept) not in targeting $targetDepts');
          return false;
        }
      }

      return true;
    } catch (e) {
      log('ERROR: $e');
      return false;
    }
  }

  /// Deliver a bottle instantly and record it in the proper queue
  Future<void> _deliverBottleInstantly({
    required String bottleId,
    required String senderId,
    required String recipientId,
    required Map<String, dynamic> bottleData,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();

      // 1. Create received bottle record
      await _db.createReceivedBottle(
        bottleId: bottleId,
        receiverId: recipientId,
        senderId: senderId,
        contentType: bottleData['content_type'] ?? 'text',
        message: bottleData['message'],
        mood: bottleData['mood'] ?? 'Dreamy',
        audioUrl: bottleData['audio_url'],
        photoUrl: bottleData['photo_url'],
      );

      // 2. Update sent bottle status
      await _supabase.from('sent_bottles').update({
        'matched_recipient_id': recipientId,
        'status': 'delivered',
        'delivered_at': now,
      }).eq('id', bottleId);

      // 3. Record in bottle_delivery_queue (mark as already delivered)
      // This respects the "proper" table as per user feedback
      await _supabase.from('bottle_delivery_queue').insert({
        'sent_bottle_id': bottleId,
        'sender_id': senderId,
        'recipient_id': recipientId,
        'scheduled_delivery_at': now,
        'delivered': true,
        'delivered_at': now,
        'created_at': now,
      });

      // 4. Increment counters via RPC
      await _supabase.rpc('increment_bottles_received', params: {
        'user_id': recipientId,
      });

      debugPrint('🚀 Instant background delivery complete for bottle $bottleId (Queue updated)');
    } catch (e) {
      debugPrint('Error in instant delivery: $e');
    }
  }
}
