import 'package:flutter/material.dart';
import '../models/line_detection_result.dart';

class DetectionIndicator extends StatelessWidget {
  final LineDetectionResult result;

  const DetectionIndicator({Key? key, required this.result}) : super(key: key);

  Color _getIndicationColor(LineDetectionResult result) {
    switch (result) {
      case LineDetectionResult.leftDeviation:
        return Colors.red;
      case LineDetectionResult.rightDeviation:
        return Colors.blue;
      case LineDetectionResult.centered:
        return Colors.green;
      case LineDetectionResult.lineNotFound:
      default:
        return Colors.grey;
    }
  }

  String _getIndicationText(LineDetectionResult result) {
    switch (result) {
      case LineDetectionResult.leftDeviation:
        return 'Move Right';
      case LineDetectionResult.rightDeviation:
        return 'Move Left';
      case LineDetectionResult.centered:
        return 'Centered';
      case LineDetectionResult.lineNotFound:
        return 'Line Lost';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getIndicationColor(result);
    final text = _getIndicationText(result);

    return Container(
      padding: const EdgeInsets.all(16),
      color: color,
      child: Center(
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }
}