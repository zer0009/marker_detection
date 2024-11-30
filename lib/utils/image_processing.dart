// lib/utils/image_processing.dart
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';

import '../models/settings_model.dart';

class ImageProcessing {
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

  /// Converts CameraImage to [img.Image]
  static img.Image? convertCameraImage(CameraImage image) {
    try {
      // Convert YUV420 to RGB
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

  /// Adaptive Thresholding
  static img.Image adaptiveThreshold(img.Image src, int threshold) {
    int windowSize = 11;
    img.Image thresholded = img.Image.from(src);

    // Only process the lower third of the image
    int startY = (src.height * 2) ~/ 3;

    for (int y = startY; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        // Simplified local thresholding
        int sum = 0;
        int count = 0;

        // Reduced window sampling
        for (int ky = -windowSize ~/ 2; ky <= windowSize ~/ 2; ky += 2) {
          for (int kx = -windowSize ~/ 2; kx <= windowSize ~/ 2; kx += 2) {
            int ny = y + ky;
            int nx = x + kx;
            if (nx >= 0 && nx < src.width && ny >= startY && ny < src.height) {
              sum += getLuminance(src.getPixel(nx, ny) as img.Pixel);
              count++;
            }
          }
        }

        int localThreshold = (sum / count).round();
        if (getLuminance(src.getPixel(x, y) as img.Pixel) < localThreshold - 5) {
          thresholded.setPixelRgba(x, y, 0, 0, 0, 255);
        } else {
          thresholded.setPixelRgba(x, y, 255, 255, 255, 255);
        }
      }
    }
    return thresholded;
  }

  // Optimized constants
  static const int MIN_LINE_WIDTH = 2;
  static const int MAX_LINE_WIDTH = 25;
  static const double LUMINANCE_THRESHOLD = 85.0;
  static const int SCAN_LINES = 60;  // Reduced scan lines
  static const double CENTER_WEIGHT = 0.5;
  static const int POSITION_RESET_MS = 250;
  static const double EDGE_WEIGHT = 0.95;
  static const int STABLE_LINE_THRESHOLD = 4;
  static const double RAPID_MOVEMENT_THRESHOLD = 4.0;
  static const int CONSECUTIVE_FRAMES_THRESHOLD = 2;
  static const double LOCAL_CONTRAST_THRESHOLD = 0.80;
  static const double GROUP_PROXIMITY_THRESHOLD = 0.025;
  static const int MAX_HISTORY_SIZE = 3;  // Reduced history size
  static const double SMOOTHING_FACTOR = 0.75;
  static const double JUMP_THRESHOLD = 0.15;

  // Updated constants for better line detection
  static const double CANNY_THRESHOLD_1 = 30.0;
  static const double CANNY_THRESHOLD_2 = 90.0;
  static const int GAUSSIAN_BLUR_SIZE = 3;
  static const double MIN_LINE_LENGTH = 20.0;
  static const double MAX_LINE_GAP = 5.0;
  static const double MIN_SLOPE = 0.5;
  static const double LANE_CENTER_THRESHOLD = 50.0;
  static const int GUIDANCE_COOLDOWN = 3;

  // Tracking variables
  static String _lastGuidance = '';
  static DateTime? _lastGuidanceTime;
  static bool _isLineStable = false;
  static double _lastConfidenceScore = 0.0;

  /// Enhanced line detection with improved preprocessing
  static Map<String, dynamic> detectLine(img.Image image, SettingsModel settings) {
    try {
      // Reduce image size and convert to grayscale
      var processImage = img.copyResize(
        image,
        width: image.width ~/ 2,
        height: image.height ~/ 2,
        interpolation: img.Interpolation.nearest
      );
      
      // Apply Gaussian blur
      processImage = _applyGaussianBlur(processImage, GAUSSIAN_BLUR_SIZE);
      
      // Edge detection (Canny-like)
      var edges = _detectEdges(processImage);
      
      // Detect left and right lanes
      var lanes = _detectLanes(edges);
      
      if (lanes == null || lanes['left'] == null || lanes['right'] == null) {
        return _createEmptyResult();
      }

      // Calculate lane center and deviation
      var deviation = _calculateLaneDeviation(
        List<List<int>>.from(lanes['left']!), 
        List<List<int>>.from(lanes['right']!), 
        processImage.width
      );

      // Calculate guidance
      var guidance = _calculateGuidance(deviation, settings);

      // Create debug visualization if needed
      Uint8List? debugImage;
      if (settings.showDebugView) {
        debugImage = createDebugImage(
          image,
          (processImage.width / 2 + deviation * processImage.width / 200).round(),
          deviation,
          settings,
        );
      }

      return {
        'deviation': deviation,
        'isLeft': guidance['isLeft'],
        'isRight': guidance['isRight'],
        'isCentered': guidance['isCentered'],
        'isLineLost': false,
        'isStable': _isLineStable,
        'needsCorrection': guidance['needsCorrection'],
        'guidance': guidance['message'],
        'debugImage': debugImage,
      };

    } catch (e) {
      print('Error in detectLine: $e');
      return _createEmptyResult();
    }
  }

  /// Apply Gaussian blur
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

  /// Detect edges using gradient-based approach
  static img.Image _detectEdges(img.Image source) {
    var edges = img.Image(width: source.width, height: source.height);
    int startY = (source.height * 2) ~/ 3;  // Only process lower third

    for (int y = startY + 1; y < source.height - 1; y++) {
      for (int x = 1; x < source.width - 1; x++) {
        // Compute gradients
        int gx = -getLuminance(source.getPixel(x-1, y)) + 
                 getLuminance(source.getPixel(x+1, y));
        int gy = -getLuminance(source.getPixel(x, y-1)) + 
                 getLuminance(source.getPixel(x, y+1));
        
        double magnitude = math.sqrt(gx * gx + gy * gy);
        
        if (magnitude > CANNY_THRESHOLD_1 && magnitude < CANNY_THRESHOLD_2) {
          edges.setPixelRgba(x, y, 255, 255, 255, 255);
        } else {
          edges.setPixelRgba(x, y, 0, 0, 0, 255);
        }
      }
    }
    
    return edges;
  }

  /// Detect left and right lanes using improved algorithm
  static Map<String, List<List<int>>>? _detectLanes(img.Image edges) {
    List<List<int>> lines = [];
    int height = edges.height;
    int width = edges.width;
    int startY = (height * 2) ~/ 3;  // Focus on lower third
    
    // Parameters for line detection
    const int MIN_LINE_PIXELS = 20;  // Minimum pixels to consider as line
    const int MAX_GAP = 5;  // Maximum gap between line segments
    
    // Scan columns for vertical line segments
    for (int x = 0; x < width; x++) {
        int whitePixelCount = 0;
        int currentGap = 0;
        int lineStartY = -1;
        
        // Scan from bottom to top
        for (int y = height - 1; y >= startY; y--) {
            bool isWhite = getLuminance(edges.getPixel(x, y)) > 127;
            
            if (isWhite) {
                whitePixelCount++;
                currentGap = 0;
                if (lineStartY == -1) lineStartY = y;
            } else {
                currentGap++;
                
                // If gap is too large, check if we found a valid line
                if (currentGap > MAX_GAP) {
                    if (whitePixelCount >= MIN_LINE_PIXELS) {
                        lines.add([x, lineStartY - whitePixelCount + 1, x, lineStartY]);
                    }
                    whitePixelCount = 0;
                    lineStartY = -1;
                }
            }
        }
        
        // Check for line at the end of column
        if (whitePixelCount >= MIN_LINE_PIXELS) {
            lines.add([x, lineStartY - whitePixelCount + 1, x, lineStartY]);
        }
    }

    if (lines.isEmpty) return null;

    // Group lines into left and right sides
    int centerX = width ~/ 2;
    List<List<int>> leftLanes = [];
    List<List<int>> rightLanes = [];
    
    // Find strongest lines on each side
    for (var line in lines) {
        int x = line[0];
        int lineLength = line[3] - line[1];
        
        if (x < centerX - 10) {  // Left side
            if (leftLanes.isEmpty || lineLength > leftLanes[0][3] - leftLanes[0][1]) {
                leftLanes = [line];
            }
        } else if (x > centerX + 10) {  // Right side
            if (rightLanes.isEmpty || lineLength > rightLanes[0][3] - rightLanes[0][1]) {
                rightLanes = [line];
            }
        }
    }

    // Require both left and right lanes to be detected
    if (leftLanes.isEmpty || rightLanes.isEmpty) return null;

    return {
        'left': leftLanes,
        'right': rightLanes,
    };
  }

  /// Calculate lane deviation
  static double _calculateLaneDeviation(
    List<List<int>> leftLanes,
    List<List<int>> rightLanes,
    int imageWidth
  ) {
    double leftX = 0, rightX = 0;
    
    for (var line in leftLanes) {
      leftX += line[0];
    }
    for (var line in rightLanes) {
      rightX += line[0];
    }
    
    leftX /= leftLanes.length;
    rightX /= rightLanes.length;
    
    double laneCenter = (leftX + rightX) / 2;
    return calculateDeviation(laneCenter.round(), imageWidth);
  }

  static Map<String, dynamic> _calculateGuidance(double deviation, SettingsModel settings) {
    if (_lastGuidanceTime != null && 
        DateTime.now().difference(_lastGuidanceTime!).inSeconds < GUIDANCE_COOLDOWN) {
      return _createGuidanceResult(_lastGuidance);
    }

    String message = '';
    bool isLeft = deviation < -settings.sensitivity;
    bool isRight = deviation > settings.sensitivity;
    bool isCentered = deviation.abs() <= settings.sensitivity;
    bool needsCorrection = deviation.abs() > settings.sensitivity * 1.5;

    if (isCentered) {
      message = "Centered";
    } else if (isLeft) {
      message = "Move right";
    } else if (isRight) {
      message = "Move left";
    }

    if (message != _lastGuidance) {
      _lastGuidance = message;
      _lastGuidanceTime = DateTime.now();
    }

    return {
      'message': message,
      'isLeft': isLeft,
      'isRight': isRight,
      'isCentered': isCentered,
      'needsCorrection': needsCorrection,
    };
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
      'guidance': '',
      'debugImage': null,
    };
  }

