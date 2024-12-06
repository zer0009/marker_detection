import 'package:flutter/material.dart';
import '../models/line_detection_result.dart';

class DetectionHistoryDialog extends StatelessWidget {
  final List<LineDetectionResult> history;

  const DetectionHistoryDialog({Key? key, required this.history}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Detection History'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: history.length,
          itemBuilder: (context, index) {
            final result = history[index];
            return Text(
              result.toString().split('.').last,
              style: const TextStyle(fontSize: 16),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}