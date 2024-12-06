import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

import '../models/settings_model.dart';
import '../models/line_position.dart';
import 'image_converter.dart';
import 'image_preprocessor.dart';
import 'edge_detector.dart';
import 'line_detector.dart';
import 'line_analyzer.dart';
import 'safety_validator.dart';
import 'guidance_generator.dart';

class ImageProcessor {
  /// Process image and detect lines with enhanced safety features
  static Map<String, dynamic> detectLine(img.Image image, SettingsModel settings) {
    try {
      var processedImage = ImagePreprocessor.preprocessImage(image);
      var edges = EdgeDetector.detectEdges(processedImage, settings);
      var lines = LineDetector.findLines(edges, settings);

      if (lines.isEmpty) {
        return _createEmptyResult();
      }

      var analysis = LineAnalyzer.analyzeLinesPosition(lines, processedImage.width);
      var safety = SafetyValidator.validatePath(processedImage, lines, settings);
      var guidance = GuidanceGenerator.generateGuidance(analysis, safety);

      return {
        'deviation': analysis['deviation'],
        'isLeft': analysis['isLeft'],
        'isRight': analysis['isRight'],
        'isCentered': analysis['isCentered'],
        'isLineLost': false,
        'isStable': analysis['isStable'],
        'needsCorrection': analysis['needsCorrection'],
        'linePosition': analysis['linePosition'],
        'isSafe': safety['isSafe'],
        'warning': safety['warning'],
        'confidence': safety['confidence'],
        'guidance': guidance,
        'debugImage': settings.showDebugView ?
            LineAnalyzer.createDebugImage(processedImage, lines, analysis) : null,
      };
    } catch (e) {
      print('Error in detectLine: $e');
      return _createEmptyResult();
    }
  }

  /// Process image in isolate with enhanced safety checks
  static Future<Map<String, dynamic>?> processImageInIsolate(Map<String, dynamic> params) async {
    try {
      final CameraImage image = params['image'] as CameraImage;
      final SettingsModel settings = params['settings'] as SettingsModel;

      final convertedImage = ImageConverter.convertCameraImage(image);
      if (convertedImage == null) return null;

      return detectLine(convertedImage, settings);
    } catch (e) {
      print('Error in processImageInIsolate: $e');
      return null;
    }
  }

  static Map<String, dynamic> _createEmptyResult() {
    return {
      'deviation': null,
      'isLeft': false,
      'isRight': false,
      'isCentered': false,
      'isLineLost': true,
      'isStable': false,
      'needsCorrection': false,
      'guidance': 'Stop. Path lost.',
      'isSafe': false,
      'warning': 'No path detected',
      'confidence': 0.0,
      'debugImage': null,
    };
  }
}