import 'dart:io';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/foundation.dart';

enum FaceVerificationResult {
  noFace,
  tooDistant,
  notForwardFacing,
  multipleFaces,
  invalidOrientation,
  success,
  error
}

class FaceDetectionService {
  late final FaceDetector _faceDetector;

  FaceDetectionService() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableLandmarks: false,
        enableClassification: false,
      ),
    );
  }

  /// Verifies if the image contains a clear, forward-facing face of sufficient size.
  Future<FaceVerificationResult> verifyFace(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) return FaceVerificationResult.noFace;
      if (faces.length > 1) return FaceVerificationResult.multipleFaces;

      final face = faces.first;
      
      // 1. Check for profile shots (Yaw)
      // headEulerAngleY is the rotation around the vertical axis.
      // 0 is looking straight, negative is left, positive is right.
      if (face.headEulerAngleY != null) {
        if (face.headEulerAngleY!.abs() > 38) {
          return FaceVerificationResult.notForwardFacing;
        }
      }

      // 2. Check for tilted heads (Roll)
      if (face.headEulerAngleZ != null) {
        if (face.headEulerAngleZ!.abs() > 40) {
          return FaceVerificationResult.invalidOrientation;
        }
      }

      // 3. Check for size (Distant shots)
      // We compare the face bounding box area to the input image area.
      if (inputImage.metadata?.size != null) {
        final imageArea = inputImage.metadata!.size.width * inputImage.metadata!.size.height;
        final faceArea = face.boundingBox.width * face.boundingBox.height;
        final occupancy = faceArea / imageArea;
        
        // Face must occupy at least 12% of the image to be considered "close enough"
        if (occupancy < 0.12) {
          return FaceVerificationResult.tooDistant;
        }
      }

      return FaceVerificationResult.success;
    } catch (e) {
      debugPrint('Error during face verification: $e');
      return FaceVerificationResult.error;
    }
  }

  /// Simple check for existing boolean logic
  Future<bool> hasFace(File imageFile) async {
    final result = await verifyFace(imageFile);
    return result == FaceVerificationResult.success;
  }

  /// Closes the detector and releases its resources.
  void dispose() {
    _faceDetector.close();
  }
}
