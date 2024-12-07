import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import '../services/camera_service.dart';
import '../services/line_detection_service.dart';
import '../models/line_detection_result.dart';
import '../widgets/detection_history_dialog.dart';
import '../widgets/detection_indicator.dart';
import '../services/audio_feedback_service.dart';
import '../widgets/line_overlay.dart';

class LineDetectionScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const LineDetectionScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  _LineDetectionScreenState createState() => _LineDetectionScreenState();
}

class _LineDetectionScreenState extends State<LineDetectionScreen>
    with WidgetsBindingObserver {
  late final CameraService _cameraService;
  late final LineDetectionService _lineDetectionService;
  late final AudioFeedbackService _audioFeedbackService;
  final List<LineDetectionResult> _detectionHistory = [];
  LineDetectionResult _detectionResult = LineDetectionResult.lineNotFound;
  String _errorMessage = '';
  double _linePosition = 0.5;
  bool _isDetecting = false;
  bool _isProcessing = false;
  bool _isStreamActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cameraService = CameraService(
      cameras: widget.cameras,
      onFrame: _processFrame,
      onError: (error) => setState(() => _errorMessage = error),
    );
    _lineDetectionService = LineDetectionService();
    _audioFeedbackService = AudioFeedbackService();
    _initializeCamera();
    _preventScreenLock();
  }

  Future<void> _preventScreenLock() async {
    try {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [SystemUiOverlay.top],
      );
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [],
      );
    } catch (e) {
      print('Error preventing screen lock: $e');
    }
  }

  Future<void> _initializeCamera() async {
    await _cameraService.initialize();
    if (mounted) {
      setState(() {});
    }
  }

  void _processFrame(CameraImage image) {
    if (_isProcessing || !_isDetecting) return;
    _isProcessing = true;

    try {
      final result = _lineDetectionService.processFrame(image);
      final position = _lineDetectionService.getLinePosition(image);
      
      if (mounted && _isDetecting) {
        setState(() {
          _detectionResult = result;
          _linePosition = position;
          _updateDetectionHistory(result);
        });
        
        _audioFeedbackService.provideFeedback(result, position);
      }
    } catch (e) {
      print('Frame processing error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  void _updateDetectionHistory(LineDetectionResult result) {
    _detectionHistory.add(result);
    if (_detectionHistory.length > 5) {
      _detectionHistory.removeAt(0);
    }
  }

  Future<void> _startDetection() async {
    if (!mounted || _isDetecting) return;

    try {
      // Start the camera stream using the new method
      await _cameraService.startImageStream();
      
      setState(() {
        _isDetecting = true;
        _detectionResult = LineDetectionResult.lineNotFound;
        _detectionHistory.clear();
      });

      _preventScreenLock();
    } catch (e) {
      print('Error starting detection: $e');
      setState(() {
        _errorMessage = 'Failed to start detection';
        _isDetecting = false;
      });
    }
  }

  Future<void> _stopDetection() async {
    if (!mounted) return;

    try {
      await _cameraService.stopImageStream();
      await _audioFeedbackService.stop();
      
      setState(() {
        _isDetecting = false;
        _detectionResult = LineDetectionResult.lineNotFound;
      });
    } catch (e) {
      print('Error stopping detection: $e');
    }
  }

  void _toggleDetection() async {
    if (_isDetecting) {
      await _stopDetection();
    } else {
      await _startDetection();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.inactive) {
      // Stop stream when app is inactive
      if (_cameraService.isStreaming) {
        await _stopDetection();
      }
    } else if (state == AppLifecycleState.resumed) {
      // Reinitialize camera when app is resumed
      await _initializeCamera();
      _preventScreenLock();
      if (_isDetecting) {
        // Delay the restart slightly to ensure proper initialization
        await Future.delayed(const Duration(milliseconds: 500));
        await _startDetection();
      }
    }
  }

  @override
  void dispose() {
    _stopDetection();
    WidgetsBinding.instance.removeObserver(this);
    _cameraService.dispose();
    _audioFeedbackService.dispose();
    // Reset system UI
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit Confirmation'),
            content: const Text('Are you sure you want to exit? The line detection will stop.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Exit'),
              ),
            ],
          ),
        );
        return shouldExit ?? false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Line Detection'),
          automaticallyImplyLeading: false,
        ),
        body: Column(
          children: [
            Expanded(
              child: _errorMessage.isNotEmpty
                  ? Center(
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                  : Stack(
                      children: [
                        if (_cameraService.isInitialized)
                          CameraPreview(_cameraService.controller!)
                        else
                          const Center(child: CircularProgressIndicator()),
                        if (_cameraService.isInitialized)
                          LineOverlay(
                            result: _detectionResult,
                            linePosition: _linePosition,
                          ),
                      ],
                    ),
            ),
            DetectionIndicator(result: _detectionResult),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _cameraService.isInitialized ? _toggleDetection : null,
                      icon: Icon(_isDetecting ? Icons.stop : Icons.play_arrow),
                      label: Text(_isDetecting ? 'Stop' : 'Start'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isDetecting ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        disabledBackgroundColor: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}