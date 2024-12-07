import 'package:image/image.dart' as img;

class EdgeDetectionService {
  static List<List<int>> calculateEdges(img.Image image) {
    final edges = List.generate(
      image.height,
      (y) => List.generate(image.width, (x) => _calculateEdgeValue(image, x, y)),
    );
    return edges;
  }

  static int _calculateEdgeValue(img.Image image, int x, int y) {
    // Sobel operator for edge detection
    if (x == 0 || x >= image.width - 1 || y == 0 || y >= image.height - 1) {
      return 0;
    }

    // Horizontal Sobel
    final gx = -1 * image.getPixel(x - 1, y - 1).r +
        -2 * image.getPixel(x - 1, y).r +
        -1 * image.getPixel(x - 1, y + 1).r +
        1 * image.getPixel(x + 1, y - 1).r +
        2 * image.getPixel(x + 1, y).r +
        1 * image.getPixel(x + 1, y + 1).r;

    // Vertical Sobel
    final gy = -1 * image.getPixel(x - 1, y - 1).r +
        -2 * image.getPixel(x, y - 1).r +
        -1 * image.getPixel(x + 1, y - 1).r +
        1 * image.getPixel(x - 1, y + 1).r +
        2 * image.getPixel(x, y + 1).r +
        1 * image.getPixel(x + 1, y + 1).r;

    return ((gx * gx + gy * gy) / 8).round().clamp(0, 255);
  }
}