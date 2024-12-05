import 'package:flutter/material.dart';

import '../models/line_position.dart';

class LineDetectionOverlay extends StatelessWidget {
  final double? deviation;
  final bool isLineLost;
  final bool isStable;
  final Size imageSize;
  final double lineWidth;
  final double? movementSpeed;
  final bool needsCorrection;
  final double confidenceScore;
  final LinePosition linePosition;

  const LineDetectionOverlay({
    Key? key,
    required this.deviation,
    required this.isLineLost,
    required this.imageSize,
    this.isStable = false,
    this.movementSpeed = 0,
    this.needsCorrection = false,
    this.lineWidth = 4.0,
    this.confidenceScore = 0.0,
    this.linePosition = LinePosition.unknown,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (deviation == null) return Container();

    final center = imageSize.width / 2;
    final linePosition = center + (deviation! * center / 100).clamp(-center * 0.8, center * 0.8);

    return Stack(
      children: [
        CustomPaint(
          size: imageSize,
          painter: LineHighlightPainter(
            linePosition: linePosition,
            lineWidth: lineWidth,
            isLost: isLineLost,
            isStable: isStable,
            needsCorrection: needsCorrection,
            movementSpeed: movementSpeed ?? 0,
            imageSize: imageSize,
            confidenceScore: confidenceScore,
            linePositionState: this.linePosition,
          ),
        ),
        if (!isLineLost) _buildGuidanceArrows(context, linePosition),
        _buildDetectionZones(context),
        _buildStatusOverlay(context),
      ],
    );
  }

  Widget _buildGuidanceArrows(BuildContext context, double linePosition) {
    final deviationAbs = deviation!.abs();
    final double arrowSize = _calculateArrowSize(deviationAbs);
    final Color arrowColor = _calculateArrowColor(deviationAbs);

    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (deviation! < -5)
            Icon(
              Icons.arrow_left,
              color: arrowColor,
              size: arrowSize,
            ),
          if (deviation! > 5)
            Icon(
              Icons.arrow_right,
              color: arrowColor,
              size: arrowSize,
            ),
        ],
      ),
    );
  }

  Widget _buildDetectionZones(BuildContext context) {
    return CustomPaint(
      size: imageSize,
      painter: DetectionZonesPainter(
        isActive: !isLineLost,
        isStable: isStable,
      ),
    );
  }

  double _calculateArrowSize(double deviation) {
    if (deviation > 40) return 56;
    if (deviation > 25) return 48;
    if (deviation > 10) return 40;
    return 32;
  }

  Color _calculateArrowColor(double deviation) {
    if (deviation > 40) return Colors.red;
    if (deviation > 25) return Colors.orange;
    if (deviation > 10) return Colors.yellow;
    return Colors.green;
  }

  Widget _buildStatusOverlay(BuildContext context) {
    return Positioned(
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
            _buildStatusRow('Confidence', confidenceScore),
            _buildStatusRow('Stability', isStable ? 1.0 : 0.5),
            _buildStatusRow('Speed', movementSpeed ?? 0),
            Text(
              'Status: ${_getStatusText()}',
              style: TextStyle(
                color: _getStatusColor(),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, double value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.white70),
        ),
        Container(
          width: 50,
          height: 10,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white24),
            borderRadius: BorderRadius.circular(5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(_getValueColor(value)),
            ),
          ),
        ),
      ],
    );
  }

  Color _getValueColor(double value) {
    if (value > 0.8) return Colors.green;
    if (value > 0.5) return Colors.yellow;
    return Colors.orange;
  }

  String _getStatusText() {
    switch (linePosition) {
      case LinePosition.enteringLeft:
        return 'Entering Left';
      case LinePosition.enteringRight:
        return 'Entering Right';
      case LinePosition.leavingLeft:
        return 'Leaving Left';
      case LinePosition.leavingRight:
        return 'Leaving Right';
      case LinePosition.visible:
        return isStable ? 'Stable' : 'Tracking';
      case LinePosition.unknown:
        return 'Searching';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor() {
    if (isLineLost) return Colors.red;
    if (isStable) return Colors.green;
    if (needsCorrection) return Colors.orange;
    return Colors.yellow;
  }
}

class LineHighlightPainter extends CustomPainter {
  final double linePosition;
  final double lineWidth;
  final bool isLost;
  final bool isStable;
  final bool needsCorrection;
  final double movementSpeed;
  final Size imageSize;
  final double confidenceScore;
  final LinePosition linePositionState;

  LineHighlightPainter({
    required this.linePosition,
    required this.lineWidth,
    required this.isLost,
    required this.isStable,
    required this.needsCorrection,
    required this.movementSpeed,
    required this.imageSize,
    required this.confidenceScore,
    required this.linePositionState,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawTargetZone(canvas, size);
    _drawLineIndicator(canvas, size);
    if (!isLost) {
      _drawStabilityIndicator(canvas, size);
      _drawConfidenceIndicator(canvas, size);
      _drawLinePositionIndicator(canvas, size);
    }
    _drawSpeedIndicator(canvas, size);
  }

  void _drawTargetZone(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final zoneWidth = size.width * 0.15;
    
    final centerLinePaint = Paint()
      ..color = Colors.green.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, size.height),
      centerLinePaint,
    );

    final zonePaint = Paint()
      ..color = Colors.green.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTRB(
        centerX - zoneWidth/2,
        0,
        centerX + zoneWidth/2,
        size.height,
      ),
      zonePaint,
    );

    final boundaryPaint = Paint()
      ..color = Colors.green.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(centerX - zoneWidth/2, 0),
      Offset(centerX - zoneWidth/2, size.height),
      boundaryPaint,
    );

    canvas.drawLine(
      Offset(centerX + zoneWidth/2, 0),
      Offset(centerX + zoneWidth/2, size.height),
      boundaryPaint,
    );
  }

  void _drawLineIndicator(Canvas canvas, Size size) {
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _getLineColor().withOpacity(0.3),
          _getLineColor(),
        ],
      ).createShader(Rect.fromLTWH(0, 0, lineWidth, size.height));

    canvas.drawRect(
      Rect.fromLTWH(
        linePosition - lineWidth/2,
        0,
        lineWidth,
        size.height,
      ),
      gradientPaint,
    );

    final trianglePath = Path()
      ..moveTo(linePosition - 25, size.height)
      ..lineTo(linePosition + 25, size.height)
      ..lineTo(linePosition, size.height - 50)
      ..close();

    canvas.drawPath(
      trianglePath,
      Paint()
        ..color = _getLineColor().withOpacity(0.4)
        ..style = PaintingStyle.fill,
    );
  }

  void _drawConfidenceIndicator(Canvas canvas, Size size) {
    final confidence = isStable ? 1.0 : 0.5;
    final rect = Rect.fromLTWH(
      size.width - 30,
      size.height - 120,
      10,
      100 * confidence,
    );

    canvas.drawRect(
      rect,
      Paint()
        ..color = _getConfidenceColor(confidence)
        ..style = PaintingStyle.fill,
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence > 0.8) return Colors.green;
    if (confidence > 0.5) return Colors.yellow;
    return Colors.orange;
  }

  void _drawStabilityIndicator(Canvas canvas, Size size) {
    final stabilityPaint = Paint()
      ..color = isStable ? Colors.green : Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(
      Offset(linePosition, size.height - 60),
      10,
      stabilityPaint,
    );
  }

  void _drawSpeedIndicator(Canvas canvas, Size size) {
    final speedHeight = (movementSpeed * 50).clamp(0.0, 100.0);
    final speedPaint = Paint()
      ..color = _getSpeedColor()
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(20, size.height - speedHeight - 20, 10, speedHeight),
      speedPaint,
    );
  }

  Color _getLineColor() {
    if (isLost) return Colors.red;
    if (needsCorrection) return Colors.orange;
    if (isStable) return Colors.green;
    return Colors.yellow;
  }

  Color _getSpeedColor() {
    if (movementSpeed > 0.8) return Colors.red;
    if (movementSpeed > 0.5) return Colors.orange;
    return Colors.green;
  }

  void _drawLinePositionIndicator(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _getLinePositionColor()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final double arrowSize = 20;
    final double arrowY = size.height - 30;

    switch (linePositionState) {
      case LinePosition.enteringLeft:
      case LinePosition.enteringRight:
        _drawArrow(canvas, paint, size, arrowSize, arrowY, isEntering: true);
        break;
      case LinePosition.leavingLeft:
      case LinePosition.leavingRight:
        _drawArrow(canvas, paint, size, arrowSize, arrowY, isEntering: false);
        break;
      default:
        break;
    }
  }

  void _drawArrow(Canvas canvas, Paint paint, Size size, double arrowSize, double y, {required bool isEntering}) {
    final path = Path();
    if (isEntering) {
      path.moveTo(linePosition - arrowSize, y - arrowSize);
      path.lineTo(linePosition, y);
      path.lineTo(linePosition + arrowSize, y - arrowSize);
    } else {
      path.moveTo(linePosition - arrowSize, y);
      path.lineTo(linePosition, y + arrowSize);
      path.lineTo(linePosition + arrowSize, y);
    }
    canvas.drawPath(path, paint);
  }

  Color _getLinePositionColor() {
    switch (linePositionState) {
      case LinePosition.enteringLeft:
      case LinePosition.enteringRight:
        return Colors.blue;
      case LinePosition.leavingLeft:
      case LinePosition.leavingRight:
        return Colors.orange;
      case LinePosition.visible:
        return isStable ? Colors.green : Colors.yellow;
      default:
        return Colors.red;
    }
  }

  @override
  bool shouldRepaint(LineHighlightPainter oldDelegate) {
    return linePosition != oldDelegate.linePosition ||
           isLost != oldDelegate.isLost ||
           isStable != oldDelegate.isStable ||
           needsCorrection != oldDelegate.needsCorrection ||
           movementSpeed != oldDelegate.movementSpeed ||
           confidenceScore != oldDelegate.confidenceScore ||
           linePositionState != oldDelegate.linePositionState;
  }
}

class DetectionZonesPainter extends CustomPainter {
  final bool isActive;
  final bool isStable;

  DetectionZonesPainter({
    required this.isActive,
    required this.isStable,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) return;

    final paint = Paint()
      ..color = isStable ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 2/3, size.width, size.height/3),
      paint,
    );
  }

  @override
  bool shouldRepaint(DetectionZonesPainter oldDelegate) {
    return isActive != oldDelegate.isActive || isStable != oldDelegate.isStable;
  }
} 