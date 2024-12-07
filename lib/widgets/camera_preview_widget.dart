import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../services/line_detector.dart';
import '../models/settings_model.dart';
import '../widgets/line_follower_overlay.dart';
import 'debug_view.dart';

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
        
        // Line follower overlay
        Positioned.fill(
          child: LineFollowerOverlay(
            deviation: lineDetector.deviation,
            isLeft: lineDetector.isLeft,
            isRight: lineDetector.isRight,
            isCentered: lineDetector.isCentered,
            isLineVisible: !lineDetector.isLineLost,
            linePosition: lineDetector.linePosition,
            isStable: lineDetector.isStable,
            confidenceScore: lineDetector.confidence,
          ),
        ),

        // Debug view only when enabled
        if (settings.showDebugView)
          Positioned(
            top: 10,
            right: 10,
            child: DebugView(
              lineDetector: lineDetector,
              debugImageBytes: lineDetector.debugImageBytes,
            ),
          ),
      ],
    );
  }
}