  static Map<String, dynamic> _createGuidanceResult(String lastGuidance) {
    return {
      'message': lastGuidance,
      'isLeft': lastGuidance == "Move right",
      'isRight': lastGuidance == "Move left",
      'isCentered': lastGuidance == "Centered",
      'needsCorrection': lastGuidance != "Centered",
    };
  }

  /// Reset tracking variables
  static void reset() {
    _lastGuidance = '';
    _lastGuidanceTime = null;
    _isLineStable = false;
    _lastConfidenceScore = 0.0;
  }

  static double _getColorDifference(Color c1, Color c2) {
    return math.sqrt(
        math.pow(c1.red - c2.red, 2) +
            math.pow(c1.green - c2.green, 2) +
            math.pow(c1.blue - c2.blue, 2)
    );
  }

  static Future<Map<String, dynamic>?> processImageInIsolate(Map<String, dynamic> params) async {
    try {
      final CameraImage image = params['image'] as CameraImage;
      final SettingsModel settings = params['settings'] as SettingsModel;

      final convertedImage = ImageProcessing.convertCameraImage(image);
      if (convertedImage == null) return null;

      // Get the line detection result
      final result = ImageProcessing.detectLine(convertedImage, settings);
      
      // The result already contains all the necessary information, just return it
      return result;

    } catch (e) {
      print('Error in processImageInIsolate: $e');
      return null;
    }
  }

