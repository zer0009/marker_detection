import 'dart:math' as math;
import 'package:image/image.dart' as img;
import '../models/settings_model.dart';

class LineDetector {
  static const int REGION_THRESHOLD = 30;
  static const double DIAGONAL_SLOPE_THRESHOLD = 0.3;
  static const int MIN_LINE_LENGTH = 80;
  static const int MAX_LINE_GAP = 15;
  static const int EDGE_DETECTION_WINDOW = 3;
  static const int SCAN_LINE_SPACING = 2;
  static const double MAX_ANGLE_CHANGE = 30.0;

  /// Enhanced line detection for blind runner guidance
  static List<List<int>> findLines(img.Image edges, SettingsModel settings) {
    List<List<int>> lines = [];
    int width = edges.width;
    int height = edges.height;
    int startY = (height * 2) ~/ 3;
    int threshold = settings.sensitivity.round();
    
    List<List<int>> preliminaryLines = [];
    
    // Scan lines with dynamic spacing based on image height
    for (int y = startY; y < height; y += SCAN_LINE_SPACING) {
      _processLine(y, width, edges, threshold, preliminaryLines);
    }

    // Filter and validate lines
    lines = _validateLines(preliminaryLines, width);
    
    // Merge nearby lines and smooth the path
    lines = _mergeNearbyLines(lines);
    lines = _smoothLines(lines);

    return lines;
  }

  static void _processLine(int y, int width, img.Image edges, int threshold, List<List<int>> lines) {
    List<int> transitions = [];
    int consecutiveWhite = 0;
    int lastTransition = -1;

    // Enhanced edge detection with noise reduction
    for (int x = 0; x < width; x++) {
      if (_isValidEdgePoint(x, y, edges, threshold)) {
        consecutiveWhite++;
        if (consecutiveWhite == 1) {
          if (lastTransition == -1 || x - lastTransition > MIN_LINE_LENGTH) {
            transitions.add(x);
            lastTransition = x;
          }
        }
      } else {
        if (consecutiveWhite >= EDGE_DETECTION_WINDOW) {
          transitions.add(x - 1);
        }
        consecutiveWhite = 0;
      }
    }

    _processTransitions(transitions, y, width, lines);
  }

  static bool _isValidEdgePoint(int x, int y, img.Image edges, int threshold) {
    if (x < 1 || x >= edges.width - 1 || y < 1 || y >= edges.height - 1) {
      return false;
    }

    int centerPixel = edges.getPixel(x, y).r.toInt();
    if (centerPixel < threshold) {
      return false;
    }

    // Check surrounding pixels for edge consistency
    int surroundingSum = 0;
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue;
        surroundingSum += edges.getPixel(x + dx, y + dy).r.toInt();
      }
    }

    return surroundingSum > threshold * 3;
  }

  static void _processTransitions(List<int> transitions, int y, int width, List<List<int>> lines) {
    if (transitions.length >= 2) {
      for (int i = 0; i < transitions.length - 1; i += 2) {
        int length = transitions[i + 1] - transitions[i];
        if (_isValidLineSegment(length, width)) {
          lines.add([transitions[i], y, transitions[i + 1], y]);
        }
      }
    }
  }

  static bool _isValidLineSegment(int length, int width) {
    return length > MIN_LINE_LENGTH && 
           length < width / 2 && 
           length > REGION_THRESHOLD;
  }

  static List<List<int>> _validateLines(List<List<int>> lines, int width) {
    if (lines.isEmpty) return [];

    List<List<int>> validLines = [];
    double previousAngle = 0;
    bool isFirstLine = true;

    for (var line in lines) {
      double currentAngle = _calculateLineAngle(line);
      
      if (isFirstLine) {
        validLines.add(line);
        previousAngle = currentAngle;
        isFirstLine = false;
        continue;
      }

      // Check if angle change is within acceptable range
      double angleChange = (currentAngle - previousAngle).abs();
      if (angleChange <= MAX_ANGLE_CHANGE) {
        validLines.add(line);
        previousAngle = currentAngle;
      }
    }

    return validLines;
  }

  static double _calculateLineAngle(List<int> line) {
    return math.atan2(line[3] - line[1], line[2] - line[0]) * 180 / math.pi;
  }

  static List<List<int>> _smoothLines(List<List<int>> lines) {
    if (lines.length < 3) return lines;

    List<List<int>> smoothedLines = [];
    
    for (int i = 1; i < lines.length - 1; i++) {
      var prevLine = lines[i - 1];
      var currentLine = lines[i];
      var nextLine = lines[i + 1];

      // Apply smoothing using moving average
      List<int> smoothedLine = [
        (prevLine[0] + currentLine[0] + nextLine[0]) ~/ 3,
        (prevLine[1] + currentLine[1] + nextLine[1]) ~/ 3,
        (prevLine[2] + currentLine[2] + nextLine[2]) ~/ 3,
        (prevLine[3] + currentLine[3] + nextLine[3]) ~/ 3,
      ];

      smoothedLines.add(smoothedLine);
    }

    // Add first and last lines
    if (lines.isNotEmpty) {
      smoothedLines.insert(0, lines.first);
      smoothedLines.add(lines.last);
    }

    return smoothedLines;
  }

  static List<List<int>> _mergeNearbyLines(List<List<int>> lines) {
    if (lines.isEmpty) return lines;

    List<List<int>> mergedLines = [];
    List<bool> used = List.filled(lines.length, false);

    for (int i = 0; i < lines.length; i++) {
      if (used[i]) continue;

      List<int> currentLine = List.from(lines[i]);
      used[i] = true;

      bool merged;
      do {
        merged = false;
        for (int j = 0; j < lines.length; j++) {
          if (used[j]) continue;

          if (_shouldMergeLines(currentLine, lines[j])) {
            currentLine = _mergeTwoLines(currentLine, lines[j]);
            used[j] = true;
            merged = true;
          }
        }
      } while (merged);

      mergedLines.add(currentLine);
    }

    return mergedLines;
  }

  static bool _shouldMergeLines(List<int> line1, List<int> line2) {
    if ((line1[1] - line2[1]).abs() > MAX_LINE_GAP) return false;

    int minX1 = math.min(line1[0], line1[2]);
    int maxX1 = math.max(line1[0], line1[2]);
    int minX2 = math.min(line2[0], line2[2]);
    int maxX2 = math.max(line2[0], line2[2]);

    return (minX1 <= maxX2 + MAX_LINE_GAP && maxX1 >= minX2 - MAX_LINE_GAP);
  }

  static List<int> _mergeTwoLines(List<int> line1, List<int> line2) {
    return [
      math.min(line1[0], line2[0]),
      (line1[1] + line2[1]) ~/ 2,
      math.max(line1[2], line2[2]),
      (line1[3] + line2[3]) ~/ 2,
    ];
  }
}