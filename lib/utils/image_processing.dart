// lib/utils/image_processing.dart
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

      // Assuming YUV420 format
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int uvIndex = (y ~/ 2) * (image.planes[1].bytesPerRow) + (x ~/ 2) * 2;
          final int Y = image.planes[0].bytes[y * image.planes[0].bytesPerRow + x];
          final int U = image.planes[1].bytes[uvIndex];
          final int V = image.planes[2].bytes[uvIndex];

          double R = Y + 1.370705 * (V - 128);
          double G = Y - 0.337633 * (U - 128) - 0.698001 * (V - 128);
          double B = Y + 1.732446 * (U - 128);

          R = R.clamp(0, 255).toDouble();
          G = G.clamp(0, 255).toDouble();
          B = B.clamp(0, 255).toDouble();

          imgImage.setPixelRgba(x, y, R.toInt(), G.toInt(), B.toInt(), 255);
        }
      }
      return imgImage;
    } catch (e) {
      print("Error converting image: $e");
      return null;
    }
  }

  /// Detects the center X position of the line in the image
  static int? detectLine(img.Image image) {
    try {
      // Convert to grayscale
      img.Image grayscale = img.grayscale(image);

      // Apply adaptive thresholding for better contrast with various line colors
      img.Image binary = adaptiveThreshold(grayscale, 128);

      // Optionally, apply Gaussian blur to reduce noise
      img.gaussianBlur(binary, radius: 1);

      // Focus on lower third of the image for better line detection
      int width = binary.width;
      int height = binary.height;
      int startY = (height * 2) ~/ 3; // Start from bottom third
      int sumX = 0;
      int count = 0;

      // Scan from bottom up
      for (int y = height - 1; y >= startY; y--) {
        int lineStartX = -1;
        int lineEndX = -1;

        // Scan each row for line segments
        for (int x = 0; x < width; x++) {
          // Get pixel value (in binary image, 0 is black and 255 is white)
          final pixel = image.getPixel(x, y);

          // Check if pixel is part of an edge (black or white)
          if ((getLuminance(pixel) < 128) || (getLuminance(pixel) > 128)) {
            if (lineStartX == -1) lineStartX = x;
            lineEndX = x;
          }
        }

        // If we found a line segment in this row
        if (lineStartX != -1 && lineEndX != -1) {
          // Calculate center of the line segment
          int centerOfLine = (lineStartX + lineEndX) ~/ 2;
          sumX += centerOfLine;
          count++;

          // Debug output
          print(
              'Line segment found at y=$y: start=$lineStartX, end=$lineEndX, center=$centerOfLine');
        }

        // If we've found enough line segments, break
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

  /// Adaptive Thresholding
  static img.Image adaptiveThreshold(img.Image src, int threshold) {
    // Define the size of the neighborhood
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
              sum += getLuminance(src.getPixel(nx, ny).value);
              count++;
            }
          }
        }
        double localThreshold = sum / count;
        if (getLuminance(src.getPixel(x, y).value) < localThreshold) {
          thresholded.setPixelRgba(x, y, 0, 0, 0, 255);
        } else {
          thresholded.setPixelRgba(x, y, 255, 255, 255, 255);
        }
      }
    }
    return thresholded;
  }

  /// Manually implemented Luminance calculation
  static int getLuminance(int color) {
    int r = getRed(color);
    int g = getGreen(color);
    int b = getBlue(color);
    // Using the Rec. 709 formula for luminance
    return ((0.2126 * r) + (0.7152 * g) + (0.0722 * b)).round();
  }

  /// Manually implemented Red component extraction
  static int getRed(int color) {
    return (color >> 16) & 0xFF;
  }

  /// Manually implemented Green component extraction
  static int getGreen(int color) {
    return (color >> 8) & 0xFF;
  }

  /// Manually implemented Blue component extraction
  static int getBlue(int color) {
    return color & 0xFF;
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