import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../i18n/app_localizations.dart';
import '../services/upload_service.dart';
import '../services/upload_controller.dart';
import '../services/face_detection_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_text_styles.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ManageGalleryPhotosScreen extends StatefulWidget {
  const ManageGalleryPhotosScreen({super.key});

  @override
  State<ManageGalleryPhotosScreen> createState() =>
      _ManageGalleryPhotosScreenState();
}

class _ManageGalleryPhotosScreenState extends State<ManageGalleryPhotosScreen> {
  final DatabaseService _db = DatabaseService();
  final UploadService _upload = UploadService();
  late final UploadController _controller;

  final List<Map<String, dynamic>> _galleryPhotos = [];
  String? _mainPhotoUrl;
  bool _loading = false;
  double _progress = 0.0;
  
  final FaceDetectionService _faceDetector = FaceDetectionService();

  static const int _maxPhotos = 6;

  @override
  void dispose() {
    _faceDetector.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller = UploadController();
    _controller.addListener(() {
      final st = _controller.statuses.values.toList();
      if (st.isEmpty) return;
      final avg =
          st.map((s) => s.progress).fold(0.0, (a, b) => a + b) / st.length;
      setState(() => _progress = avg);
    });
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
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0AC5C5),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              tr.tr('secret_souls.main_photo_warning.set_main'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final user = AuthService().currentUser;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      // 🛡️ [MODERATION FIX]: Download and verify face before setting as main!
      final url = photo['url'] as String;
      final tempDir = await getTemporaryDirectory();
      final tempPath = p.join(tempDir.path, 'temp_main_profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
      
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final file = File(tempPath);
        await file.writeAsBytes(response.bodyBytes);
        
        // Run verification
        final faceResult = await _faceDetector.verifyFace(file);
        
        // Cleanup temp file
        if (await file.exists()) await file.delete();
        
        if (faceResult != FaceVerificationResult.success) {
          if (mounted) {
            _showFaceVerificationErrorDialog(faceResult);
          }
          return; // Block!
        }
      } else {
        throw Exception('Failed to download image for verification');
      }

      if (photo['id'] != 'main_legacy') {
        await _db.setMainPhoto(
          userId: user.id,
          photoId: photo['id'],
          photoUrl: photo['url'],
        );
      }
      // No manual _load needed, StreamBuilder handles it
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showFaceVerificationErrorDialog(FaceVerificationResult result) {
    if (result == FaceVerificationResult.success ||
        result == FaceVerificationResult.error) {
      if (result == FaceVerificationResult.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(AppLocalizations.of(context).tr('notification.error'))),
        );
      }
      return;
    }

    String titleKey;
    String messageKey;

