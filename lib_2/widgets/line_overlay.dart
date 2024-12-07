import 'package:flutter/material.dart';
import '../models/line_detection_result.dart';

class LineOverlay extends StatelessWidget {
  final LineDetectionResult result;
  final double linePosition; // Position of the detected line (0.0 to 1.0)

  const LineOverlay({
    Key? key,
    required this.result,
    required this.linePosition,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: LineOverlayPainter(
          result: result,
          linePosition: linePosition,
        ),
      ),
    );
  }
}

class LineOverlayPainter extends CustomPainter {
  final LineDetectionResult result;
  final double linePosition;

  LineOverlayPainter({
    required this.result,
    required this.linePosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    // Draw center guide line
    paint.color = Colors.white.withOpacity(0.3);
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );

    // Draw detected line
    switch (result) {
      case LineDetectionResult.centered:
        paint.color = Colors.green;
        break;
      case LineDetectionResult.leftDeviation:
        paint.color = Colors.red;
        break;
      case LineDetectionResult.rightDeviation:
        paint.color = Colors.blue;
        break;
      case LineDetectionResult.lineNotFound:
        return; // Don't draw line if none detected
    }

    final lineX = size.width * linePosition;
    canvas.drawLine(
      Offset(lineX, 0),
      Offset(lineX, size.height),
      paint,
    );

    // Draw guidance arrows when not centered
    if (result != LineDetectionResult.centered && 
        result != LineDetectionResult.lineNotFound) {
      _drawGuidanceArrow(canvas, size, paint);
    }
  }

  void _drawGuidanceArrow(Canvas canvas, Size size, Paint paint) {
    const arrowSize = 40.0;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    
    paint.style = PaintingStyle.fill;

    final path = Path();
    if (result == LineDetectionResult.leftDeviation) {
      // Draw arrow pointing right
      path.moveTo(centerX - arrowSize, centerY - arrowSize);
      path.lineTo(centerX + arrowSize, centerY);
      path.lineTo(centerX - arrowSize, centerY + arrowSize);
    } else {
      // Draw arrow pointing left
      path.moveTo(centerX + arrowSize, centerY - arrowSize);
      path.lineTo(centerX - arrowSize, centerY);
      path.lineTo(centerX + arrowSize, centerY + arrowSize);
    }
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(LineOverlayPainter oldDelegate) {
    return oldDelegate.result != result || 
           oldDelegate.linePosition != linePosition;
  }
} 