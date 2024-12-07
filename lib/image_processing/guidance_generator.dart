import '../models/line_position.dart';

/// Generates clear audio guidance instructions.
class GuidanceGenerator {
  static const double SLIGHT_DEVIATION = 15.0;
  static const double MODERATE_DEVIATION = 30.0;
  
  /// Generates guidance based on analysis and safety validation.
  static String generateGuidance(Map<String, dynamic> analysis, Map<String, dynamic> safety) {
    if (!safety['isSafe']) {
      return _generateSafetyWarning(safety['warning']);
    }

    double? deviation = analysis['deviation'] as double?;
    LinePosition linePosition = _mapToLinePosition(analysis);
    bool isStable = analysis['isStable'] as bool;

    if (deviation == null || linePosition == LinePosition.unknown) {
      return 'Stop. Path lost.';
    }

    if (!isStable) {
      return _generateStabilityWarning(linePosition);
    }

    return _generateDirectionalGuidance(deviation);
  }

  static String _generateDirectionalGuidance(double deviation) {
    if (deviation.abs() < SLIGHT_DEVIATION) {
      return 'Maintaining position.';
    } else if (deviation.abs() < MODERATE_DEVIATION) {
      return deviation > 0 
          ? 'Move slightly to the right.' 
          : 'Move slightly to the left.';
    } else {
      return deviation > 0 
          ? 'Move right swiftly.' 
          : 'Move left swiftly.';
    }
  }

  static String _generateStabilityWarning(LinePosition linePosition) {
    switch (linePosition) {
      case LinePosition.visible:
        return 'Line unstable. Stabilizing.';
      case LinePosition.enteringLeft:
      case LinePosition.enteringRight:
        return 'Line entering. Stabilizing.';
      case LinePosition.leavingLeft:
      case LinePosition.leavingRight:
        return 'Line leaving. Stabilizing.';
      default:
        return 'Line status unclear.';
    }
  }

  static String _generateSafetyWarning(String warning) {
    switch (warning) {
      case 'No path detected':
        return 'Stop immediately. No path detected';
      case 'Path too narrow':
        return 'Caution. Path narrowing';
      case 'Low confidence in path detection':
        return 'Warning. Path unclear';
      case 'Potential obstacle detected':
        return 'Stop. Obstacle ahead';
      default:
        return 'Stop. Unsafe conditions';
    }
  }

  static LinePosition _mapToLinePosition(Map<String, dynamic> analysis) {
    if (analysis['isLeft'] as bool) return LinePosition.enteringLeft;
    if (analysis['isRight'] as bool) return LinePosition.enteringRight;
    if ((analysis['isCentered'] as bool) && (analysis['isStable'] as bool)) return LinePosition.visible;
    return LinePosition.unknown;
  }
}