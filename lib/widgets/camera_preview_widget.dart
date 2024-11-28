import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../services/line_detector.dart';
import '../models/settings_model.dart';

class CameraPreviewWidget extends StatelessWidget {
  const CameraPreviewWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final lineDetector = context.watch<LineDetector>();
    final settings = context.watch<SettingsModel>();
    final cameraController = lineDetector.cameraController;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return const Center(child: Text('Camera not initialized'));
    }

    return Stack(
      children: [
        // Camera preview with correct aspect ratio
        AspectRatio(
          aspectRatio: cameraController.value.aspectRatio,
          child: CameraPreview(cameraController),
        ),
        
        // Line detection overlay
        AspectRatio(
          aspectRatio: cameraController.value.aspectRatio,
          child: CustomPaint(
            painter: LineDetectionPainter(
              deviation: lineDetector.deviation,
              isLeft: lineDetector.isLeft,
              isRight: lineDetector.isRight,
              isCentered: lineDetector.isCentered,
              sensitivity: settings.sensitivity,
            ),
          ),
        ),

        // Debug info overlay
        if (settings.showDebugView)
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deviation: ${lineDetector.deviation?.toStringAsFixed(1) ?? "N/A"}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  Text(
                    'Status: ${_getStatusText(lineDetector)}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _getStatusText(LineDetector detector) {
    if (detector.isLeft) return 'Left';
    if (detector.isRight) return 'Right';
    if (detector.isCentered) return 'Centered';
    return 'No Line';
  }
}

class LineDetectionPainter extends CustomPainter {
  final double? deviation;
  final bool isLeft;
  final bool isRight;
  final bool isCentered;
  final double sensitivity;

  LineDetectionPainter({
    required this.deviation,
    required this.isLeft,
    required this.isRight,
    required this.isCentered,
    required this.sensitivity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 3.0;

    // Draw center reference line
    paint.color = Colors.green.withOpacity(0.3);
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );

    // Draw sensitivity boundaries
    double sensitivityWidth = (size.width * (sensitivity / 200)).clamp(
      size.width * 0.05,
      size.width * 0.5,
    );
    
    paint.color = Colors.yellow.withOpacity(0.3);
    // Left boundary
    canvas.drawLine(
      Offset(size.width / 2 - sensitivityWidth, 0),
      Offset(size.width / 2 - sensitivityWidth, size.height),
      paint,
    );
    // Right boundary
    canvas.drawLine(
      Offset(size.width / 2 + sensitivityWidth, 0),
      Offset(size.width / 2 + sensitivityWidth, size.height),
      paint,
    );

    // Draw detected line position
    if (deviation != null) {
      // Calculate position based on deviation
      double linePosition = size.width / 2 + (deviation! * size.width / 100);
      
      // Draw detected line
      paint
        ..color = _getLineColor()
        ..strokeWidth = 4.0;
      
      canvas.drawLine(
        Offset(linePosition, 0),
        Offset(linePosition, size.height),
        paint,
      );

      // Draw arrow indicating direction to move
      if (isLeft || isRight) {
        _drawDirectionArrow(canvas, size, linePosition, paint);
      }
    }

    // Draw target zone indicator
    if (isCentered) {
      paint
        ..color = Colors.green
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: sensitivityWidth * 2,
          height: 100,
        ),
        paint,
      );
    }
  }

  Color _getLineColor() {
    if (isCentered) return Colors.green;
    if (isLeft || isRight) return Colors.red;
    return Colors.blue;
  }

  void _drawDirectionArrow(Canvas canvas, Size size, double linePosition, Paint paint) {
    final arrowSize = size.width * 0.05;
    final centerY = size.height / 2;
    
    Path path = Path();
    if (isLeft) {
      // Draw arrow pointing right
      path.moveTo(linePosition + arrowSize, centerY);
      path.lineTo(linePosition, centerY + arrowSize);
      path.lineTo(linePosition, centerY - arrowSize);
      path.close();
    } else {
      // Draw arrow pointing left
      path.moveTo(linePosition - arrowSize, centerY);
      path.lineTo(linePosition, centerY + arrowSize);
      path.lineTo(linePosition, centerY - arrowSize);
      path.close();
    }
    
    paint.style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(LineDetectionPainter oldDelegate) {
    return oldDelegate.deviation != deviation ||
           oldDelegate.isLeft != isLeft ||
           oldDelegate.isRight != isRight ||
           oldDelegate.isCentered != isCentered ||
           oldDelegate.sensitivity != sensitivity;
  }
}