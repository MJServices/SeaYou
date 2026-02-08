import 'dart:io';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/foundation.dart';

class FaceDetectionService {
  late final FaceDetector _faceDetector;

  FaceDetectionService() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
      ),
    );
  }

  /// Detects if there is at least one face in the given image file.
  Future<bool> hasFace(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final List<Face> faces = await _faceDetector.processImage(inputImage);
      return faces.isNotEmpty;
    } catch (e) {
      debugPrint('Error during face detection: $e');
      // In case of error, we might want to default to true to not block the user
      // or false to be strict. Let's go with true but log it.
      return true;
    }
  }

  /// Closes the detector and releases its resources.
  void dispose() {
    _faceDetector.close();
  }
}
