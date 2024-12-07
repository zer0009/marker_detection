import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import '../services/audio_feedback.dart';
import '../utils/image_processing.dart';
import '../models/settings_model.dart';
import 'dart:math' as math;
import '../models/line_position.dart';

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
  static const processingInterval = Duration(milliseconds: 50); // Reduced from 30ms to 50ms for better performance
  DateTime? _lastProcessingTime;
  Uint8List? _debugImageBytes;

  // Line tracking
  static const int CONSECUTIVE_FRAMES_THRESHOLD = 3;
  int _consecutiveLineLostFrames = 0;
  int _consecutiveStableFrames = 0;

  // Add new constants for improved detection
  static const int STABLE_FRAMES_THRESHOLD = 3; // Reduced from 4
  static const int LINE_LOST_THRESHOLD = 1; // Reduced from 2
  static const double MAX_DEVIATION_CHANGE = 10.0; // Maximum allowed deviation change between frames
  static const int MIN_STABLE_FRAMES = 3; // Minimum number of stable frames to confirm line
  static const double STABILITY_THRESHOLD = 5.0; // Maximum deviation variation for stability
  static const int MAX_LOST_FRAMES = 5; // Maximum number of frames before declaring line lost

  // Add movement tracking
  List<double> _recentDeviations = [];
  static const int DEVIATION_HISTORY_SIZE = 5;

  // Add vibration thresholds
  static const double VIBRATION_THRESHOLD = 5.0;
  static const double STRONG_VIBRATION_THRESHOLD = 15.0;

  // Add new states for line position tracking
  bool isLineVisible = false;
  LinePosition linePosition = LinePosition.unknown;
  
  // Add position tracking
  double? _lastDeviation;
  DateTime? _lastLineSeenTime;
  static const lineTimeout = Duration(milliseconds: 500);

  // Add tracking variables
  List<double> _deviationHistory = [];
  int _stableFrameCount = 0;
  int _lostFrameCount = 0;
  DateTime? _lastValidDetection;

  // Add new property for confidence tracking
  double _confidence = 0.0;
  double get confidence => _confidence;

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
        ResolutionPreset.low,
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

  void _processImage(CameraImage image) {
    if (_isProcessing || (_lastProcessingTime != null && 
        DateTime.now().difference(_lastProcessingTime!) < processingInterval)) {
      return;
    }

    _isProcessing = true;
    _lastProcessingTime = DateTime.now();

    try {
      final convertedImage = ImageProcessing.convertCameraImage(image);
      if (convertedImage == null) {
        _handleInvalidFrame();
        return;
      }

      final result = ImageProcessing.detectLine(convertedImage, settings);
      _processDetectionResult(result);

      notifyListeners();
    } catch (e) {
      print('Error in _processImage: $e');
      _handleInvalidFrame();
    } finally {
      _isProcessing = false;
    }
  }

  void _processDetectionResult(Map<String, dynamic> result) {
    double? newDeviation = result['deviation'];
    double confidence = result['confidence'] ?? 0.0;
    
    if (newDeviation != null && confidence > 0.3) {  // Only process results with decent confidence
      if (_isValidDeviationChange(newDeviation)) {
        _updateLineState(result, newDeviation);
        _lastValidDetection = DateTime.now();
        _lostFrameCount = 0;
        _confidence = confidence;
      } else {
        _handleSuspiciousDetection();
      }
    } else {
      _handleInvalidFrame();
    }

    // Update UI state
    isLeft = result['isLeft'] ?? false;
    isRight = result['isRight'] ?? false;
    isCentered = result['isCentered'] ?? false;
    isLineLost = result['isLineLost'] ?? true;
    isStable = _checkStability() && confidence > 0.5;  // Require good confidence for stability
    needsCorrection = result['needsCorrection'] ?? false;
    linePosition = result['linePosition'] ?? LinePosition.unknown;
    _debugImageBytes = result['debugImage'];

    // Update line visibility state
    isLineVisible = linePosition == LinePosition.visible;

    // Handle audio feedback with enhanced position information
    _handleEnhancedAudioFeedback();
  }

  bool _isValidDeviationChange(double newDeviation) {
    if (_deviationHistory.isEmpty) return true;
    
    double lastDeviation = _deviationHistory.last;
    double change = (newDeviation - lastDeviation).abs();
    
    // More sophisticated change validation
    if (change <= MAX_DEVIATION_CHANGE) {
      return true;
    } else if (_confidence > 0.7 && change <= MAX_DEVIATION_CHANGE * 1.5) {
      // Allow slightly larger changes if confidence is high
      return true;
    }
    
    return false;
  }

  void _updateLineState(Map<String, dynamic> result, double newDeviation) {
    // Update deviation history
    _deviationHistory.add(newDeviation);
    if (_deviationHistory.length > DEVIATION_HISTORY_SIZE) {
      _deviationHistory.removeAt(0);
    }

    currentDeviation = newDeviation;

    // Update stability tracking with confidence consideration
    if (_isStableDeviation() && _confidence > 0.5) {
      _stableFrameCount++;
      if (_stableFrameCount >= MIN_STABLE_FRAMES) {
        isStable = true;
      }
    } else {
      _stableFrameCount = 0;
      isStable = false;
    }

    // Update line position tracking
    _lastDeviation = newDeviation;
    _lastLineSeenTime = DateTime.now();
  }

  bool _isStableDeviation() {
    if (_deviationHistory.length < 3) return false;

    double sum = 0;
    for (int i = 1; i < _deviationHistory.length; i++) {
      sum += (_deviationHistory[i] - _deviationHistory[i-1]).abs();
    }
    double avgChange = sum / (_deviationHistory.length - 1);
    
    return avgChange <= STABILITY_THRESHOLD;
  }

  void _handleInvalidFrame() {
    _lostFrameCount++;
    if (_lostFrameCount >= MAX_LOST_FRAMES) {
      isLineLost = true;
      isStable = false;
      _stableFrameCount = 0;
      _deviationHistory.clear();
    }
  }

  void _handleSuspiciousDetection() {
    // Don't immediately update state for suspicious detections
    _lostFrameCount++;
    if (_lostFrameCount < MAX_LOST_FRAMES && _lastValidDetection != null) {
      // Use last valid detection if within timeout
      if (DateTime.now().difference(_lastValidDetection!) < lineTimeout) {
        return;
      }
    }
    _handleInvalidFrame();
  }

  void _handleEnhancedAudioFeedback() {
    if (isLineLost) {
      return;
    }

    // Enhanced position-based feedback
    switch (linePosition) {
      case LinePosition.enteringLeft:
        audioFeedback.playMessage("Line entering from left");
        break;
      case LinePosition.enteringRight:
        audioFeedback.playMessage("Line entering from right");
        break;
      case LinePosition.leavingLeft:
        audioFeedback.playMessage("Line moving left", isUrgent: true);
        break;
      case LinePosition.leavingRight:
        audioFeedback.playMessage("Line moving right", isUrgent: true);
        break;
      case LinePosition.visible:
        if (isStable && isCentered) {
          if (_stableFrameCount == MIN_STABLE_FRAMES) {
            audioFeedback.playMessage("Centered", isPositive: true);
          }
        } else {
          audioFeedback.provideFeedback(
            isLeft: isLeft,
            isRight: isRight,
            isCentered: isCentered,
            isLineLost: isLineLost,
            isStable: isStable,
            needsCorrection: needsCorrection,
            deviation: currentDeviation,
            linePosition: linePosition,
          );
        }
        break;
      case LinePosition.unknown:
        // Handle unknown state
        if (!isLineLost) {
          audioFeedback.playMessage("Uncertain position");
        }
        break;
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