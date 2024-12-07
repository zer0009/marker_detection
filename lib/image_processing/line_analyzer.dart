import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../models/line_position.dart';

class LineAnalyzer {
  static bool _isLineStable = false;
  static double _lastConfidenceScore = 0.0;

  static bool get isLineStable => _isLineStable;
  static double get confidenceScore => _lastConfidenceScore;

  /// Calculate deviation from center
  static double calculateDeviation(int linePosition, int imageWidth) {
    double center = imageWidth / 2;
    double deviation = ((linePosition - center) / center) * 100;
    return deviation.clamp(-100.0, 100.0);
  }

  /// Analyze line positions
  static Map<String, dynamic> analyzeLinesPosition(List<List<int>> lines, int imageWidth) {
    int regionWidth = imageWidth ~/ 3;
    double? deviation;
    bool isLeft = false;
    bool isRight = false;
    bool isCentered = false;
    bool isStable = false;
    bool needsCorrection = false;
    LinePosition linePosition = LinePosition.unknown;

    var dominantLine = _findDominantLine(lines, imageWidth);
    if (dominantLine != null) {
      double avgX = (dominantLine[0] + dominantLine[2]) / 2;
      deviation = ((avgX - imageWidth / 2) / (imageWidth / 2)) * 100;

      double slope = (dominantLine[3] - dominantLine[1]).abs() /
                    (dominantLine[2] - dominantLine[0]).abs();

      if (slope > 0.3) {
        linePosition = dominantLine[2] > dominantLine[0] ?
            LinePosition.enteringRight : LinePosition.enteringLeft;
        needsCorrection = true;
      } else {
        if (avgX < regionWidth) {
          isLeft = true;
          linePosition = LinePosition.leavingLeft;
        } else if (avgX > 2 * regionWidth) {
          isRight = true;
          linePosition = LinePosition.leavingRight;
        } else {
          isCentered = true;
          linePosition = LinePosition.visible;
          isStable = true;
        }
      }
    }

    return {
      'deviation': deviation,
      'isLeft': isLeft,
      'isRight': isRight,
      'isCentered': isCentered,
      'isStable': isStable,
      'needsCorrection': needsCorrection,
      'linePosition': linePosition,
    };
  }

  static List<int>? _findDominantLine(List<List<int>> lines, int imageWidth) {
    if (lines.isEmpty) return null;

    int centerX = imageWidth ~/ 2;
    List<int>? closestLine;
    double minDistance = double.infinity;

    for (var line in lines) {
      double avgX = (line[0] + line[2]) / 2;
      double distance = (avgX - centerX).abs();

      if (distance < minDistance) {
        minDistance = distance;
        closestLine = line;
      }
    }

    return closestLine;
  }

  /// Create debug visualization
  static Uint8List? createDebugImage(
    img.Image sourceImage,
    List<List<int>> lines,
    Map<String, dynamic> analysis,
  ) {
    try {
      img.Image debugImage = img.copyResize(sourceImage, width: 240);

      for (var line in lines) {
        img.drawLine(debugImage,
          x1: line[0], y1: line[1],
          x2: line[2], y2: line[3],
          color: img.ColorRgb8(255, 0, 0)
        );
      }

      int centerX = debugImage.width ~/ 2;
      for (int y = 0; y < debugImage.height; y++) {
        debugImage.setPixelRgba(centerX, y, 0, 255, 0, 180);
      }

      return Uint8List.fromList(img.encodePng(debugImage));
    } catch (e) {
      print('Error creating debug image: $e');
      return null;
    }
  }

  /// Reset tracking variables
  static void reset() {
    _isLineStable = false;
    _lastConfidenceScore = 0.0;
  }
}