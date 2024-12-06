import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class ImageConverter {
  /// Converts CameraImage to img.Image
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
          final int u = uPlane[uvIndex];
          final int v = vPlane[uvIndex + 1];
          final int yValue = yPlane[y * image.planes[0].bytesPerRow + x];

          // Convert YUV to RGB
          int r = (yValue + 1.402 * (v - 128)).round();
          int g = (yValue - 0.344136 * (u - 128) - 0.714136 * (v - 128)).round();
          int b = (yValue + 1.772 * (u - 128)).round();

          // Clamp to valid range
          r = r.clamp(0, 255);
          g = g.clamp(0, 255);
          b = b.clamp(0, 255);

          imgImage.setPixelRgba(x, y, r, g, b, 255);
        }
      }

      return imgImage;
    } catch (e) {
      print('Error converting CameraImage to img.Image: $e');
      return null;
    }
  }

  /// Convert serialized image data back to img.Image
  static img.Image? convertFromImageData(Map<String, dynamic> imageData) {
    try {
      final width = imageData['width'] as int;
      final height = imageData['height'] as int;
      final planes = imageData['planes'] as List;
      
      final img.Image image = img.Image(width: width, height: height);
      
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