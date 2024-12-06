import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'yuv_converter.dart';

class ImageConverter {
  static img.Image? convertCameraImage(CameraImage cameraImage) {
    try {
      final planes = cameraImage.planes;
      if (planes.length < 3) return null;

      final width = cameraImage.width;
      final height = cameraImage.height;

      final yBuffer = planes[0].bytes;
      final uBuffer = planes[1].bytes;
      final vBuffer = planes[2].bytes;

      if (yBuffer.isEmpty || uBuffer.isEmpty || vBuffer.isEmpty) return null;

      final int yRowStride = planes[0].bytesPerRow;
      final int uvRowStride = planes[1].bytesPerRow;
      final int uvPixelStride = planes[1].bytesPerPixel ?? 1;

      final img.Image result = img.Image(
        width: width,
        height: height,
        numChannels: 3,
      );

      for (int h = 0; h < height; h++) {
        for (int w = 0; w < width; w++) {
          final yIndex = h * yRowStride + w;
          final uvIndex = (h >> 1) * uvRowStride + (w >> 1) * uvPixelStride;

          final y = yIndex < yBuffer.length ? yBuffer[yIndex] : 0;
          final u = uvIndex < uBuffer.length ? uBuffer[uvIndex] : 128;
          final v = uvIndex < vBuffer.length ? vBuffer[uvIndex] : 128;

          final (r, g, b) = YuvConverter.yuvToRgb(y, u, v);
          result.setPixelRgb(w, h, r, g, b);
        }
      }

      return result;
    } catch (e) {
      print('Image conversion error: $e');
      return null;
    }
  }
}