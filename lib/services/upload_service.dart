import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class UploadResult {
  final String bucket;
  final String path;
  final String url;
  const UploadResult({required this.bucket, required this.path, required this.url});
}

class UploadService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  Future<XFile?> pickFromGallery({int maxWidth = 1920, int maxHeight = 1920, int quality = 85}) async {
    try {
      return await _picker.pickImage(source: ImageSource.gallery, maxWidth: maxWidth.toDouble(), maxHeight: maxHeight.toDouble(), imageQuality: quality);
    } catch (e) {
      debugPrint('pickFromGallery error: $e');
      return null;
    }
  }

  Future<XFile?> pickFromCamera({int maxWidth = 1920, int maxHeight = 1920, int quality = 85}) async {
    try {
      return await _picker.pickImage(source: ImageSource.camera, maxWidth: maxWidth.toDouble(), maxHeight: maxHeight.toDouble(), imageQuality: quality);
    } catch (e) {
      debugPrint('pickFromCamera error: $e');
      return null;
    }
  }

  Future<UploadResult?> uploadFile({required String bucket, required String userId, required File file, String prefix = 'content', String? cacheControl}) async {
    try {
      final ext = file.path.split('.').last;
      final path = buildPath(userId: userId, prefix: prefix, ext: ext);
      
      debugPrint('📤 Starting upload to bucket: $bucket, path: $path');
      debugPrint('📁 File exists: ${await file.exists()}, size: ${await file.length()} bytes');
      
      await _supabase.storage.from(bucket).upload(
        path, 
        file, 
        fileOptions: FileOptions(
          cacheControl: cacheControl ?? '3600', 
          upsert: false
        )
      );
      
      final url = _supabase.storage.from(bucket).getPublicUrl(path);
      debugPrint('✅ Upload successful! URL: $url');
      return UploadResult(bucket: bucket, path: path, url: url);
    } catch (e, stackTrace) {
      debugPrint('❌ uploadFile error: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  static String buildPath({required String userId, required String prefix, required String ext}) {
    return '$userId/${prefix}_${DateTime.now().millisecondsSinceEpoch}.$ext';
  }
}
