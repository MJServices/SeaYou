import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'database_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final DatabaseService _db = DatabaseService();

  /// Request permission and update user location in database
  Future<void> updateUserLocation() async {
    try {
      final hasPermission = await _handlePermission();
      if (!hasPermission) {
        debugPrint('Location permission denied');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium, // Sufficient for regional matching (100-500m)
        ),
      );

      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        debugPrint('📍 Updating location for user ${user.id}: ${position.latitude}, ${position.longitude}');
        await _db.updateLocation(
          user.id,
          position.latitude,
          position.longitude,
        );
        debugPrint('✅ Location updated successfully in database');
      } else {
        debugPrint('⚠️ No authenticated user, skipping location update');
      }
    } catch (e) {
      debugPrint('❌ Error updating user location: $e');
      // Don't rethrow - location update is non-critical
    }
  }

  Future<bool> _handlePermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('⚠️ Location services are disabled on device');
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      debugPrint('📍 Requesting location permission...');
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('❌ Location permission denied by user');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('❌ Location permissions permanently denied - user must enable in settings');
      return false;
    }

    debugPrint('✅ Location permission granted');
    return true;
  }
}
