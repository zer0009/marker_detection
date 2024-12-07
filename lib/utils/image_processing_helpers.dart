import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

import '../models/settings_model.dart';
import '../models/line_position.dart';
import 'image_processing.dart';

class ImageProcessingHelpers {
  static img.Image? convertCameraImage(CameraImage image) {
    try {
      final int width = image.width;
      final int height = image.height;
      final img.Image imgImage = img.Image(width: width, height: height);

      if (image.planes.length < 3) {
        print("Invalid number of planes in CameraImage");
        return null;
      }

      final Uint8List yPlane = image.planes[0].bytes;
      final Uint8List uPlane = image.planes[1].bytes;
      final Uint8List vPlane = image.planes[2].bytes;

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int uvIndex = (y ~/ 2) * (image.planes[1].bytesPerRow) + (x ~/ 2) * 2;
          if (uvIndex + 1 >= uPlane.length || uvIndex + 1 >= vPlane.length) {
            continue;
          }
          final int Y = yPlane[y * image.planes[0].bytesPerRow + x];
          final int U = uPlane[uvIndex];
          final int V = vPlane[uvIndex + 1];

          int C = Y - 16;
          int D = U - 128;
          int E = V - 128;

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

  static double getLuminance(img.Pixel pixel) {
    int r = pixel.r.toInt();
    int g = pixel.g.toInt();
    int b = pixel.b.toInt();
    return (0.2126 * r + 0.7152 * g + 0.0722 * b);
  }

  static img.Image preprocessImage(img.Image source) {
    // Convert to grayscale and apply Gaussian blur
    var grayscale = img.grayscale(source);
    var blurred = img.gaussianBlur(
      grayscale,
      radius: ImageProcessing.GAUSSIAN_KERNEL_SIZE,
    );
    
    // Apply edge detection using Sobel operator
    var edges = img.sobel(blurred);
    
    // Threshold the edges to create binary image
    for (var y = 0; y < edges.height; y++) {
      for (var x = 0; x < edges.width; x++) {
        var pixel = edges.getPixel(x, y);
        var luminance = getLuminance(pixel);
        if (luminance > ImageProcessing.CANNY_LOW_THRESHOLD) {
          edges.setPixelRgba(x, y, 255, 255, 255, 255);  // White
        } else {
          edges.setPixelRgba(x, y, 0, 0, 0, 255);  // Black
        }
      }
    }
    
    return edges;
  }

  static img.Image createROIMask(img.Image source) {
    final mask = img.Image(width: source.width, height: source.height);
    final height = source.height;
    final width = source.width;
    
    // Define ROI trapezoid (adjust these values based on your needs)
    final topWidth = width * 0.5;    // Width at the top of trapezoid
    final bottomWidth = width * 0.8;  // Width at the bottom of trapezoid
    final topY = height * 0.3;        // Start from 30% from the top
    
    // Draw white trapezoid on black background
    for (var y = (topY).toInt(); y < height; y++) {
      var progress = (y - topY) / (height - topY);
      var currentWidth = topWidth + (bottomWidth - topWidth) * progress;
      var startX = (width - currentWidth) ~/ 2;
      var endX = startX + currentWidth.toInt();
      
      for (var x = startX; x < endX; x++) {
        mask.setPixel(x, y, img.ColorRgb8(255, 255, 255));
      }
    }
    
    return mask;
  }

  static img.Image applyMask(img.Image edges, img.Image mask) {
    final result = img.Image(width: edges.width, height: edges.height);
    
    for (var y = 0; y < edges.height; y++) {
      for (var x = 0; x < edges.width; x++) {
        var edgePixel = edges.getPixel(x, y);
        var maskPixel = mask.getPixel(x, y);
        
        // Only keep edge pixels where mask is white
        if (getLuminance(maskPixel) > 127) {
          result.setPixel(x, y, edgePixel);
        }
      }
    }
    
    return result;
  }

  static List<List<int>> findLinesEnhanced(img.Image edges, SettingsModel settings) {
    final lines = <List<int>>[];
    final width = edges.width;
    final height = edges.height;
    
    // Scan more frequently for better detection
    for (var y = 0; y < height; y += 1) {  // Changed from 2 to 1
      var startX = -1;
      var lineLength = 0;
      
      for (var x = 0; x < width; x++) {
        var pixel = edges.getPixel(x, y);
        var isEdge = getLuminance(pixel) > 127;
        
        if (isEdge) {
          if (startX == -1) startX = x;
          lineLength++;
        } else if (startX != -1) {
          // Reduced minimum line length for better detection
          if (lineLength >= ImageProcessing.MIN_LINE_LENGTH ~/ 2) {
            lines.add([startX, y, x, y]);
          }
          startX = -1;
          lineLength = 0;
        }
      }
      
      if (startX != -1 && lineLength >= ImageProcessing.MIN_LINE_LENGTH ~/ 2) {
        lines.add([startX, y, width - 1, y]);
      }
    }
    
    return lines;
  }

  static Map<String, dynamic> analyzeLinesPosition(List<List<int>> lines, double imageWidth) {
    if (lines.isEmpty) return createEmptyResult();
    
    double totalX = 0.0;
    double validLines = 0.0;
    
    for (var line in lines) {
      double centerX = (line[0].toDouble() + line[2].toDouble()) / 2.0;
      double yDiff = (line[3].toDouble() - line[1].toDouble()).abs();
      
      // More lenient angle threshold
      if (yDiff < 15.0) {  // Increased from 10.0
        totalX += centerX;
        validLines += 1.0;
      }
    }
    
    if (validLines < 0.5) return createEmptyResult();
    
    double averageX = totalX / validLines;
    double center = imageWidth / 2.0;
    double deviation = (averageX - center) / center;

    // More lenient thresholds for position detection
    bool isLeft = deviation < -0.15;  // Changed from -0.2
    bool isRight = deviation > 0.15;  // Changed from 0.2
    bool isCentered = deviation.abs() <= 0.15;  // Changed from 0.2

    LinePosition position = _determineDetailedLinePosition(deviation, lines.length);
    bool isStable = lines.length >= 2 && validLines >= 1.5;  // More lenient stability check

    return {
      'deviation': deviation,
      'isLeft': isLeft,
      'isRight': isRight,
      'isCentered': isCentered,
      'isLineLost': false,
      'isStable': isStable,
      'needsCorrection': deviation.abs() > 0.1,
      'linePosition': position,
      'confidence': validLines / lines.length.toDouble(),
    };
  }

  static LinePosition _determineDetailedLinePosition(double deviation, int lineCount) {
    if (lineCount < 2) return LinePosition.unknown;
    
    // More detailed position analysis
    if (deviation < -0.5) {
      return LinePosition.enteringLeft;
    } else if (deviation > 0.5) {
      return LinePosition.enteringRight;
    } else if (deviation < -0.2) {
      return LinePosition.leavingLeft;
    } else if (deviation > 0.2) {
      return LinePosition.leavingRight;
    } else {
      return LinePosition.visible;
    }
  }

  static Map<String, dynamic> createEmptyResult() {
    return {
      'deviation': 0.0,
      'isLeft': false,
      'isRight': false,
      'isCentered': false,
      'isLineLost': true,
      'isStable': false,
      'needsCorrection': true,
      'linePosition': LinePosition.unknown,
      'confidence': 0.0,  // Add confidence score
    };
  }

  static Uint8List? createDebugImage(img.Image sourceImage, List<List<int>> lines, Map<String, dynamic> analysis) {
    // Create a copy of the source image for debugging
    var debugImage = img.copyResize(sourceImage, width: sourceImage.width, height: sourceImage.height);
    
    // Define centerX at the beginning
    int centerX = sourceImage.width ~/ 2;
    
    // Draw ROI trapezoid
    _drawROI(debugImage);
    
    // Draw detected line segments with thicker lines
    for (var line in lines) {
      int yDiff = (line[3] - line[1]).abs();
      var color = yDiff < 10 ? 
          img.ColorRgb8(0, 255, 0) :  // Valid lines in bright green
          img.ColorRgb8(255, 0, 0);   // Invalid lines in bright red
      
      img.drawLine(
        debugImage,
        x1: line[0],
        y1: line[1],
        x2: line[2],
        y2: line[3],
        color: color,
        thickness: 3,  // Increased thickness
      );
    }
    
    // Add deviation indicator with increased visibility
    if (analysis['deviation'] != null) {
      int deviationX = (centerX + analysis['deviation'] * centerX).round();
      img.drawLine(
        debugImage,
        x1: deviationX,
        y1: 0,
        x2: deviationX,
        y2: sourceImage.height,
        color: img.ColorRgb8(255, 255, 0),  // Bright yellow
        thickness: 2,  // Increased thickness
      );
    }

    // Draw center indicator with maximum visibility
    img.drawLine(
      debugImage,
      x1: centerX,
      y1: 0,
      x2: centerX,
      y2: sourceImage.height,
      color: img.ColorRgb8(0, 255, 255),  // Changed to cyan for better visibility
      thickness: 4,  // Increased thickness further
    );
    
    return img.encodeJpg(debugImage);
  }

  static void _drawROI(img.Image image) {
    final height = image.height;
    final width = image.width;
    final topWidth = width * 0.5;
    final bottomWidth = width * 0.8;
    final topY = height * 0.3;
    
    // Draw trapezoid outline
    var points = [
      [(width - topWidth) ~/ 2, topY.round()],
      [(width + topWidth) ~/ 2, topY.round()],
      [(width + bottomWidth) ~/ 2, height],
      [(width - bottomWidth) ~/ 2, height],
    ];
    
    for (int i = 0; i < points.length; i++) {
      var start = points[i];
      var end = points[(i + 1) % points.length];
      img.drawLine(
        image,
        x1: start[0],
        y1: start[1],
        x2: end[0],
        y2: end[1],
        color: img.ColorRgb8(255, 165, 0),  // Orange color for ROI
        thickness: 1,
      );
    }
  }
} 