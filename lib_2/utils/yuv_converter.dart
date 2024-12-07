import 'dart:math';

class YuvConverter {
  static (int, int, int) yuvToRgb(int y, int u, int v) {
    final r = (y + 1.402 * (v - 128)).round().clamp(0, 255);
    final g = (y - 0.344 * (u - 128) - 0.714 * (v - 128)).round().clamp(0, 255);
    final b = (y + 1.772 * (u - 128)).round().clamp(0, 255);
    return (r, g, b);
  }
}