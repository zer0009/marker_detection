// lib/utils/image_processing.dart
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

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
    int windowSize = 15;
    img.Image thresholded = img.Image.from(src);
    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        int sum = 0;
        int count = 0;
        for (int ky = -windowSize ~/ 2; ky <= windowSize ~/ 2; ky++) {
          for (int kx = -windowSize ~/ 2; kx <= windowSize ~/ 2; kx++) {
            int ny = y + ky;
            int nx = x + kx;
            if (nx >= 0 && nx < src.width && ny >= 0 && ny < src.height) {
              sum += getLuminance(src.getPixel(nx, ny) as img.Pixel);
              count++;
            }
          }
        }
        int localThreshold = (sum / count).round();
        if (getLuminance(src.getPixel(x, y) as img.Pixel) < localThreshold) {
          thresholded.setPixelRgba(x, y, 0, 0, 0, 255);
        } else {
          thresholded.setPixelRgba(x, y, 255, 255, 255, 255);
        }
      }
    }
    return thresholded;
  }

  /// Detects the center X position of the line in the image
  static int? detectLine(img.Image image) {
    try {
      // Convert to grayscale
      img.Image grayscale = img.grayscale(image);

      // Apply adaptive thresholding for better contrast with various line colors
      img.Image binary = adaptiveThreshold(grayscale, 128);

      // Apply Gaussian blur to reduce noise
      binary = img.gaussianBlur(binary, radius: 1);

      // Focus on lower third of the image for better line detection
      int width = binary.width;
      int height = binary.height;
      int startY = (height * 2) ~/ 3;
      int sumX = 0;
      int count = 0;

      // Scan from bottom up
      for (int y = height - 1; y >= startY; y--) {
        int lineStartX = -1;
        int lineEndX = -1;

        // Scan each row for line segments
        for (int x = 0; x < width; x++) {
          final pixel = binary.getPixel(x, y) as img.Pixel;
          
          // Detect black pixels as part of the line
          if (getLuminance(pixel) < 128) {
            if (lineStartX == -1) lineStartX = x;
            lineEndX = x;
          }
        }

        // If we found a line segment in this row
        if (lineStartX != -1 && lineEndX != -1) {
          int centerOfLine = (lineStartX + lineEndX) ~/ 2;
          sumX += centerOfLine;
          count++;
          print('Line segment found at y=$y: start=$lineStartX, end=$lineEndX, center=$centerOfLine');
        }

        if (count >= 5) break;
      }

      if (count == 0) {
        print('No line detected');
        return null;
      }

      int centerX = (sumX / count).round();
      print('Final centerX: $centerX (averaged from $count points)');
      return centerX;
    } catch (e) {
      print('Error in detectLine: $e');
      return null;
    }
  }

  /// Calculates deviation from the center of the image
  static double calculateDeviation(int centerX, int imageWidth) {
    double center = imageWidth / 2;
    double deviation = centerX - center;
    // Normalize deviation to be between -100 and 100
    deviation = (deviation / (imageWidth / 2)) * 100;
    print('Normalized deviation: $deviation');
    return deviation;
  }
}