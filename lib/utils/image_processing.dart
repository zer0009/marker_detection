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
    // Extract RGB components and cast them to int
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

  /// Detects the center X position of the line in the image
  static int? detectLine(img.Image image, SettingsModel settings) {
    try {
      int width = image.width;
      int height = image.height;
      int startY = (height * 1) ~/ 2;
      List<int> centerPoints = [];
      
      int scanStep = (height - startY) ~/ settings.scanLines;
      scanStep = scanStep.clamp(1, 5);
      
      // Reset previous position if too old
      if (DateTime.now().difference(_lastPositionUpdate).inMilliseconds > POSITION_RESET_MS) {
        _previousCenterX = null;
      }

      for (int y = height - 1; y >= startY; y -= scanStep) {
        List<int> blackRuns = [];
        int currentRun = 0;
        int runStart = -1;
        
        // Scan each row with higher precision
        for (int x = 0; x < width; x++) {
          final pixel = image.getPixel(x, y) as img.Pixel;
          double luminance = getLuminance(pixel).toDouble();
          
          if (luminance < settings.luminanceThreshold) {
            currentRun++;
            if (runStart == -1) runStart = x;
          } else {
            if (currentRun >= settings.minLineWidth) {
              int centerOfRun = runStart + (currentRun ~/ 2);
              // Only add runs that are within reasonable distance of previous position
              if (_previousCenterX == null || 
                  (centerOfRun - _previousCenterX!).abs() < width ~/ 4) {
                blackRuns.add(centerOfRun);
              }
            }
            currentRun = 0;
            runStart = -1;
          }
        }
        
        // Process the last run
        if (currentRun >= settings.minLineWidth) {
          int centerOfRun = runStart + (currentRun ~/ 2);
          if (_previousCenterX == null || 
              (centerOfRun - _previousCenterX!).abs() < width ~/ 4) {
            blackRuns.add(centerOfRun);
          }
        }
        
        if (blackRuns.isNotEmpty) {
          blackRuns.sort();
          int medianCenter = blackRuns[blackRuns.length ~/ 2];
          centerPoints.add(medianCenter);
        }
      }
      
      // Need at least 2 points to consider it a valid line
      if (centerPoints.length < 2) {
        return _previousCenterX;  // Return previous position if no new line detected
      }
      
      // Calculate new position
      centerPoints.sort();
      int newCenter = centerPoints[centerPoints.length ~/ 2];
      
      // Update tracking
      _previousCenterX = newCenter;
      _lastPositionUpdate = DateTime.now();
      
      return newCenter;
    } catch (e) {
      print('Error in detectLine: $e');
      return _previousCenterX;
    }
  }

  /// Enhanced deviation calculation with movement detection
  static double calculateDeviation(int centerX, int imageWidth) {
    double center = imageWidth / 2;
    double deviation = centerX - center;
    // More sensitive normalization
    deviation = (deviation / (imageWidth / 3)) * 100;  // Increased sensitivity
    deviation = deviation.clamp(-100.0, 100.0);  // Ensure within bounds
    print('Normalized deviation: $deviation');
    return deviation;
  }

  static double _getColorDifference(Color c1, Color c2) {
    return sqrt(
      pow(c1.red - c2.red, 2) +
      pow(c1.green - c2.green, 2) +
      pow(c1.blue - c2.blue, 2)
    );
  }
}