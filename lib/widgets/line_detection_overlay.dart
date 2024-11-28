import 'package:flutter/material.dart';

class LineDetectionOverlay extends StatelessWidget {
  final double? deviation;
  final bool isLineLost;
  final Size imageSize;
  final double lineWidth;

  const LineDetectionOverlay({
    Key? key,
    required this.deviation,
    required this.isLineLost,
    required this.imageSize,
    this.lineWidth = 4.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (deviation == null || isLineLost) return Container();

    final center = imageSize.width / 2;
    final linePosition = center + (deviation! * center / 100);

    return CustomPaint(
      size: imageSize,
      painter: LineHighlightPainter(
        linePosition: linePosition,
        lineWidth: lineWidth,
        isLost: isLineLost,
      ),
    );
  }
}

class LineHighlightPainter extends CustomPainter {
  final double linePosition;
  final double lineWidth;
  final bool isLost;

  LineHighlightPainter({
    required this.linePosition,
    required this.lineWidth,
    required this.isLost,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isLost ? Colors.red.withOpacity(0.5) : Colors.green.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth;

    // Draw vertical line
    canvas.drawLine(
      Offset(linePosition, 0),
      Offset(linePosition, size.height),
      paint,
    );

    // Draw detection area
    final areaPath = Path()
      ..moveTo(linePosition - 20, size.height)
      ..lineTo(linePosition + 20, size.height)
      ..lineTo(linePosition + 10, size.height - 50)
      ..lineTo(linePosition - 10, size.height - 50)
      ..close();

    final areaPaint = Paint()
      ..color = isLost ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    canvas.drawPath(areaPath, areaPaint);
  }

  @override
  bool shouldRepaint(LineHighlightPainter oldDelegate) {
    return linePosition != oldDelegate.linePosition ||
           isLost != oldDelegate.isLost;
  }
} 