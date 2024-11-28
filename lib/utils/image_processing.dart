// lib/utils/image_processing.dart
import 'dart:typed_data';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';

import '../models/settings_model.dart';

class ImageProcessing {
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

  /// Add class-level constants for tuning
  static const int MIN_LINE_WIDTH = 15;  // Reduced minimum width
  static const int MIN_BLACK_PIXELS = 3;  // Reduced minimum black pixels
  static const double LUMINANCE_THRESHOLD = 120.0;  // Adjusted threshold
  static const int SCAN_LINES = 30;  // Increased number of scan lines
  
  // Add tracking for previous position
  static int? _previousCenterX;
  static DateTime _lastPositionUpdate = DateTime.now();
  static const int POSITION_RESET_MS = 1000; // Reset previous position after 1 second

  // Add new constants for line state tracking
  static const int STABLE_LINE_THRESHOLD = 5; // Number of consistent readings for stable line
  static const double RAPID_MOVEMENT_THRESHOLD = 30.0; // Deviation change threshold
  static List<double> _recentDeviations = [];
  static bool _isLineStable = false;

  /// Detects the center X position of the line in the image
  static int? detectLine(img.Image image, SettingsModel settings) {
    try {
      // Convert to grayscale and apply adaptive threshold
      img.grayscale(image);
      
      // Focus on the bottom portion of the image where the line is most likely to be
      int scanHeight = image.height ~/ 3;  // Bottom third of the image
      int startY = image.height - scanHeight;
      int endY = image.height;
      
      // Optimize scanning area width
      int marginX = image.width ~/ 6;  // Ignore edges
      int startX = marginX;
      int endX = image.width - marginX;
      
      List<int> linePositions = [];
      
      // Scan lines from bottom to top with adaptive step size
      for (int y = endY - 1; y >= startY; y -= 2) {
        List<int> darkPixels = [];
        int consecutiveDark = 0;
        int darkStart = -1;
        
        // Scan each row for dark pixels
        for (int x = startX; x < endX; x += 2) {
          final pixel = image.getPixel(x, y);
          int luminance = getLuminance(pixel);
          
          if (luminance < LUMINANCE_THRESHOLD) {
            if (darkStart == -1) darkStart = x;
            consecutiveDark++;
          } else if (consecutiveDark > 0) {
            // Found a potential line segment
            if (consecutiveDark >= MIN_BLACK_PIXELS) {
              int center = darkStart + (consecutiveDark ~/ 2);
              darkPixels.add(center);
            }
            consecutiveDark = 0;
            darkStart = -1;
          }
        }
        
        // Process dark pixels in this row
        if (darkPixels.isNotEmpty) {
          // Use the median position if multiple dark regions found
          darkPixels.sort();
          int medianPos = darkPixels[darkPixels.length ~/ 2];
          linePositions.add(medianPos);
        }
      }
      
      // Process collected line positions
      if (linePositions.isEmpty) return _previousCenterX;
      
      // Apply temporal smoothing
      DateTime now = DateTime.now();
      if (_previousCenterX != null && 
          now.difference(_lastPositionUpdate).inMilliseconds < POSITION_RESET_MS) {
        // Weight current and previous positions
        linePositions.add(_previousCenterX!);
        linePositions.add(_previousCenterX!);  // Add twice for more stability
      }
      
      // Calculate final position using median filtering
      linePositions.sort();
      int medianPosition = linePositions[linePositions.length ~/ 2];
      
      // Update tracking variables
      _previousCenterX = medianPosition;
      _lastPositionUpdate = now;
      
      return medianPosition;
      
    } catch (e) {
      print('Error in detectLine: $e');
      return _previousCenterX;
    }
  }

  /// Enhanced deviation calculation with movement detection
  static double calculateDeviation(int linePosition, int imageWidth) {
    double center = imageWidth / 2;
    double currentDeviation = ((linePosition - center) / center * 100).clamp(-100.0, 100.0);
    
    // Track recent deviations for stability analysis
    _recentDeviations.add(currentDeviation);
    if (_recentDeviations.length > STABLE_LINE_THRESHOLD) {
      _recentDeviations.removeAt(0);
    }
    
    // Calculate line stability
    if (_recentDeviations.length >= STABLE_LINE_THRESHOLD) {
      double maxDiff = 0;
      for (int i = 1; i < _recentDeviations.length; i++) {
        maxDiff = max(maxDiff, (_recentDeviations[i] - _recentDeviations[i-1]).abs());
      }
      _isLineStable = maxDiff < RAPID_MOVEMENT_THRESHOLD;
    }
    
    return currentDeviation;
  }

  static double _getColorDifference(Color c1, Color c2) {
    return sqrt(
      pow(c1.red - c2.red, 2) +
      pow(c1.green - c2.green, 2) +
      pow(c1.blue - c2.blue, 2)
    );
  }

  static Future<Map<String, dynamic>?> processImageInIsolate(Map<String, dynamic> params) async {
    try {
      final CameraImage image = params['image'] as CameraImage;
      final SettingsModel settings = params['settings'] as SettingsModel;

      final convertedImage = ImageProcessing.convertCameraImage(image);
      if (convertedImage == null) return null;

      final linePosition = ImageProcessing.detectLine(convertedImage, settings);
      if (linePosition == null) {
        return {
          'deviation': null,
          'isLeft': false,
          'isRight': false,
          'isCentered': false,
          'isLineLost': true,
          'isStable': false,
          'needsCorrection': false,
          'debugImage': null,
        };
      }

      final deviation = ImageProcessing.calculateDeviation(linePosition, convertedImage.width);
      
      // Enhanced state detection
      bool isLeft = deviation < -settings.sensitivity / 2;
      bool isRight = deviation > settings.sensitivity / 2;
      bool isCentered = deviation.abs() <= settings.sensitivity / 2;
      bool needsCorrection = deviation.abs() > settings.sensitivity * 0.75; // Urgent correction needed
      
      // Create debug image if needed
      Uint8List? debugImage;
      if (settings.showDebugView) {
        debugImage = ImageProcessing.createDebugImage(
          convertedImage,
          linePosition,
          deviation,
          settings,
        );
      }

      return {
        'deviation': deviation,
        'isLeft': isLeft,
        'isRight': isRight,
        'isCentered': isCentered,
        'isLineLost': false,
        'isStable': _isLineStable,
        'needsCorrection': needsCorrection,
        'debugImage': debugImage,
      };
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