  static Uint8List? createDebugImage(
      img.Image sourceImage,
      int linePosition,
      double deviation,
      SettingsModel settings,
      ) {
    try {
      // Create a smaller debug image for better performance
      img.Image debugImage = img.copyResize(sourceImage, width: 240);

      // Draw detected line position with improved visibility
      int scaledPosition = (linePosition * debugImage.width) ~/ sourceImage.width;
      for (int y = 0; y < debugImage.height; y++) {
        // Thicker line with gradient effect
        for (int x = -3; x <= 3; x++) {
          if (scaledPosition + x >= 0 && scaledPosition + x < debugImage.width) {
            int alpha = 255 - (x.abs() * 40);
            debugImage.setPixelRgba(scaledPosition + x, y, 255, 0, 0, alpha);
          }
        }
      }

      // Draw center and boundaries with improved visibility
      int centerX = debugImage.width ~/ 2;
      double sensitivity = (settings.sensitivity / 2).clamp(5.0, 50.0);
      int zoneWidth = (debugImage.width * (sensitivity / 100)).round();

      // Draw zones with semi-transparent fills
      for (int y = 0; y < debugImage.height; y++) {
        // Left zone
        for (int x = 0; x < centerX - zoneWidth; x++) {
          debugImage.setPixelRgba(x, y, 255, 0, 0, 40);
        }
        // Right zone
        for (int x = centerX + zoneWidth; x < debugImage.width; x++) {
          debugImage.setPixelRgba(x, y, 255, 0, 0, 40);
        }
        // Center zone
        debugImage.setPixelRgba(centerX, y, 0, 255, 0, 180);
      }

      return Uint8List.fromList(img.encodePng(debugImage));
    } catch (e) {
      print('Error creating debug image: $e');
      return null;
    }
  }
}