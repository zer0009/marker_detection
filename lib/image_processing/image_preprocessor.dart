import 'package:image/image.dart' as img;

/// Preprocesses images by applying Gaussian blur and converting to grayscale.
class ImagePreprocessor {
  /// Calculate luminance from pixel
  static int getLuminance(img.Pixel pixel) {
    int r = pixel.r.toInt();
    int g = pixel.g.toInt();
    int b = pixel.b.toInt();
    return ((0.2126 * r) + (0.7152 * g) + (0.0722 * b)).round();
  }

  /// Apply Gaussian blur
  static img.Image applyGaussianBlur(img.Image source, int kernelSize) {
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

        int avg = (sum / count).round();
        blurred.setPixelRgba(x, y, avg, avg, avg, 255);
      }
    }

    return blurred;
  }

  /// Preprocess image by applying Gaussian blur and converting to grayscale
  static img.Image preprocessImage(img.Image image) {
    img.Image blurred = applyGaussianBlur(image, 5);
    return img.grayscale(blurred);
  }
}