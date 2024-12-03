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
import 'dart:math' as math;

// Define the enum outside the class
enum LinePosition {
  none,
  enteringLeft,
  enteringRight,
  visible,
  leavingLeft,
  leavingRight
}

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
  static const processingInterval = Duration(milliseconds: 30); // Increased to ~33 FPS
  DateTime? _lastProcessingTime;
  Uint8List? _debugImageBytes;

  // Line tracking
  static const int CONSECUTIVE_FRAMES_THRESHOLD = 3;
  int _consecutiveLineLostFrames = 0;
  int _consecutiveStableFrames = 0;

  // Add new constants for improved detection
  static const int STABLE_FRAMES_THRESHOLD = 3; // Reduced from 4
  static const int LINE_LOST_THRESHOLD = 1; // Reduced from 2

  // Add movement tracking
  List<double> _recentDeviations = [];
  static const int DEVIATION_HISTORY_SIZE = 5;

  // Add vibration thresholds
  static const double VIBRATION_THRESHOLD = 5.0;
  static const double STRONG_VIBRATION_THRESHOLD = 15.0;

  // Add new states for line position tracking
  bool isLineVisible = false;
  LinePosition linePosition = LinePosition.none;
  
  // Add position tracking
  double? _lastDeviation;
  DateTime? _lastLineSeenTime;
  static const lineTimeout = Duration(milliseconds: 500);

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
    if (_isProcessing || (_lastProcessingTime != null && 
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

      // Track line visibility changes
      bool wasVisible = isLineVisible;
      isLineVisible = result != null && !result['isLineLost'];
      
      if (isLineVisible) {
        _lastLineSeenTime = DateTime.now();
        _updateLinePosition(result!['deviation']);
      } else if (wasVisible) {
        // Line just disappeared - determine exit direction
        if (_lastDeviation != null) {
          linePosition = _lastDeviation! < 0 ? 
              LinePosition.leavingLeft : 
              LinePosition.leavingRight;
          audioFeedback.playMessage(
            "Line leaving to ${linePosition == LinePosition.leavingLeft ? 'left' : 'right'}"
          );
        }
      } else if (_lastLineSeenTime != null && 
          DateTime.now().difference(_lastLineSeenTime!) > lineTimeout) {
        // Line completely lost
        linePosition = LinePosition.none;
        audioFeedback.playLineLost();
      }

      // Update other states
      if (result != null) {
        currentDeviation = result['deviation'];
        _lastDeviation = currentDeviation;
        isLeft = result['isLeft'];
        isRight = result['isRight'];
        isCentered = result['isCentered'];
        isLineLost = result['isLineLost'];
        this.isStable = _checkStability();
        needsCorrection = result['needsCorrection'];
        _debugImageBytes = result['debugImage'];
      }

      notifyListeners();
    } catch (e) {
      print('Error in _processImage: $e');
    } finally {
      _isProcessing = false;
    }
  }

  void _updateLinePosition(double deviation) {
    if (_lastDeviation == null) {
      // First detection - determine entry direction
      linePosition = deviation < 0 ? 
          LinePosition.enteringLeft : 
          LinePosition.enteringRight;
      audioFeedback.playMessage(
        "Line detected from ${linePosition == LinePosition.enteringLeft ? 'left' : 'right'}"
      );
    } else {
      linePosition = LinePosition.visible;
    }
  }

  bool _checkStability() {
    if (_recentDeviations.length < 3) return false;

    double sum = 0;
    double maxDiff = 0;

    for (int i = 1; i < _recentDeviations.length; i++) {
      double diff = (_recentDeviations[i] - _recentDeviations[i-1]).abs();
      maxDiff = math.max(maxDiff, diff);
      sum += diff;
    }

    double avgDiff = sum / (_recentDeviations.length - 1);
    // More strict stability requirements
    return avgDiff < 3.0 && maxDiff < 7.0; // Reduced from 5.0 and 10.0
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
      if (_consecutiveStableFrames >= CONSECUTIVE_FRAMES_THRESHOLD) {
        if (isCentered) {
          // Provide positive feedback for staying centered
          audioFeedback.playMessage("Good", isPositive: true);
        }
      }
    } else {
      _consecutiveStableFrames = 0;
      
      // Add immediate feedback for sudden movements
      if (currentDeviation != null && currentDeviation!.abs() > STRONG_VIBRATION_THRESHOLD) {
        audioFeedback.playMessage(
          "Too ${currentDeviation! < 0 ? 'right' : 'left'}",
          isUrgent: true
        );
      }
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

  void updateDetection(CameraImage image, SettingsModel settings) async {
    final result = await ImageProcessing.processImageInIsolate({
      'image': image,
      'settings': settings,
    });

    if (result != null) {
      currentDeviation = result['deviation'];
      isLeft = result['isLeft'];
      isRight = result['isRight'];
      isCentered = result['isCentered'];
      isLineLost = result['isLineLost'];
      _debugImageBytes = result['debugImage'];
      notifyListeners();
    } else {
      // Handle null result
      isLineLost = true;
      notifyListeners();
    }
  }
}