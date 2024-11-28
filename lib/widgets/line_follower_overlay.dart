import 'package:flutter/material.dart';

class LineFollowerOverlay extends StatelessWidget {
  final double? deviation;
  final bool isLeft;
  final bool isRight;
  final bool isCentered;

  const LineFollowerOverlay({
    Key? key,
    this.deviation,
    required this.isLeft,
    required this.isRight,
    required this.isCentered,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Screen regions
        _buildRegions(),
        // Line follower box
        if (deviation != null) _buildFollowerBox(),
      ],
    );
  }

  Widget _buildRegions() {
    return Row(
      children: [
        // Left region
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isLeft ? Colors.red.withOpacity(0.5) : Colors.white24,
                width: 2,
              ),
              color: isLeft 
                  ? Colors.red.withOpacity(0.1) 
                  : Colors.transparent,
            ),
            child: Center(
              child: RotatedBox(
                quarterTurns: 3,
                child: Text(
                  'LEFT',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
        // Center region
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isCentered ? Colors.green.withOpacity(0.5) : Colors.white24,
                width: 2,
              ),
              color: isCentered 
                  ? Colors.green.withOpacity(0.1) 
                  : Colors.transparent,
            ),
            child: Center(
              child: RotatedBox(
                quarterTurns: 3,
                child: Text(
                  'CENTER',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
        // Right region
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isRight ? Colors.red.withOpacity(0.5) : Colors.white24,
                width: 2,
              ),
              color: isRight 
                  ? Colors.red.withOpacity(0.1) 
                  : Colors.transparent,
            ),
            child: Center(
              child: RotatedBox(
                quarterTurns: 3,
                child: Text(
                  'RIGHT',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFollowerBox() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 100), // Fast but smooth animation
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
        child: Center(
          child: Icon(
            _getBoxIcon(),
            color: _getBoxColor(),
            size: 40,
          ),
        ),
      ),
    );
  }

  Color _getBoxColor() {
    if (isCentered) return Colors.green;
    if (isLeft || isRight) return Colors.red;
    return Colors.yellow;
  }

  IconData _getBoxIcon() {
    if (isCentered) return Icons.check_circle_outline;
    if (isLeft) return Icons.arrow_back;
    if (isRight) return Icons.arrow_forward;
    return Icons.warning_outlined;
  }
}