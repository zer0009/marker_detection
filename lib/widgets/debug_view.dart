import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/line_detector.dart';
import '../models/line_position.dart';

class DebugView extends StatelessWidget {
  final LineDetector lineDetector;
  final Uint8List? debugImageBytes;

  const DebugView({
    Key? key,
    required this.lineDetector,
    this.debugImageBytes,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Debug image
        if (debugImageBytes != null)
          Container(
            width: 160,
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(
                debugImageBytes!,
                fit: BoxFit.cover,
              ),
            ),
          ),
        
        const SizedBox(height: 8),
        
        // Debug info
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Status: ${_getStatusText()}',
                style: TextStyle(
                  color: _getStatusColor(),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Position: ${_getPositionText()}',
                style: const TextStyle(color: Colors.white),
              ),
              Text(
                'Deviation: ${lineDetector.deviation?.toStringAsFixed(1) ?? "N/A"}',
                style: const TextStyle(color: Colors.white),
              ),
              Text(
                'Confidence: ${_getConfidenceText()}',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getStatusText() {
    if (lineDetector.isLineLost) return 'LINE LOST';
    if (lineDetector.isCentered) return 'CENTERED';
    if (lineDetector.isLeft) return 'LEFT';
    if (lineDetector.isRight) return 'RIGHT';
    return 'SEARCHING';
  }

  String _getPositionText() {
    switch (lineDetector.linePosition) {
      case LinePosition.unknown:
        return 'No Line';
      case LinePosition.enteringLeft:
        return 'Entering Left';
      case LinePosition.enteringRight:
        return 'Entering Right';
      case LinePosition.leavingLeft:
        return 'Leaving Left';
      case LinePosition.leavingRight:
        return 'Leaving Right';
      case LinePosition.visible:
        return 'Visible';
    }
  }

  Color _getStatusColor() {
    if (lineDetector.isLineLost) return Colors.red;
    if (lineDetector.isCentered) return Colors.green;
    return Colors.yellow;
  }

  String _getConfidenceText() {
    if (lineDetector.isStable) return 'HIGH';
    if (lineDetector.isLineLost) return 'LOST';
    return 'MEDIUM';
  }
} 