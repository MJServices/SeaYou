import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../i18n/app_localizations.dart';
import '../services/upload_service.dart';
import '../services/upload_controller.dart';
import 'dart:io';

class ManageGalleryPhotosScreen extends StatefulWidget {
  const ManageGalleryPhotosScreen({super.key});

  @override
  State<ManageGalleryPhotosScreen> createState() => _ManageGalleryPhotosScreenState();
}

class _ManageGalleryPhotosScreenState extends State<ManageGalleryPhotosScreen> {
  final DatabaseService _db = DatabaseService();
  final UploadService _upload = UploadService();
  late final UploadController _controller;
  
  List<Map<String, dynamic>> _galleryPhotos = [];
  String? _mainPhotoUrl;
  bool _loading = false;
  double _progress = 0.0;
  
  static const int _maxPhotos = 6;

  @override
  void initState() {
    super.initState();
    _controller = UploadController();
    _controller.addListener(() {
      final st = _controller.statuses.values.toList();
      if (st.isEmpty) return;
      final avg = st.map((s) => s.progress).fold(0.0, (a, b) => a + b) / st.length;
      setState(() => _progress = avg);
    });
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = AuthService().currentUser;
    if (user != null) {
      // 1. Get Main Photo URL
      final profile = await _db.getProfile(user.id);
      _mainPhotoUrl = profile?['avatar_url'];

      // 2. Get Gallery Photos
      _galleryPhotos = await _db.listUserPhotos(user.id);
    }
    setState(() => _loading = false);
  }

  int get _totalPhotos {
    // We count unique URLs. 
    // If main photo is in gallery photos, we shouldn't double count.
    // However, our logic separates them: 'profiles.avatar_url' vs 'profile_photos' table.
    // Ideally, the main photo matches one entry in 'profile_photos'.
    // If it doesn't (legacy), we count it as +1.
    
    // Let's create a visual list where Main Photo is explicitly identified from the gallery list
    // OR added if missing.
    return _buildDisplayList().length;
  }

  List<Map<String, dynamic>> _buildDisplayList() {
     // Start with gallery photos
     final list = List<Map<String, dynamic>>.from(_galleryPhotos);
     
     // Find which one is main
     int mainIndex = -1;
     if (_mainPhotoUrl != null) {
       mainIndex = list.indexWhere((p) => p['url'] == _mainPhotoUrl);
     }

     // If main exists but not in list (legacy data), add it
     if (mainIndex == -1 && _mainPhotoUrl != null) {
       list.insert(0, {
         'id': 'main_legacy',
         'url': _mainPhotoUrl,
         'is_main': true,
         'show_in_secret_souls': true, 
       });
     } else if (mainIndex != -1) {
       // Move main to top
       final mainItem = list.removeAt(mainIndex);
       mainItem['is_main'] = true;
       list.insert(0, mainItem);
     }

     return list;
  }

  Future<void> _handleSetMain(Map<String, dynamic> photo) async {
    final tr = AppLocalizations.of(context);
    
    // Mandatory Pop-up
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 8),
            Text(tr.tr('secret_souls.main_photo_warning.title')),
          ],
        ),
        content: Text(tr.tr('secret_souls.main_photo_warning.message')),
        actions: [
          TextButton(
             onPressed: () => Navigator.pop(context, false),
             child: Text(tr.tr('secret_souls.main_photo_warning.cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0AC5C5)),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr.tr('secret_souls.main_photo_warning.set_main')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final user = AuthService().currentUser;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      if (photo['id'] != 'main_legacy') {
        await _db.setMainPhoto(
          userId: user.id,
          photoId: photo['id'],
          photoUrl: photo['url'],
        );
      }
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => _loading = false);
  }

  Future<void> _handleDelete(Map<String, dynamic> photo) async {
    final tr = AppLocalizations.of(context);
    
    // Prevent deleting Main Photo directly if it's the only one?
    // User requirement: "Define a main photo". We assume there must always be one.
    // If they delete the main photo, we lose the avatar.
    // Let's block deleting if is_main is true.
    if (photo['is_main'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot delete your Main Photo. Please set another photo as Main first.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr.tr('secret_souls.delete_photo')),
        content: Text(tr.tr('secret_souls.delete_confirmation')),
        actions: [
           TextButton(
             onPressed: () => Navigator.pop(context, false),
             child: Text(tr.tr('secret_souls.cancel')),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr.tr('secret_souls.delete')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final user = AuthService().currentUser;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      if (photo['id'] != 'main_legacy') {
        await _db.deletePhoto(
          userId: user.id,
          photoId: photo['id'],
          photoUrl: photo['url'],
        );
      }
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => _loading = false);
  }

  Future<void> _uploadPhoto() async {
    final tr = AppLocalizations.of(context);
    final displayList = _buildDisplayList();
    if (displayList.length >= _maxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr.tr('secret_souls.photo_limit_reached'))),
      );
      return;
    }

    final user = AuthService().currentUser;
    if (user == null) return;

    final file = await _upload.pickFromGallery();
    if (file != null) {
      final f = File(file.path);
      
      setState(() {
        _loading = true;
        _progress = 0.1;
      }); 
      
      try {
       final url = await _db.uploadGalleryPhoto(user.id, f);
        if (url != null && mounted) {
          // Reload photos from database
          await _load();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Photo uploaded successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _loading = false;
            _progress = 0.0;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context);
    final photos = _buildDisplayList();

    return Scaffold(
      appBar: AppBar(
        title: Text(tr.tr('secret_souls.manage_photos')),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_progress > 0 && _progress < 1.0)
                  LinearProgressIndicator(value: _progress, color: const Color(0xFF0AC5C5)),
                
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: photos.length + 1, // +1 for Add button
                    itemBuilder: (context, index) {
                      if (index == photos.length) {
                        // Add Button
                        return GestureDetector(
                          onTap: _uploadPhoto,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE0E0E0)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_a_photo, color: Color(0xFF737373), size: 32),
                                const SizedBox(height: 8),
                                Text(
                                  '${photos.length}/$_maxPhotos',
                                  style: const TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 12,
                                    color: Color(0xFF737373),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final photo = photos[index];
                      final isMain = photo['is_main'] == true;
                      
                      return GestureDetector(
                        onTap: () {
                          // Show Actions Bottom Sheet
                          showModalBottomSheet(
                            context: context,
                            builder: (ctx) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isMain)
                                    ListTile(
                                      leading: const Icon(Icons.star_outline),
                                      title: Text(tr.tr('secret_souls.set_as_main_photo')),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        _handleSetMain(photo);
                                      },
                                    ),
                                  ListTile(
                                    leading: const Icon(Icons.delete_outline, color: Colors.red),
                                    title: Text(tr.tr('secret_souls.delete_photo'), style: const TextStyle(color: Colors.red)),
                                    onTap: () {
                                       Navigator.pop(ctx);
                                       _handleDelete(photo);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                photo['url'],
                                fit: BoxFit.cover,
                                errorBuilder: (_,__,___) => Container(color: Colors.grey[200]),
                              ),
                            ),
                            if (isMain)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0AC5C5),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
                                  ),
                                  child: const Text(
                                    'MAIN',
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

