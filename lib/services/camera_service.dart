import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraService {
  final List<CameraDescription> cameras;
  final Function(CameraImage) onFrame;
  final Function(String) onError;
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isStreaming = false;

  CameraService({
    required this.cameras,
    required this.onFrame,
    required this.onError,
  });

  bool get isInitialized => _isInitialized;
  CameraController? get controller => _controller;
  bool get isStreaming => _isStreaming;

  Future<void> initialize() async {
    var cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      onError('Camera permission is required');
      return;
    }

    if (cameras.isEmpty) {
      onError('No cameras available');
      return;
    }

    // Stop any existing controller
    await _controller?.dispose();
    _isInitialized = false;
    _isStreaming = false;

    _controller = CameraController(
      cameras[0],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _controller?.initialize();
      _isInitialized = true;
    } catch (e) {
      onError('Camera initialization error: $e');
      _isInitialized = false;
    }
  }

  Future<void> startImageStream() async {
    if (!_isInitialized || _isStreaming) {
      return;
    }

    try {
      await _controller?.startImageStream(onFrame);
      _isStreaming = true;
    } catch (e) {
      onError('Failed to start camera stream: $e');
      _isStreaming = false;
    }
  }

  Future<void> stopImageStream() async {
    if (!_isStreaming) {
      return;
    }

    try {
      await _controller?.stopImageStream();
      _isStreaming = false;
    } catch (e) {
      onError('Failed to stop camera stream: $e');
    }
  }

  Future<void> dispose() async {
    try {
      await stopImageStream();
      await _controller?.dispose();
      _isInitialized = false;
      _isStreaming = false;
    } catch (e) {
      onError('Error disposing camera: $e');
    }
  }
}