// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/line_detector.dart';
import '../widgets/status_indicator.dart';
import 'package:camera/camera.dart';
import '../widgets/camera_preview_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late LineDetector _lineDetector;

  @override
  void initState() {
    super.initState();
    _lineDetector = Provider.of<LineDetector>(context, listen: false);
  }

  void _startDetection() async {
    await _lineDetector.startDetection();
    setState(() {});
  }

  void _stopDetection() {
    _lineDetector.stopDetection();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cameraController = context.watch<LineDetector>().cameraController;
    final isLeft = context.watch<LineDetector>().isLeft;
    final isRight = context.watch<LineDetector>().isRight;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blind Runner App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.fitWidth,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.width * 
                      (cameraController?.value.aspectRatio ?? 1.0),
                    child: const CameraPreviewWidget(),
                  ),
                ),
              ),
            ),
          ),
          StatusIndicator(isLeft: isLeft, isRight: isRight, isCentered: true),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: cameraController == null || !cameraController.value.isStreamingImages
                  ? _startDetection
                  : _stopDetection,
              child: Text(cameraController == null || !cameraController.value.isStreamingImages
                  ? 'Start Detection'
                  : 'Stop Detection'),
            ),
          ),
        ],
      ),
    );
  }
}