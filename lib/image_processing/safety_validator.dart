import 'package:image/image.dart' as img;
import '../models/settings_model.dart';

class SafetyValidator {
  static const double MINIMUM_CONFIDENCE_THRESHOLD = 0.85;
  static const int MINIMUM_LINE_WIDTH = 40;
  static const int OBSTACLE_DETECTION_HEIGHT = 50;
  
  /// Validates if the detected path is safe for running
  static Map<String, dynamic> validatePath(img.Image image, List<List<int>> lines, SettingsModel settings) {
    bool isSafe = true;
    String warning = '';
    double confidence = 0.0;

    if (lines.isEmpty) {
      return {
        'isSafe': false,
        'warning': 'No path detected',
        'confidence': 0.0
      };
    }

    // Check line width for stability
    double averageWidth = _calculateAverageLineWidth(lines);
    if (averageWidth < MINIMUM_LINE_WIDTH) {
      isSafe = false;
      warning = 'Path too narrow';
    }

    // Calculate path confidence
    confidence = _calculatePathConfidence(image, lines);
    if (confidence < MINIMUM_CONFIDENCE_THRESHOLD) {
      isSafe = false;
      warning = 'Low confidence in path detection';
    }

    // Check for obstacles
    bool hasObstacles = _detectObstacles(image, lines);
    if (hasObstacles) {
      isSafe = false;
      warning = 'Potential obstacle detected';
    }

    return {
      'isSafe': isSafe,
      'warning': warning,
      'confidence': confidence
    };
  }

  static double _calculateAverageLineWidth(List<List<int>> lines) {
    if (lines.isEmpty) return 0;
    
    double totalWidth = 0;
    for (var line in lines) {
      totalWidth += (line[2] - line[0]).abs();
    }
    return totalWidth / lines.length;
  }

  static double _calculatePathConfidence(img.Image image, List<List<int>> lines) {
    if (lines.isEmpty) return 0;

    int validPoints = 0;
    int totalPoints = 0;

    for (var line in lines) {
      int startX = line[0];
      int endX = line[2];
      int y = line[1];

      for (int x = startX; x <= endX; x++) {
        if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
          totalPoints++;
          var pixel = image.getPixel(x, y);
          if (pixel.r > 200) { // Check for white/bright pixels
            validPoints++;
          }
        }
      }
    }

    return totalPoints > 0 ? validPoints / totalPoints : 0;
  }

  static bool _detectObstacles(img.Image image, List<List<int>> lines) {
    if (lines.isEmpty) return true;

    for (var line in lines) {
      int centerX = (line[0] + line[2]) ~/ 2;
      int y = line[1];

      // Check area above the line for obstacles
      for (int checkY = y - OBSTACLE_DETECTION_HEIGHT; checkY < y; checkY++) {
        if (checkY < 0 || checkY >= image.height) continue;
        
        var pixel = image.getPixel(centerX, checkY);
        if (pixel.r < 50) { // Dark pixels might indicate obstacles
          return true;
        }
      }
    }

    return false;
  }
}