import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../services/line_detector.dart';
import '../models/settings_model.dart';
import '../widgets/line_follower_overlay.dart';
import 'line_detection_overlay.dart';

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
      fit: StackFit.expand,
      children: [
        // Camera preview
        AspectRatio(
          aspectRatio: cameraController.value.aspectRatio,
          child: CameraPreview(cameraController),
        ),
        
        // Line detection overlay
        if (settings.showLineHighlight)
          Positioned.fill(
            child: LineDetectionOverlay(
              deviation: lineDetector.deviation,
              isLineLost: lineDetector.isLineLost,
              imageSize: Size(
                MediaQuery.of(context).size.width,
                MediaQuery.of(context).size.height,
              ),
            ),
          ),

        // Line follower overlay
        Positioned.fill(
          child: LineFollowerOverlay(
            deviation: lineDetector.deviation,
            isLeft: lineDetector.isLeft,
            isRight: lineDetector.isRight,
            isCentered: lineDetector.isCentered,
          ),
        ),

        // Debug information
        if (settings.showDebugView)
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Line Status: ${_getStatusText(lineDetector)}',
                    style: TextStyle(
                      color: _getStatusColor(lineDetector),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Deviation: ${lineDetector.deviation?.toStringAsFixed(1) ?? "N/A"}',
                    style: TextStyle(color: Colors.white),
                  ),
                  Text(
                    'Confidence: ${_getConfidenceText(lineDetector)}',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

        // Debug view image
        if (settings.showDebugView && lineDetector.debugImageBytes != null)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              width: 160,
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.memory(
                  lineDetector.debugImageBytes!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _getStatusText(LineDetector detector) {
    if (detector.isLineLost) return 'LINE LOST';
    if (detector.isCentered) return 'CENTERED';
    if (detector.isLeft) return 'LEFT';
    if (detector.isRight) return 'RIGHT';
    return 'SEARCHING';
  }

  Color _getStatusColor(LineDetector detector) {
    if (detector.isLineLost) return Colors.red;
    if (detector.isCentered) return Colors.green;
    return Colors.yellow;
  }

  String _getConfidenceText(LineDetector detector) {
    if (detector.isStable) return 'HIGH';
    if (detector.isLineLost) return 'LOST';
    return 'MEDIUM';
  }
}