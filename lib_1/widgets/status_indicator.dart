// lib/widgets/status_indicator.dart
import 'package:flutter/material.dart';

class StatusIndicator extends StatelessWidget {
  final bool isLeft;
  final bool isRight;
  final bool isCentered;
  final double? deviation;

  const StatusIndicator({
    Key? key,
    required this.isLeft,
    required this.isRight,
    required this.isCentered,
    this.deviation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _getStatusColor().withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
        border: Border.all(
          color: _getStatusColor().withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatusIcon(),
              const SizedBox(width: 16),
              _buildStatusText(),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    if (isLeft || isRight) return Colors.red;
    if (isCentered) return Colors.green;
    return Colors.yellow;
  }

  Widget _buildStatusIcon() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(
        _getStatusIcon(),
        color: _getStatusColor(),
        size: 32,
      ),
    );
  }

  IconData _getStatusIcon() {
    if (isLeft) return Icons.arrow_back_rounded;
    if (isRight) return Icons.arrow_forward_rounded;
    if (isCentered) return Icons.check_circle_rounded;
    return Icons.warning_rounded;
  }

  Widget _buildStatusText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getStatusMessage(),
          style: TextStyle(
            color: _getStatusColor(),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          _getStatusDescription(),
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  String _getStatusMessage() {
    if (isLeft) return 'Move Right';
    if (isRight) return 'Move Left';
    if (isCentered) return 'On Track';
    return 'Line Lost';
  }

  String _getStatusDescription() {
    if (isLeft) return 'Adjust position rightward';
    if (isRight) return 'Adjust position leftward';
    if (isCentered) return 'Maintaining correct position';
    return 'Please stop and relocate the line';
  }
}