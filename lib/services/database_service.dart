import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
}
