import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import 'blocked_users_screen.dart';
import 'splash_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final SupabaseClient _supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _preferences;
  
  String _acceptFromGender = 'everyone';
  int _minAge = 18;
  int _maxAge = 100;
  int _maxBottlesPerDay = 5;
  bool _notifyOnReceived = true;
  bool _notifyOnRead = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Load user profile and preferences
      final results = await Future.wait([
        _databaseService.getProfile(userId),
        _databaseService.getUserPreferences(userId),
      ]);

      if (mounted) {
        setState(() {
          _userProfile = results[0] as Map<String, dynamic>?;
          _preferences = results[1] as Map<String, dynamic>?;

          // Set preferences if they exist
          if (_preferences != null) {
            _acceptFromGender = _preferences!['accept_from_gender'] ?? 'everyone';
            _minAge = _preferences!['accept_from_age_min'] ?? 18;
            _maxAge = _preferences!['accept_from_age_max'] ?? 100;
            _maxBottlesPerDay = _preferences!['max_bottles_per_day'] ?? 5;
            _notifyOnReceived = _preferences!['notify_on_bottle_received'] ?? true;
            _notifyOnRead = _preferences!['notify_on_bottle_read'] ?? true;
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _savePreferences() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _databaseService.upsertUserPreferences(
        userId: userId,
        acceptFromGender: _acceptFromGender,
        acceptFromAgeMin: _minAge,
        acceptFromAgeMax: _maxAge,
        maxBottlesPerDay: _maxBottlesPerDay,
        notifyOnBottleReceived: _notifyOnReceived,
        notifyOnBottleRead: _notifyOnRead,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferences saved successfully'),
            backgroundColor: Color(0xFF0AC5C5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving preferences: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }



  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthService().signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SplashScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF151515)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF151515),
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0AC5C5)),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  // Profile Section
                  _buildProfileSection(),

                  const SizedBox(height: 32),

                  // Receiving Preferences
                  _buildSectionTitle('Receiving Preferences'),
                  _buildPreferenceCard(),

                  const SizedBox(height: 24),

                  // Privacy
                  _buildSectionTitle('Privacy'),
                  _buildPrivacyCard(),

                  const SizedBox(height: 24),

                  // Account
                  _buildSectionTitle('Account'),
                  _buildAccountCard(),

                  const SizedBox(height: 32),

                  // Save Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _savePreferences,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0AC5C5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Save Preferences',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(
                image: _userProfile?['avatar_url'] != null
                    ? NetworkImage(_userProfile!['avatar_url'])
                    : const AssetImage('assets/images/profile_avatar.png')
                        as ImageProvider,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Name and email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userProfile?['full_name'] ?? 'User',
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF151515),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _userProfile?['email'] ?? '',
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF737373),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF151515),
        ),
      ),
    );
  }

  Widget _buildPreferenceCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFCFCFC),
          border: Border.all(color: const Color(0xFFE3E3E3), width: 0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Accept bottles from
            const Text(
              'Accept bottles from:',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF151515),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _acceptFromGender,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE3E3E3)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'everyone', child: Text('Everyone')),
                DropdownMenuItem(value: 'men', child: Text('Men only')),
                DropdownMenuItem(value: 'women', child: Text('Women only')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _acceptFromGender = value;
                  });
                }
              },
            ),

            const SizedBox(height: 20),

            // Age range
            Text(
              'Age range: $_minAge - $_maxAge',
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF151515),
              ),
            ),
            const SizedBox(height: 12),
            RangeSlider(
              values: RangeValues(_minAge.toDouble(), _maxAge.toDouble()),
              min: 18,
              max: 100,
              divisions: 82,
              activeColor: const Color(0xFF0AC5C5),
              labels: RangeLabels(_minAge.toString(), _maxAge.toString()),
              onChanged: (values) {
                setState(() {
                  _minAge = values.start.round();
                  _maxAge = values.end.round();
                });
              },
            ),

            const SizedBox(height: 20),

            // Max bottles per day
            Text(
              'Max bottles per day: $_maxBottlesPerDay',
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF151515),
              ),
            ),
            const SizedBox(height: 12),
            Slider(
              value: _maxBottlesPerDay.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              activeColor: const Color(0xFF0AC5C5),
              label: _maxBottlesPerDay.toString(),
              onChanged: (value) {
                setState(() {
                  _maxBottlesPerDay = value.round();
                });
              },
            ),

            const SizedBox(height: 20),

            // Notifications
            SwitchListTile(
              title: const Text(
                'Notify when bottle received',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF151515),
                ),
              ),
              value: _notifyOnReceived,
              activeColor: const Color(0xFF0AC5C5),
              onChanged: (value) {
                setState(() {
                  _notifyOnReceived = value;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),

            SwitchListTile(
              title: const Text(
                'Notify when bottle read',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF151515),
                ),
              ),
              value: _notifyOnRead,
              activeColor: const Color(0xFF0AC5C5),
              onChanged: (value) {
                setState(() {
                  _notifyOnRead = value;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFCFCFC),
          border: Border.all(color: const Color(0xFFE3E3E3), width: 0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ListTile(
          leading: const Icon(Icons.block, color: Color(0xFF151515)),
          title: const Text(
            'Blocked Users',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF151515),
            ),
          ),
          trailing: const Icon(Icons.chevron_right, color: Color(0xFF737373)),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BlockedUsersScreen(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAccountCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFCFCFC),
          border: Border.all(color: const Color(0xFFE3E3E3), width: 0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.language, color: Color(0xFF151515)),
              title: const Text(
                'Language',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF151515),
                ),
              ),
              trailing: Text(
                _userProfile?['language'] ?? 'English',
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF737373),
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Logout',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.red,
                ),
              ),
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }
}
