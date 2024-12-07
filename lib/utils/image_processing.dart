import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

import '../models/settings_model.dart';
import '../models/line_position.dart';
import './image_processing_helpers.dart';

class ImageProcessing {
  static bool _isLineStable = false;
  static double _lastConfidenceScore = 0.0;

  // Core constants for line detection
  static const int MIN_LINE_LENGTH = 80;
  static const int MAX_LINE_GAP = 15;
  static const double CANNY_LOW_THRESHOLD = 50.0;
  static const double CANNY_HIGH_THRESHOLD = 150.0;
  static const int GAUSSIAN_KERNEL_SIZE = 5;

  static bool get isLineStable => _isLineStable;
  static double get confidenceScore => _lastConfidenceScore;

  static img.Image? convertCameraImage(CameraImage image) {
    return ImageProcessingHelpers.convertCameraImage(image);
  }

  /// Calculate luminance from pixel
  static double getLuminance(img.Pixel pixel) {
    int r = pixel.r.toInt();
    int g = pixel.g.toInt();
    int b = pixel.b.toInt();
    return (0.2126 * r + 0.7152 * g + 0.0722 * b);
  }

  static Map<String, dynamic> detectLine(img.Image image, SettingsModel settings) {
    try {
      var processedImage = ImageProcessingHelpers.preprocessImage(image);
      var mask = ImageProcessingHelpers.createROIMask(processedImage);
      var maskedImage = ImageProcessingHelpers.applyMask(processedImage, mask);
      var lines = ImageProcessingHelpers.findLinesEnhanced(maskedImage, settings);

      if (lines.isEmpty) {
        return ImageProcessingHelpers.createEmptyResult();
      }

      var analysis = ImageProcessingHelpers.analyzeLinesPosition(lines, processedImage.width.toDouble());
      
      // Pass the original image for debug view instead of processed image
      var debugImage = settings.showDebugView ? 
          ImageProcessingHelpers.createDebugImage(image, lines, analysis) : null;

      return {
        'deviation': analysis['deviation'] ?? 0.0,
        'isLeft': analysis['isLeft'] ?? false,
        'isRight': analysis['isRight'] ?? false,
        'isCentered': analysis['isCentered'] ?? false,
        'isLineLost': false,
        'isStable': analysis['isStable'] ?? false,
        'needsCorrection': analysis['needsCorrection'] ?? true,
        'linePosition': analysis['linePosition'] ?? LinePosition.unknown,
        'debugImage': debugImage,
        'confidence': analysis['confidence'] ?? 0.0,
      };
    } catch (e) {
      print('Error in detectLine: $e');
      return ImageProcessingHelpers.createEmptyResult();
    }
  }

  static void reset() {
    _isLineStable = false;
    _lastConfidenceScore = 0.0;
  }

  static Future<Map<String, dynamic>?> processImageInIsolate(Map<String, dynamic> params) async {
    try {
      final image = params['image'] as CameraImage;
      final settings = params['settings'] as SettingsModel;

      final convertedImage = convertCameraImage(image);
      if (convertedImage == null) return null;

      return detectLine(convertedImage, settings);
    } catch (e) {
      print('Error in processImageInIsolate: $e');
      return null;
    }
  }
}