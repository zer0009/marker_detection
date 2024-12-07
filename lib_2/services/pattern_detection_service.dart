class PatternDetectionService {
  static bool hasDiagonalPattern(List<List<int>> edges) {
    final height = edges.length;
    if (height == 0) return false;
    final width = edges[0].length;
    
    int diagonalCount = 0;
    final threshold = 50;
    
    // Check main diagonal pattern
    for (int i = 1; i < height - 1 && i < width - 1; i++) {
      if (edges[i][i] > threshold && 
          edges[i-1][i-1] > threshold && 
          edges[i+1][i+1] > threshold) {
        diagonalCount++;
      }
    }
    
    return diagonalCount > height ~/ 4;
  }

  static bool hasHorizontalPattern(List<List<int>> edges) {
    final height = edges.length;
    if (height == 0) return false;
    final width = edges[0].length;
    
    int horizontalCount = 0;
    final threshold = 50;
    
    for (int y = 1; y < height - 1; y++) {
      int lineLength = 0;
      for (int x = 0; x < width; x++) {
        if (edges[y][x] > threshold) {
          lineLength++;
        } else if (lineLength > width ~/ 3) {
          horizontalCount++;
          lineLength = 0;
        } else {
          lineLength = 0;
        }
      }
      if (lineLength > width ~/ 3) horizontalCount++;
    }
    
    return horizontalCount > 0;
  }

  static bool hasVerticalPattern(List<List<int>> edges) {
    final height = edges.length;
    if (height == 0) return false;
    final width = edges[0].length;
    
    int verticalCount = 0;
    final threshold = 50;
    
    for (int x = 1; x < width - 1; x++) {
      int lineLength = 0;
      for (int y = 0; y < height; y++) {
        if (edges[y][x] > threshold) {
          lineLength++;
        } else if (lineLength > height ~/ 3) {
          verticalCount++;
          lineLength = 0;
        } else {
          lineLength = 0;
        }
      }
      if (lineLength > height ~/ 3) verticalCount++;
    }
    
    return verticalCount > 0;
  }
}