    switch (result) {
      case FaceVerificationResult.noFace:
        titleKey = 'secret_souls.main_photo_warning.no_face_title';
        messageKey = 'secret_souls.main_photo_warning.no_face_message';
        break;
      case FaceVerificationResult.tooDistant:
        titleKey = 'secret_souls.main_photo_warning.too_distant_title';
        messageKey = 'secret_souls.main_photo_warning.too_distant_message';
        break;
      case FaceVerificationResult.notForwardFacing:
        titleKey = 'secret_souls.main_photo_warning.not_forward_title';
        messageKey = 'secret_souls.main_photo_warning.not_forward_message';
        break;
      case FaceVerificationResult.multipleFaces:
        titleKey = 'secret_souls.main_photo_warning.multiple_faces_title';
        messageKey = 'secret_souls.main_photo_warning.multiple_faces_message';
        break;
      case FaceVerificationResult.invalidOrientation:
        titleKey = 'secret_souls.main_photo_warning.invalid_orientation_title';
        messageKey =
            'secret_souls.main_photo_warning.invalid_orientation_message';
        break;
      default:
        titleKey = 'secret_souls.main_photo_warning.no_face_title';
        messageKey = 'secret_souls.main_photo_warning.no_face_message';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppLocalizations.of(context).tr(titleKey),
            style: AppTextStyles.displayText),
        content: Text(
          AppLocalizations.of(context).tr(messageKey),
          style: AppTextStyles.bodyText,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).tr('common.ok'),
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDelete(Map<String, dynamic> photo) async {
    final tr = AppLocalizations.of(context);

    // Prevent deleting Main Photo directly if it's the only one?
    // User requirement: "Define a main photo". We assume there must always be one.
    // If they delete the main photo, we lose the avatar.
    // Let's block deleting if is_main is true.
    if (photo['is_main'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)
                .tr('errors.cannot_delete_main_photo'))),
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
      // No manual _load needed, StreamBuilder handles it
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _uploadPhoto(List<Map<String, dynamic>> currentPhotos) async {
    final tr = AppLocalizations.of(context);
    if (currentPhotos.length >= _maxPhotos) {
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
          // No manual _load needed, StreamBuilder handles it
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    AppLocalizations.of(context).tr('gallery.upload_success')),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
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
    final user = AuthService().currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('User not found')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tr.tr('secret_souls.manage_photos')),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _db.profileStream(user.id),
        builder: (context, profileSnapshot) {
          final profile = profileSnapshot.data;
          final mainPhotoUrl = profile?['avatar_url'];

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _db.userPhotosStream(user.id),
            builder: (context, photosSnapshot) {
              if (photosSnapshot.connectionState == ConnectionState.waiting &&
                  !photosSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final galleryPhotos = photosSnapshot.data ?? [];

              // Build display list
              final displayList =
                  List<Map<String, dynamic>>.from(galleryPhotos);

              int mainIndex = -1;
              if (mainPhotoUrl != null) {
                mainIndex =
                    displayList.indexWhere((p) => p['url'] == mainPhotoUrl);
              }

              if (mainIndex == -1 && mainPhotoUrl != null) {
                displayList.insert(0, {
                  'id': 'main_legacy',
                  'url': mainPhotoUrl,
                  'is_main': true,
                  'show_in_secret_souls': true,
                });
              } else if (mainIndex != -1) {
                final mainItem =
                    Map<String, dynamic>.from(displayList.removeAt(mainIndex));
                mainItem['is_main'] = true;
                displayList.insert(0, mainItem);
              }

              return Column(
                children: [
                  if (_progress > 0 && _progress < 1.0)
                    LinearProgressIndicator(
                        value: _progress, color: const Color(0xFF0AC5C5)),
                  if (_loading && _progress == 0)
                    const LinearProgressIndicator(color: Color(0xFF0AC5C5)),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: displayList.length + 1, // +1 for Add button
                      itemBuilder: (context, index) {
                        if (index == displayList.length) {
                          // Add Button
                          return GestureDetector(
                            onTap: () => _uploadPhoto(displayList),
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFE0E0E0)),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add_a_photo,
                                      color: Color(0xFF737373), size: 32),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${displayList.length}/$_maxPhotos',
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

                        final photo = displayList[index];
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
                                        title: Text(tr.tr(
                                            'secret_souls.set_as_main_photo')),
                                        onTap: () {
                                          Navigator.pop(ctx);
                                          _handleSetMain(photo);
                                        },
                                      ),
                                    StatefulBuilder(
                                      builder: (context, setSheetState) {
                                        return SwitchListTile(
                                          secondary: const Icon(
                                              Icons.visibility_outlined),
                                          title: Text(tr
                                              .tr('secret_souls.toggle_label')),
                                          value:
                                              photo['show_in_secret_souls'] ==
                                                  true,
                                          activeColor: const Color(0xFF0AC5C5),
                                          onChanged: (bool value) async {
                                            setSheetState(() {
                                              photo['show_in_secret_souls'] =
                                                  value;
                                            });
                                            if (photo['id'] != 'main_legacy') {
                                              await _db
                                                  .setPhotoGalleryVisibility(
                                                photoId: photo['id'],
                                                visible: value,
                                              );
                                            } else {
                                              final user =
                                                  AuthService().currentUser;
                                              if (user != null) {
                                                await _db.updateProfile(
                                                  user.id,
                                                  {
                                                    'show_in_secret_souls':
                                                        value
                                                  },
                                                );
                                              }
                                            }
                                          },
                                        );
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.delete_outline,
                                          color: Colors.red),
                                      title: Text(
                                          tr.tr('secret_souls.delete_photo'),
                                          style: const TextStyle(
                                              color: Colors.red)),
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
                          behavior: HitTestBehavior.opaque,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  photo['url'],
                                  key: ValueKey(photo[
                                      'url']), // Important for cache busting if URL changes but not key
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.error_outline,
                                        color: Colors.grey),
                                  ),
                                ),
                              ),
                              if (isMain)
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0AC5C5),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: const [
                                        BoxShadow(
                                            blurRadius: 4,
                                            color: Colors.black26)
                                      ],
                                    ),
                                    child: Text(
                                      AppLocalizations.of(context)
                                          .tr('gallery.main_badge'),
                                      style: const TextStyle(
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
              );
            },
          );
        },
      ),
    );
  }
}
