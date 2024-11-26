// lib/widgets/status_indicator.dart
import 'package:flutter/material.dart';

class StatusIndicator extends StatelessWidget {
  final bool isLeft;
  final bool isRight;

  const StatusIndicator({Key? key, required this.isLeft, required this.isRight}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String statusText = 'Centered';
    Color statusColor = Colors.green;

    if (isLeft) {
      statusText = 'Veering Left';
      statusColor = Colors.red;
    } else if (isRight) {
      statusText = 'Veering Right';
      statusColor = Colors.blue;
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            statusText,
            style: TextStyle(fontSize: 18, color: statusColor, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 10),
          Icon(
            isLeft
                ? Icons.arrow_left
                : isRight
                ? Icons.arrow_right
                : Icons.check,
            color: statusColor,
          ),
        ],
      ),
    );
  }
}