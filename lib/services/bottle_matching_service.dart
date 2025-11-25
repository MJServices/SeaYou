import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bottle.dart';
import 'database_service.dart';

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

      // 2. Find eligible recipients
      final eligibleUsers = await _getEligibleRecipients(
        senderId: senderId,
        senderProfile: senderProfile,
      );

      if (eligibleUsers.isEmpty) {
        debugPrint('No eligible recipients found');
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
      scoredUsers.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

      // 4. Select from top 3 matches (add randomness among best matches)
      final topMatches = scoredUsers.take(3).toList();
      final selectedMatch = topMatches[_random.nextInt(topMatches.length)];

      final recipientId = selectedMatch['userId'] as String;
      final matchScore = selectedMatch['score'] as int;

      debugPrint('Matched bottle $bottleId to user $recipientId with score $matchScore');

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

  /// Get list of eligible recipients based on sender's preferences
  Future<List<Map<String, dynamic>>> _getEligibleRecipients({
    required String senderId,
    required Map<String, dynamic> senderProfile,
  }) async {
    try {
      final lookingFor = senderProfile['interested_in'] as String? ?? 'everyone';
      final senderOrientation = senderProfile['sexual_orientation'] as List? ?? [];
      
      // Build query for eligible users
      var query = _supabase
          .from('profiles')
          .select('id, full_name, interests, sexual_orientation, expectation, '
              'interested_in, last_active, bottles_received_today, is_active, receive_bottles')
          .neq('id', senderId)
          .eq('is_active', true)
          .eq('receive_bottles', true)
          .lt('bottles_received_today', 5) // Fair distribution limit
          .gte('last_active', DateTime.now().subtract(const Duration(days: 7)).toIso8601String());

      final results = await query as List<dynamic>;
      
      // Filter by gender preferences (client-side filtering for complex logic)
      final filtered = results.where((user) {
        final userOrientation = user['sexual_orientation'] as List? ?? [];
        final userInterestedIn = user['interested_in'] as String? ?? 'everyone';
        
        // Check if sender's preference matches user's gender
        if (lookingFor != 'everyone') {
          if (lookingFor == 'women' && !userOrientation.contains('Woman')) {
            return false;
          }
          if (lookingFor == 'men' && !userOrientation.contains('Man')) {
            return false;
          }
        }
        
        // Check if user's preference matches sender's gender
        if (userInterestedIn != 'everyone') {
          if (userInterestedIn == 'women' && !senderOrientation.contains('Woman')) {
            return false;
          }
          if (userInterestedIn == 'men' && !senderOrientation.contains('Man')) {
            return false;
          }
        }
        
        return true;
      }).toList();

      // Check for blocks
      final filteredWithoutBlocks = await _filterBlockedUsers(senderId, filtered);

      return filteredWithoutBlocks.cast<Map<String, dynamic>>();
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

      return users.where((user) => !blockedUserIds.contains(user['id'])).toList();
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
    final senderInterests = (sender['interests'] as List?)?.cast<String>() ?? [];
    final recipientInterests = (recipient['interests'] as List?)?.cast<String>() ?? [];
    
    final sharedInterests = senderInterests
        .where((interest) => recipientInterests.contains(interest))
        .length;
    score += (sharedInterests * 10).clamp(0, 50);

    // 2. Expectation alignment (0-30 points)
    final senderExpectation = sender['expectation'] as String? ?? '';
    final recipientExpectation = recipient['expectation'] as String? ?? '';
    
    if (senderExpectation == recipientExpectation) {
      score += 30;
    } else if (_areExpectationsCompatible(senderExpectation, recipientExpectation)) {
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
    final bottlesReceivedToday = recipient['bottles_received_today'] as int? ?? 0;
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

    return compatiblePairs[exp1.toLowerCase()]?.contains(exp2.toLowerCase()) ?? false;
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
}
