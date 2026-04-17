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

  // Efficiency Cache: Avoid redundant historical lookups in a single session
  static final Map<String, List<String>> _historicalRecipientsCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheDuration = Duration(minutes: 5);

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

      // 1.5. Fetch bottle details for targeting and status check
      final bottle = await _supabase
          .from('sent_bottles')
          .select(
              'target_min_age, target_max_age, target_gender, target_departments, matched_recipient_id, status')
          .eq('id', bottleId)
          .single();

      // DUPLICATION GUARD:
      // If the bottle is already matched or delivered, return the existing recipient ID
      final existingRecipient = bottle['matched_recipient_id'] as String?;
      final status = bottle['status'] as String?;
      if (existingRecipient != null &&
          (status == 'matched' || status == 'delivered' || status == 'read')) {
        debugPrint(
            '🛡️ Duplication Guard: Bottle $bottleId already matched to $existingRecipient. Skipping.');
        return existingRecipient;
      }

      final int? minAge = bottle['target_min_age'];
      final int? maxAge = bottle['target_max_age'];
      final List<String> targetGender =
          (bottle['target_gender'] as List?)?.cast<String>() ?? [];
      final List<String> targetDepartments =
          (bottle['target_departments'] as List?)?.cast<String>() ?? [];

      // 2. Fetch exclusion lists (Conversations + historical matches)
      // ⚡ EFFICIENCY: Use local cache if fresh (5 min) to avoid slamming DB
      final now = DateTime.now();
      List<String> historyIds;
      
      if (_historicalRecipientsCache.containsKey(senderId) && 
          now.difference(_cacheTimestamps[senderId]!) < _cacheDuration) {
        historyIds = _historicalRecipientsCache[senderId]!;
        debugPrint('⚡ Matching: Using cached historical recipients for $senderId');
      } else {
        historyIds = await _db.getHistoricalRecipientIds(senderId);
        _historicalRecipientsCache[senderId] = historyIds;
        _cacheTimestamps[senderId] = now;
      }

      final conversationIds = await _db.getRepliedPartnerIds(senderId);
      
      final Set<String> allExclusionIds = {
        ...historyIds,
        ...conversationIds,
      };

      debugPrint('🛡️ Total exclusion list for sender: ${allExclusionIds.length} users');

      List<Map<String, dynamic>> eligibleUsers = [];
      MatchLeniency selectedLeniency = MatchLeniency.strict;

      final leniencyLevels = [
        MatchLeniency.strict,
        MatchLeniency.balanced,
        MatchLeniency.relaxed,
        MatchLeniency.global,
      ];

      final bool hasSpecificTargeting = minAge != null ||
          maxAge != null ||
          targetGender.isNotEmpty ||
          targetDepartments.isNotEmpty;

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
          exclusionIds: allExclusionIds,
        );

        if (eligibleUsers.isNotEmpty) {
          selectedLeniency = leniency;
          debugPrint(
              '✅ Found ${eligibleUsers.length} users with ${leniency.name} leniency');
          break;
        }

        // ⚡ REGRESSION FIX:
        // If the user has specified strict targeting (Age, Department, or Gender),
        // we DO NOT fall back to higher leniency levels. The bottle should
        // stay 'pending/floating' until a truly compatible user matches.
        if (hasSpecificTargeting) {
          debugPrint(
              '🚫 Strict targeting detected for $bottleId: Skipping fallback leniency levels to ensure criteria compliance.');
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
    Set<String>? exclusionIds,
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
          
          if (userGender == 'nonbinary' || userGender == 'non-binary') {
            genderMatch = true; // Wildcard recipient
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
        if (recipientLookingFor == 'everyone' || recipientLookingFor.contains('everyone') || recipientLookingFor == 'all' || senderGender == 'nonbinary' || senderGender == 'non-binary') {
          reciprocalMatch = true;
        } else if ((recipientLookingFor == 'women' || recipientLookingFor == 'female' || recipientLookingFor == 'femme') &&
            (senderGender == 'female' ||
                senderGender == 'woman' ||
                senderGender == 'femme')) {
          reciprocalMatch = true;
        } else if ((recipientLookingFor == 'men' || recipientLookingFor == 'male' || recipientLookingFor == 'homme') &&
            (senderGender == 'male' ||
                senderGender == 'man' ||
                senderGender == 'homme')) {
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

      // Check for existing conversations and historical matches
      // ⚡ STICKY REGRESSION FIX:
      // Per latest user feedback, NO user should receive multiple bottles from the same sender.
      // This filter is now absolute.
      final filteredStrict = filteredWithoutBlocks
          .where((user) => !(exclusionIds?.contains(user['id'] ?? '') ?? false))
          .toList();

      return filteredStrict.cast<Map<String, dynamic>>();
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
    bool isImmediate = false,
  }) async {
    // ⚡ EFFICIENCY FIX: 
    // If isImmediate (e.g. Premium) -> 0 delay.
    // Otherwise -> 5-15 seconds (reduced from 1-5 minutes for better UX).
    final delaySeconds = isImmediate ? 0 : 5 + _random.nextInt(11);
    final scheduledTime = DateTime.now().add(Duration(seconds: delaySeconds));

    // DUPLICATION GUARD: Check if already in queue or already delivered
    final existingQueue = await _supabase
        .from('bottle_delivery_queue')
        .select('id')
        .eq('sent_bottle_id', bottleId)
        .maybeSingle();

    if (existingQueue != null) {
      debugPrint('🛡️ scheduleBottleDelivery: Bottle $bottleId already in delivery queue. Skipping.');
      return scheduledTime; // Re-use time (approximate)
    }

    await _supabase.from('bottle_delivery_queue').insert({
      'sent_bottle_id': bottleId,
      'sender_id': senderId,
      'recipient_id': recipientId,
      'scheduled_delivery_at': scheduledTime.toIso8601String(),
      'delivered': false,
    });

    debugPrint('Bottle $bottleId scheduled for delivery at $scheduledTime (Delay: $delaySeconds)');
    
    // If it's immediate, trigger delivery check now for best performance
    if (isImmediate) {
      deliverPendingBottles();
    }
    
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
      log('Triggering secure re-match for user $recipientId...');
      
      // 1. Call SQL RPC to handle matching and delivery in one secure transaction
      // This bypasses RLS issues (SECURITY DEFINER) and ensures atomicity
      final int matchesFound = await _supabase.rpc(
        'try_match_pending_bottles_for_user', 
        params: {'target_user_id': recipientId}
      );

      if (matchesFound > 0) {
        log('🎯 SUCCESS: $matchesFound bottles delivered instantly via background re-match.');
      } else {
        log('📭 No compatible pending/floating bottles found at this time.');
      }
      
      log('🏁 Re-match check finished.');
    } catch (e) {
      debugPrint('❌ Error in auto-match RPC: $e');
    }
  }
}
