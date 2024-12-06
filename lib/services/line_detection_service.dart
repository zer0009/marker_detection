import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import '../models/line_detection_result.dart';
import '../utils/image_converter.dart';
import 'edge_detection_service.dart';

class LineDetectionService {
  // Cache the last known good position
  double _lastKnownPosition = 0.5;
  DateTime? _lastProcessingTime;
  static const int _processingInterval = 50; // milliseconds

  LineDetectionResult processFrame(CameraImage image) {
    try {
      // Implement frame skipping for performance
      if (_lastProcessingTime != null &&
          DateTime.now().difference(_lastProcessingTime!) <
              const Duration(milliseconds: _processingInterval)) {
        return _getResultFromPosition(_lastKnownPosition);
      }

      final convertedImage = ImageConverter.convertCameraImage(image);
      if (convertedImage == null) return LineDetectionResult.lineNotFound;

      // Process only the bottom third of the image for better performance
      final height = convertedImage.height;
      final startY = (height * 2 ~/ 3);
      final processHeight = height - startY;

      final croppedImage = img.copyCrop(
        convertedImage,
        x: 0,
        y: startY,
        width: convertedImage.width,
        height: processHeight,
      );

      final edges = EdgeDetectionService.calculateEdges(croppedImage);
      final position = _calculateLinePosition(edges);
      
      _lastKnownPosition = position;
      _lastProcessingTime = DateTime.now();

      return _getResultFromPosition(position);
    } catch (e) {
      print('Frame processing error: $e');
      return LineDetectionResult.lineNotFound;
    }
  }

  double getLinePosition(CameraImage image) {
    return _lastKnownPosition;
  }

  double _calculateLinePosition(List<List<int>> edges) {
    if (edges.isEmpty || edges[0].isEmpty) return 0.5;

    final width = edges[0].length;
    final height = edges.length;

    double weightedSum = 0;
    double totalWeight = 0;

    // Analyze only every other pixel for better performance
    for (int y = 0; y < height; y += 2) {
      for (int x = 0; x < width; x += 2) {
        final weight = edges[y][x].toDouble();
        weightedSum += x * weight;
        totalWeight += weight;
      }
    }

    if (totalWeight == 0) return _lastKnownPosition;

    // Calculate normalized position with smoothing
    final newPosition = (weightedSum / totalWeight) / width;
    return _smoothPosition(newPosition);
  }

  double _smoothPosition(double newPosition) {
    // Apply exponential smoothing
    const alpha = 0.3; // Smoothing factor
    return alpha * newPosition + (1 - alpha) * _lastKnownPosition;
  }

  LineDetectionResult _getResultFromPosition(double position) {
    const centerThreshold = 0.1; // 10% deviation threshold
    
    if ((position - 0.5).abs() < centerThreshold) {
      return LineDetectionResult.centered;
    } else if (position < 0.5) {
      return LineDetectionResult.leftDeviation;
    } else {
      return LineDetectionResult.rightDeviation;
    }
  }
}