import 'package:flutter/material.dart';
import '../models/line_position.dart';

class LineFollowerOverlay extends StatelessWidget {
  final double? deviation;
  final bool isLeft;
  final bool isRight;
  final bool isCentered;
  final bool isLineVisible;
  final LinePosition linePosition;
  final double confidenceScore;
  final bool isStable;

  const LineFollowerOverlay({
    Key? key,
    this.deviation,
    required this.isLeft,
    required this.isRight,
    required this.isCentered,
    required this.isLineVisible,
    required this.linePosition,
    this.confidenceScore = 0.0,
    this.isStable = false,
  }) : super(key: key);

  Widget _buildRegions() {
    return Row(
      children: [
        _buildRegion('LEFT', isLeft),
        _buildRegion('CENTER', isCentered),
        _buildRegion('RIGHT', isRight),
      ],
    );
  }

  Widget _buildRegion(String label, bool isActive) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: _getRegionColor(label, isActive).withOpacity(0.5),
            width: 2,
          ),
          color: _getRegionColor(label, isActive).withOpacity(0.1),
        ),
        child: Center(
          child: RotatedBox(
            quarterTurns: 3,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getRegionColor(String region, bool isActive) {
    if (!isActive) return Colors.white24;
    switch (region) {
      case 'CENTER':
        return isStable ? Colors.green : Colors.yellow;
      default:
        return Colors.red;
    }
  }

  Widget _buildFollowerBox() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      left: deviation != null 
          ? 150 + (deviation! * 300 / 100).clamp(-140.0, 140.0) 
          : 150,
      bottom: 100,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          border: Border.all(
            color: _getBoxColor(),
            width: 3,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: _getBoxColor().withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getBoxIcon(),
              color: _getBoxColor(),
              size: 40,
            ),
            if (confidenceScore > 0)
              Text(
                '${(confidenceScore * 100).round()}%',
                style: TextStyle(
                  color: _getBoxColor(),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getBoxColor() {
    if (!isLineVisible) return Colors.grey;
    if (isCentered && isStable) return Colors.green;
    if (isCentered) return Colors.yellow;
    if (isLeft || isRight) return Colors.red;
    return Colors.orange;
  }

  IconData _getBoxIcon() {
    if (!isLineVisible) return Icons.search;
    if (isCentered && isStable) return Icons.check_circle;
    if (isCentered) return Icons.check_circle_outline;
    if (isLeft) return Icons.arrow_back;
    if (isRight) return Icons.arrow_forward;
    return Icons.warning_outlined;
  }

  Widget _buildStatusIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusRow(),
          if (deviation != null)
            _buildDeviationIndicator(),
          _buildConfidenceIndicator(),
        ],
      ),
    );
  }

  Widget _buildStatusRow() {
    String message = _getStatusMessage();
    Color color = _getStatusColor();
    IconData icon = _getStatusIcon();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Text(
          message,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildDeviationIndicator() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        'Deviation: ${deviation!.toStringAsFixed(1)}%',
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildConfidenceIndicator() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isStable ? Icons.verified : Icons.running_with_errors,
            color: isStable ? Colors.green : Colors.orange,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            isStable ? 'Stable' : 'Stabilizing',
            style: TextStyle(
              color: isStable ? Colors.green : Colors.orange,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusMessage() {
    switch (linePosition) {
      case LinePosition.unknown:
        return "Searching for Line";
      case LinePosition.enteringLeft:
        return "Line Entering Left";
      case LinePosition.enteringRight:
        return "Line Entering Right";
      case LinePosition.leavingLeft:
        return "Line Leaving Left";
      case LinePosition.leavingRight:
        return "Line Leaving Right";
      default:
        return isStable ? "Line Locked" : "Line Detected";
    }
  }

  Color _getStatusColor() {
    if (!isLineVisible) return Colors.grey;
    if (isStable && isCentered) return Colors.green;
    if (isCentered) return Colors.yellow;
    return Colors.orange;
  }

  IconData _getStatusIcon() {
    if (!isLineVisible) return Icons.search;
    if (isStable && isCentered) return Icons.gps_fixed;
    if (isCentered) return Icons.gps_not_fixed;
    return Icons.warning;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildRegions(),
        if (deviation != null) _buildFollowerBox(),
        Positioned(
          top: 40,
          left: 0,
          right: 0,
          child: Center(
            child: _buildStatusIndicator(),
          ),
        ),
      ],
    );
  }
}