import 'dart:math' as math;
import 'package:image/image.dart' as img;
import '../models/settings_model.dart';
import 'image_preprocessor.dart';

class EdgeDetector {
  /// Detect edges using Sobel operator
  static img.Image detectEdges(img.Image source, SettingsModel settings) {
    img.Image edges = img.Image(width: source.width, height: source.height);
    int threshold1 = settings.cannyThreshold1.round() + 20;
    int threshold2 = settings.cannyThreshold2.round() + 20;
    
    int startY = (source.height * 2) ~/ 3;

    for (int y = startY + 1; y < source.height - 1; y++) {
      for (int x = 1; x < source.width - 1; x++) {
        int gx = _calculateSobelX(source, x, y);
        int gy = _calculateSobelY(source, x, y);

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

  static int _calculateSobelX(img.Image source, int x, int y) {
    return -ImagePreprocessor.getLuminance(source.getPixel(x-1, y-1)) +
           ImagePreprocessor.getLuminance(source.getPixel(x+1, y-1)) +
           -2 * ImagePreprocessor.getLuminance(source.getPixel(x-1, y)) +
           2 * ImagePreprocessor.getLuminance(source.getPixel(x+1, y)) +
           -ImagePreprocessor.getLuminance(source.getPixel(x-1, y+1)) +
           ImagePreprocessor.getLuminance(source.getPixel(x+1, y+1));
  }

  static int _calculateSobelY(img.Image source, int x, int y) {
    return -ImagePreprocessor.getLuminance(source.getPixel(x-1, y-1)) +
           -2 * ImagePreprocessor.getLuminance(source.getPixel(x, y-1)) +
           -ImagePreprocessor.getLuminance(source.getPixel(x+1, y-1)) +
           ImagePreprocessor.getLuminance(source.getPixel(x-1, y+1)) +
           2 * ImagePreprocessor.getLuminance(source.getPixel(x, y+1)) +
           ImagePreprocessor.getLuminance(source.getPixel(x+1, y+1));
  }
}