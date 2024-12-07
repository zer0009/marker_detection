// lib_2/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/line_detector.dart';
import '../widgets/status_indicator.dart';
import '../widgets/camera_preview_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late LineDetector _lineDetector;
  DateTime? _lastBackPress;
  bool _isProcessingFrame = false;
  bool _wasDetecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lineDetector = Provider.of<LineDetector>(context, listen: false);
    // Auto-start detection when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startDetection();
    });
  }

  @override
  void dispose() {
    _stopDetection();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cameraController = _lineDetector.cameraController;
    
    switch (state) {
      case AppLifecycleState.paused:
        // Store the current detection state
        _wasDetecting = cameraController?.value.isStreamingImages ?? false;
        if (_wasDetecting) {
          _lineDetector.pauseDetection();
        }
        break;
        
      case AppLifecycleState.resumed:
        // Restore the previous detection state
        if (_wasDetecting) {
          _resumeDetection();
        }
        break;
        
      case AppLifecycleState.inactive:
        // Don't stop detection on inactive state (keeps running during navigation)
        break;
        
      case AppLifecycleState.detached:
        _stopDetection();
        break;
      case AppLifecycleState.hidden:
        // TODO: Handle this case.
    }
  }

  Future<bool> _onWillPop() async {
    if (_lastBackPress == null || 
        DateTime.now().difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = DateTime.now();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _startDetection() async {
    try {
      await _lineDetector.startDetection();
      _wasDetecting = true;
      if (mounted) setState(() {});
    } catch (e) {
      print('Error starting detection: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start camera')),
        );
      }
    }
  }

  Future<void> _resumeDetection() async {
    try {
      _lineDetector.resumeDetection();
      if (mounted) setState(() {});
    } catch (e) {
      print('Error resuming detection: $e');
      // Try to restart detection if resuming fails
      await _startDetection();
    }
  }

  void _stopDetection() {
    _lineDetector.stopDetection();
    _wasDetecting = false;
    if (mounted) setState(() {});
  }

  void _navigateToSettings() async {
    // Don't stop detection, just pause if needed
    final wasActive = _lineDetector.cameraController?.value.isStreamingImages ?? false;
    if (wasActive) {
      _lineDetector.pauseDetection();
    }

    // Navigate to settings
    await Navigator.pushNamed(context, '/settings');

    // Resume detection if it was active before
    if (wasActive && mounted) {
      _resumeDetection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Blind Runner App'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _navigateToSettings,
              tooltip: 'Settings',
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
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
                          (context.select((LineDetector d) => 
                            d.cameraController?.value.aspectRatio ?? 1.0)),
                        child: const CameraPreviewWidget(),
                      ),
                    ),
                  ),
                ),
              ),
              Consumer<LineDetector>(
                builder: (context, detector, _) => StatusIndicator(
                  isLeft: detector.isLeft,
                  isRight: detector.isRight,
                  isCentered: detector.isCentered,
                  deviation: detector.deviation,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Consumer<LineDetector>(
                  builder: (context, detector, _) => ElevatedButton(
                    onPressed: detector.cameraController?.value.isStreamingImages ?? false
                        ? _stopDetection
                        : _startDetection,
                    child: Text(
                      detector.cameraController?.value.isStreamingImages ?? false
                          ? 'Stop Detection'
                          : 'Start Detection'
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}