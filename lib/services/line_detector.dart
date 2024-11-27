// lib/services/line_detector.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import '../services/audio_feedback.dart';
import '../utils/image_processing.dart';
import '../models/settings_model.dart';

class LineDetector with ChangeNotifier {
  CameraController? _cameraController;
  bool isLeft = false;
  bool isRight = false;
  bool isCentered = true;
  double? currentDeviation;
  final AudioFeedback audioFeedback;
  final SettingsModel settings;
  bool _isProcessing = false;
  DateTime? _lastDetectionTime;
  final Duration debounceDuration = Duration(milliseconds: 100); // Reduced to 100ms

  LineDetector({required this.audioFeedback, required this.settings});

  CameraController? get cameraController => _cameraController;
  double? get deviation => currentDeviation;

  Future<void> initializeCamera() async {
    try {
      print("Starting camera initialization");
      final cameras = await availableCameras();
      print("Available cameras: ${cameras.length}");
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
        (_lastDetectionTime != null && 
         DateTime.now().difference(_lastDetectionTime!) < debounceDuration)) {
      return;
    }

    _isProcessing = true;
    _lastDetectionTime = DateTime.now();

    try {
      img.Image? convertedImage = ImageProcessing.convertCameraImage(image);
      if (convertedImage == null) {
        _isProcessing = false;
        return;
      }

      // Pass settings to detectLine
      int? linePosition = ImageProcessing.detectLine(convertedImage, settings);
      if (linePosition != null) {
        double deviation = ImageProcessing.calculateDeviation(linePosition, convertedImage.width);
        currentDeviation = deviation;
        
        // Get sensitivity threshold from settings
        double sensitivity = (settings.sensitivity / 2).clamp(5.0, 50.0);
        
        print('Processing - Deviation: $deviation, Sensitivity: $sensitivity');
        bool shouldUpdateUI = false;

        // Update status based on deviation
        if (deviation.abs() > sensitivity) {
          bool newIsLeft = deviation < 0;
          isCentered = false;
          
          if (newIsLeft != isLeft || (!newIsLeft && isRight != true)) {
            isLeft = newIsLeft;
            isRight = !newIsLeft;
            
            // Play appropriate audio feedback
            if (isLeft) {
              audioFeedback.playLeftWarning();
            } else {
              audioFeedback.playRightWarning();
            }
            shouldUpdateUI = true;
          }
        } else {
          // Line is centered
          if (!isCentered || isLeft || isRight) {
            isLeft = false;
            isRight = false;
            isCentered = true;
            shouldUpdateUI = true;
          }
        }

        if (shouldUpdateUI) {
          notifyListeners();
        }
      } else {
        // No line detected
        if (isLeft || isRight || isCentered) {
          isLeft = false;
          isRight = false;
          isCentered = false;
          currentDeviation = null;
          notifyListeners();
        }
      }
    } catch (e) {
      print('Error in _processImage: $e');
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> startDetection() async {
    isLeft = false;
    isRight = false;
    isCentered = false;
    currentDeviation = null;
    await initializeCamera();
  }

  void stopDetection() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _cameraController = null;
    isLeft = false;
    isRight = false;
    isCentered = false;
    currentDeviation = null;
    notifyListeners();
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
    super.dispose();
  }
}