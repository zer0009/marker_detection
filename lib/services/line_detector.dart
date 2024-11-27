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
  final AudioFeedback audioFeedback;
  final SettingsModel settings;
  bool _isProcessing = false;
  DateTime? _lastDetectionTime;
  final Duration debounceDuration = Duration(milliseconds: 500); // 500ms debounce

  LineDetector({required this.audioFeedback, required this.settings});

  CameraController? get cameraController => _cameraController;

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
    if (_isProcessing) return;
    
    // Debounce to prevent processing too frequently
    if (_lastDetectionTime != null) {
      final difference = DateTime.now().difference(_lastDetectionTime!);
      if (difference < debounceDuration) {
        return;
      }
    }

    _isProcessing = true;
    _lastDetectionTime = DateTime.now();

    print("Processing image: ${image.width}x${image.height}");

    try {
      img.Image? convertedImage = ImageProcessing.convertCameraImage(image);
      if (convertedImage == null) {
        _isProcessing = false;
        return;
      }

      int? linePosition = ImageProcessing.detectLine(convertedImage);
      if (linePosition != null) {
        double deviation = ImageProcessing.calculateDeviation(linePosition, convertedImage.width);
        
        // Get sensitivity threshold (normalized to match deviation scale)
        double sensitivity = settings.sensitivity / 2; // Adjust sensitivity scale
        
        print('Processing - Deviation: $deviation, Sensitivity Threshold: $sensitivity');

        bool shouldUpdateUI = false;

        if (deviation < -sensitivity) {
          // Significant left deviation
          if (!isLeft) {
            print('Detected LEFT deviation');
            await audioFeedback.playLeftWarning();
            isLeft = true;
            isRight = false;
            shouldUpdateUI = true;
          }
        } else if (deviation > sensitivity) {
          // Significant right deviation
          if (!isRight) {
            print('Detected RIGHT deviation');
            await audioFeedback.playRightWarning();
            isRight = true;
            isLeft = false;
            shouldUpdateUI = true;
          }
        } else {
          // Centered
          if (isLeft || isRight) {
            print('Detected CENTER position');
            isLeft = false;
            isRight = false;
            shouldUpdateUI = true;
          }
        }

        if (shouldUpdateUI) {
          notifyListeners();
        }
      } else {
        // If no line detected, reset indicators
        if (isLeft || isRight) {
          print('No line detected, resetting indicators');
          isLeft = false;
          isRight = false;
          notifyListeners();
        }
      }
    } catch (e) {
      print('Error in _processImage: $e');
    }

    _isProcessing = false;
  }

  Future<void> startDetection() async {
    await initializeCamera();
  }

  void stopDetection() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _cameraController = null;
    if (isLeft || isRight) {
      isLeft = false;
      isRight = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }
}