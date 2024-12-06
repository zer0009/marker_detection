import 'dart:typed_data';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

import '../models/settings_model.dart';
import '../models/line_position.dart';

class ImageProcessing {
  static bool _isLineStable = false;
  static double _lastConfidenceScore = 0.0;

  // Add new constants for line detection
  static const int REGION_THRESHOLD = 30;
  static const double DIAGONAL_SLOPE_THRESHOLD = 0.3;
  static const int MIN_LINE_LENGTH = 80;
  static const int MAX_LINE_GAP = 15;
  static const int EDGE_DETECTION_WINDOW = 3;

  /// Calculates the deviation of the line from center as a percentage
  static double calculateDeviation(int linePosition, int imageWidth) {
    double center = imageWidth / 2;
    double deviation = ((linePosition - center) / center) * 100;
    return deviation.clamp(-100.0, 100.0); // Clamp to -100% to 100%
  }

  /// Gets the current line stability state
  static bool get isLineStable => _isLineStable;

  /// Gets the current confidence score
  static double get confidenceScore => _lastConfidenceScore;

  /// Converts CameraImage to img.Image
  static img.Image? convertCameraImage(CameraImage image) {
    try {
      final int width = image.width;
      final int height = image.height;
      final img.Image imgImage = img.Image(width: width, height: height);

      // Ensure the image has the expected number of planes
      if (image.planes.length < 3) {
        print("Invalid number of planes in CameraImage");
        return null;
      }

      // Y, U, and V planes
      final Uint8List yPlane = image.planes[0].bytes;
      final Uint8List uPlane = image.planes[1].bytes;
      final Uint8List vPlane = image.planes[2].bytes;

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int uvIndex = (y ~/ 2) * (image.planes[1].bytesPerRow) + (x ~/ 2) * 2;
          if (uvIndex + 1 >= uPlane.length || uvIndex + 1 >= vPlane.length) {
            continue; // Prevent out-of-bounds access
          }
          final int Y = yPlane[y * image.planes[0].bytesPerRow + x];
          final int U = uPlane[uvIndex];
          final int V = vPlane[uvIndex + 1];

          // Convert YUV to RGB using integer approximation for performance
          int C = Y - 16;
          int D = U - 128;
          int E = V - 128;

          // Ensure proper rounding for RGB values
          int R = (1.164 * C + 1.596 * E).round().clamp(0, 255);
          int G = (1.164 * C - 0.392 * D - 0.813 * E).round().clamp(0, 255);
          int B = (1.164 * C + 2.017 * D).round().clamp(0, 255);

          imgImage.setPixelRgba(x, y, R, G, B, 255);
        }
      }
      return imgImage;
    } catch (e) {
      print("Error converting image: $e");
      return null;
    }
  }

  /// Updated Luminance calculation to accept [img.Pixel]
  static int getLuminance(img.Pixel pixel) {
    // Extract RGB components
    int r = pixel.r.toInt();
    int g = pixel.g.toInt();
    int b = pixel.b.toInt();
    // Using the Rec. 709 formula for luminance
    return ((0.2126 * r) + (0.7152 * g) + (0.0722 * b)).round();
  }

  /// Adaptive Thresholding using dynamic settings
  static img.Image adaptiveThreshold(img.Image src, SettingsModel settings) {
    int windowSize = settings.scanLines; // Dynamic window size from settings
    img.Image thresholded = img.Image.from(src);

    // Only process the lower third of the image
    int startY = (src.height * 2) ~/ 3;

    for (int y = startY; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        // Simplified local thresholding
        int sum = 0;
        int count = 0;

        // Reduced window sampling based on settings
        for (int ky = -windowSize ~/ 2; ky <= windowSize ~/ 2; ky += 2) {
          for (int kx = -windowSize ~/ 2; kx <= windowSize ~/ 2; kx += 2) {
            int ny = y + ky;
            int nx = x + kx;
            if (nx >= 0 && nx < src.width && ny >= startY && ny < src.height) {
              sum += getLuminance(src.getPixel(nx, ny));
              count++;
            }
          }
        }

        int localThreshold = (sum / count).round();
        if (getLuminance(src.getPixel(x, y)) < localThreshold - 5) {
          thresholded.setPixelRgba(x, y, 0, 0, 0, 255);
        } else {
          thresholded.setPixelRgba(x, y, 255, 255, 255, 255);
        }
      }
    }
    return thresholded;
  }

  /// Enhanced line detection with region awareness
  static Map<String, dynamic> detectLine(img.Image image, SettingsModel settings) {
    try {
      // Convert and preprocess image
      var processImage = _preprocessImage(image);

      // Detect edges with dynamic thresholds
      var edges = _detectEdges(processImage, settings);

      // Find lines using modified Hough transform approach
      var lines = _findLines(edges, settings);

      if (lines.isEmpty) {
        return _createEmptyResult();
      }

      // Analyze line positions and movement
      var analysis = _analyzeLinesPosition(lines, processImage.width);

      // Ensure linePosition is never null
      LinePosition linePosition = analysis['linePosition'] ?? LinePosition.unknown;

      // Calculate deviation and guidance
      return {
        'deviation': analysis['deviation'],
        'isLeft': analysis['isLeft'],
        'isRight': analysis['isRight'],
        'isCentered': analysis['isCentered'],
        'isLineLost': false,
        'isStable': analysis['isStable'],
        'needsCorrection': analysis['needsCorrection'],
        'linePosition': linePosition,
        'debugImage': settings.showDebugView ?
            _createDebugImage(processImage, lines, analysis) : null,
      };
    } catch (e) {
      print('Error in detectLine: $e');
      return _createEmptyResult();
    }
  }

  /// Analyze line positions and determine guidance
  static Map<String, dynamic> _analyzeLinesPosition(List<List<int>> lines, int imageWidth) {
    int regionWidth = imageWidth ~/ 3;
    double? deviation;
    bool isLeft = false;
    bool isRight = false;
    bool isCentered = false;
    bool isStable = false;
    bool needsCorrection = false;
    LinePosition linePosition = LinePosition.unknown;

    // Find dominant line (closest to center)
    var dominantLine = _findDominantLine(lines, imageWidth);
    if (dominantLine != null) {
      // Calculate average X position
      double avgX = (dominantLine[0] + dominantLine[2]) / 2;

      // Calculate deviation as percentage from center
      deviation = ((avgX - imageWidth / 2) / (imageWidth / 2)) * 100;

      // Check if line is diagonal
      double slope = (dominantLine[3] - dominantLine[1]).abs() /
                    (dominantLine[2] - dominantLine[0]).abs();

      if (slope > DIAGONAL_SLOPE_THRESHOLD) {
        // Handle diagonal line
        linePosition = dominantLine[2] > dominantLine[0] ?
            LinePosition.enteringRight : LinePosition.enteringLeft;
        needsCorrection = true;
      } else {
        // Determine region
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

  /// Find the dominant (most relevant) line
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

  /// Apply Gaussian blur using dynamic kernel size from settings
  static img.Image _applyGaussianBlur(img.Image source, int kernelSize) {
    var blurred = img.Image.from(source);

    for (int y = kernelSize ~/ 2; y < source.height - kernelSize ~/ 2; y++) {
      for (int x = kernelSize ~/ 2; x < source.width - kernelSize ~/ 2; x++) {
        var sum = 0;
        var count = 0;

        for (int ky = -kernelSize ~/ 2; ky <= kernelSize ~/ 2; ky++) {
          for (int kx = -kernelSize ~/ 2; kx <= kernelSize ~/ 2; kx++) {
            var pixel = source.getPixel(x + kx, y + ky);
            sum += getLuminance(pixel);
            count++;
          }
        }

        var avg = (sum / count).round();
        blurred.setPixelRgba(x, y, avg, avg, avg, 255);
      }
    }

    return blurred;
  }

  /// Improved edge detection using Sobel operator with higher thresholds
  static img.Image _detectEdges(img.Image source, SettingsModel settings) {
    img.Image edges = img.Image(width: source.width, height: source.height);
    int threshold1 = settings.cannyThreshold1.round() + 20; // Increase threshold
    int threshold2 = settings.cannyThreshold2.round() + 20; // Increase threshold
    
    // Only process the lower third of the image
    int startY = (source.height * 2) ~/ 3;

    for (int y = startY + 1; y < source.height - 1; y++) {
      for (int x = 1; x < source.width - 1; x++) {
        // Sobel operators for better edge detection
        int gx = -getLuminance(source.getPixel(x-1, y-1)) + 
                 getLuminance(source.getPixel(x+1, y-1)) +
                -2 * getLuminance(source.getPixel(x-1, y)) + 
                 2 * getLuminance(source.getPixel(x+1, y)) +
                -getLuminance(source.getPixel(x-1, y+1)) + 
                 getLuminance(source.getPixel(x+1, y+1));
                 
        int gy = -getLuminance(source.getPixel(x-1, y-1)) + 
                -2 * getLuminance(source.getPixel(x, y-1)) +
                -getLuminance(source.getPixel(x+1, y-1)) +
                 getLuminance(source.getPixel(x-1, y+1)) +
                 2 * getLuminance(source.getPixel(x, y+1)) +
                 getLuminance(source.getPixel(x+1, y+1));

        int gradient = math.sqrt(gx * gx + gy * gy).round();

        if (gradient > threshold1 && gradient < threshold2) {
          edges.setPixelRgba(x, y, 255, 255, 255, 255);
        } else {
          edges.setPixelRgba(x, y, 0, 0, 0, 255);
        }
      }
    }
    return edges;
  }

  /// Create an empty result when no lines are detected
  static Map<String, dynamic> _createEmptyResult() {
    return {
      'deviation': null,
      'isLeft': false,
      'isRight': false,
      'isCentered': false,
      'isLineLost': true,
      'isStable': false,
      'needsCorrection': false,
      'guidance': '',
      'debugImage': null,
    };
  }

  /// Reset tracking variables
  static void reset() {
    _isLineStable = false;
    _lastConfidenceScore = 0.0;
  }

  /// Process image in isolate (if used)
  static Future<Map<String, dynamic>?> processImageInIsolate(Map<String, dynamic> params) async {
    try {
      final CameraImage image = params['image'] as CameraImage;
      final SettingsModel settings = params['settings'] as SettingsModel;

      final convertedImage = convertCameraImage(image);
      if (convertedImage == null) return null;

      // Get the line detection result
      final result = detectLine(convertedImage, settings);

      // The result already contains all the necessary information, just return it
      return result;
    } catch (e) {
      print('Error in processImageInIsolate: $e');
      return null;
    }
  }

  /// Create debug image for visualization
  static Uint8List? _createDebugImage(
    img.Image sourceImage,
    List<List<int>> lines,
    Map<String, dynamic> analysis,
  ) {
    try {
      // Resize for performance and visualization
      img.Image debugImage = img.copyResize(sourceImage, width: 240);

      // Draw all detected line segments in red
      for (var line in lines) {
        int x1 = line[0];
        int y1 = line[1];
        int x2 = line[2];
        int y2 = line[3];
        img.drawLine(debugImage, y1: y1, x2: x2, y2: y2, x1: x1, color: img.ColorRgb8(255, 0, 0));
      }

      // Draw center reference line only
      int centerX = debugImage.width ~/ 2;
      for (int y = 0; y < debugImage.height; y++) {
        // Green center reference line
        debugImage.setPixelRgba(centerX, y, 0, 255, 0, 180);
      }

      return Uint8List.fromList(img.encodePng(debugImage));
    } catch (e) {
      print('Error creating debug image: $e');
      return null;
    }
  }

  /// Preprocess the image by applying Gaussian blur and converting to grayscale
  static img.Image _preprocessImage(img.Image image) {
    // Apply Gaussian blur to reduce noise
    img.Image blurred = _applyGaussianBlur(image, 5);
    // Convert to grayscale
    img.Image grayscale = img.grayscale(blurred);
    return grayscale;
  }

  /// Improved line finding algorithm with additional validation
  static List<List<int>> _findLines(img.Image edges, SettingsModel settings) {
    List<List<int>> lines = [];
    int width = edges.width;
    int height = edges.height;
    int startY = (height * 2) ~/ 3;
    int threshold = settings.sensitivity.round();
    
    // Scan with multiple angles for better line detection
    for (int y = startY; y < height; y += 2) {
      List<int> transitions = [];
      int consecutiveWhite = 0;
      int lastTransition = -1;

      for (int x = 0; x < width; x++) {
        int pixel = getLuminance(edges.getPixel(x, y));
        
        if (pixel >= threshold) {
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

      // Process transitions to find line segments
      if (transitions.length >= 2) {
        for (int i = 0; i < transitions.length - 1; i += 2) {
          int length = transitions[i + 1] - transitions[i];
          if (length > MIN_LINE_LENGTH && length < width / 2) {
            // Validate line slope
            double slope = (y - y) / (transitions[i + 1] - transitions[i]).abs();
            if (slope.abs() < DIAGONAL_SLOPE_THRESHOLD) {
              lines.add([transitions[i], y, transitions[i + 1], y]);
            }
          }
        }
      }
    }

    return _mergeNearbyLines(lines);
  }

  /// Merge nearby line segments
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

          // Check if lines are close enough to merge
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

  /// Check if two lines should be merged
  static bool _shouldMergeLines(List<int> line1, List<int> line2) {
    // Lines should be close in Y coordinate
    if ((line1[1] - line2[1]).abs() > MAX_LINE_GAP) return false;

    // Check X coordinate overlap or proximity
    int minX1 = math.min(line1[0], line1[2]);
    int maxX1 = math.max(line1[0], line1[2]);
    int minX2 = math.min(line2[0], line2[2]);
    int maxX2 = math.max(line2[0], line2[2]);

    // Check for overlap or small gap
    return (minX1 <= maxX2 + MAX_LINE_GAP && maxX1 >= minX2 - MAX_LINE_GAP);
  }

  /// Merge two lines into one
  static List<int> _mergeTwoLines(List<int> line1, List<int> line2) {
    return [
      math.min(line1[0], line2[0]),  // leftmost x
      (line1[1] + line2[1]) ~/ 2,    // average y
      math.max(line1[2], line2[2]),  // rightmost x
      (line1[3] + line2[3]) ~/ 2,    // average y
    ];
  }

  /// Convert serialized image data back to img.Image
  static img.Image? convertFromImageData(Map<String, dynamic> imageData) {
    try {
      final width = imageData['width'] as int;
      final height = imageData['height'] as int;
      final planes = imageData['planes'] as List;
      
      // Create a new image
      final img.Image image = img.Image(width: width, height: height);
      
      // Convert YUV to RGB using the first plane (Y)
      final bytes = (planes[0] as Map)['bytes'] as Uint8List;
      final bytesPerRow = (planes[0] as Map)['bytesPerRow'] as int;
      
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int value = bytes[y * bytesPerRow + x];
          image.setPixelRgba(x, y, value, value, value, 255);
        }
      }
      
      return image;
    } catch (e) {
      print('Error converting image data: $e');
      return null;
    }
  }
}