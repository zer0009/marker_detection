// lib/services/line_detector.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import '../services/audio_feedback.dart';
import '../utils/image_processing.dart';
import '../models/settings_model.dart';
import 'dart:ui';
import 'dart:typed_data';
import 'dart:isolate';

class LineDetector with ChangeNotifier {
  CameraController? _cameraController;
  bool isLeft = false;
  bool isRight = false;
  bool isCentered = true;
  bool isLineLost = false;
  bool isStable = false;
  bool needsCorrection = false;
  double? currentDeviation;
  final AudioFeedback audioFeedback;
  final SettingsModel settings;
  bool _isProcessing = false;
  
  // Optimization constants
  static const processingInterval = Duration(milliseconds: 50); // 20 FPS
  DateTime? _lastProcessingTime;
  Uint8List? _debugImageBytes;

  // Line tracking
  static const int CONSECUTIVE_FRAMES_THRESHOLD = 3;
  int _consecutiveLineLostFrames = 0;
  int _consecutiveStableFrames = 0;

  LineDetector({required this.audioFeedback, required this.settings}) {
    // Initialize with starting message
    audioFeedback.playStarting();
  }

  CameraController? get cameraController => _cameraController;
  double? get deviation => currentDeviation;
  Uint8List? get debugImageBytes => _debugImageBytes;

  Future<void> initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        print("No camera available");
        return;
      }
      
      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        imageFormatGroup: ImageFormatGroup.yuv420,
        enableAudio: false,
      );
      
      await _cameraController!.initialize();
      await _cameraController!.startImageStream(_processImage);
      notifyListeners();
    } catch (e) {
      print("Camera initialization error: $e");
    }
  }

  void _processImage(CameraImage image) async {
    if (_isProcessing || 
        (_lastProcessingTime != null && 
         DateTime.now().difference(_lastProcessingTime!) < processingInterval)) {
      return;
    }

    _isProcessing = true;
    _lastProcessingTime = DateTime.now();

    try {
      final result = await ImageProcessing.processImageInIsolate({
        'image': image,
        'settings': settings,
      });

      if (result == null) {
        _handleLineLost();
        return;
      }

      // Update state with detection results
      currentDeviation = result['deviation'];
      isLeft = result['isLeft'];
      isRight = result['isRight'];
      isCentered = result['isCentered'];
      isLineLost = result['isLineLost'];
      isStable = result['isStable'];
      needsCorrection = result['needsCorrection'];
      _debugImageBytes = result['debugImage'];

      // Handle line tracking
      if (isLineLost) {
        _consecutiveLineLostFrames++;
        if (_consecutiveLineLostFrames >= CONSECUTIVE_FRAMES_THRESHOLD) {
          _handleLineLost();
        }
      } else {
        _consecutiveLineLostFrames = 0;
        _handleLineDetected();
      }

      // Provide audio feedback
      await audioFeedback.provideFeedback(
        isLeft: isLeft,
        isRight: isRight,
        isCentered: isCentered,
        isLineLost: isLineLost,
        isStable: isStable,
        needsCorrection: needsCorrection,
        deviation: currentDeviation,
      );

      notifyListeners();
    } catch (e) {
      print('Error in _processImage: $e');
    } finally {
      _isProcessing = false;
    }
  }

  void _handleLineLost() {
    isLineLost = true;
    isStable = false;
    needsCorrection = true;
    audioFeedback.playLineLost();
  }

  void _handleLineDetected() {
    if (isStable) {
      _consecutiveStableFrames++;
      if (_consecutiveStableFrames >= CONSECUTIVE_FRAMES_THRESHOLD && isCentered) {
        audioFeedback.playCentered();
      }
    } else {
      _consecutiveStableFrames = 0;
    }
  }

  Future<void> startDetection() async {
    _resetState();
    await initializeCamera();
    audioFeedback.playStarting();
  }

  void stopDetection() {
    audioFeedback.playStopping();
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _cameraController = null;
    _resetState();
    notifyListeners();
  }

  void _resetState() {
    isLeft = false;
    isRight = false;
    isCentered = false;
    isLineLost = false;
    isStable = false;
    needsCorrection = false;
    currentDeviation = null;
    _consecutiveLineLostFrames = 0;
    _consecutiveStableFrames = 0;
  }

  void pauseDetection() {
    _cameraController?.stopImageStream();
  }

  void resumeDetection() {
    _cameraController?.startImageStream(_processImage);
  }

  @override
  void dispose() {
    stopDetection();
    audioFeedback.dispose();
    super.dispose();
  }
}