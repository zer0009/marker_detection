// lib/services/line_detector.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import '../services/audio_feedback.dart';
import '../utils/image_processing.dart';
import '../models/settings_model.dart';
import 'dart:ui';
import 'dart:typed_data';

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
  Uint8List? _debugImageBytes;

  // Add movement threshold
  static const double MOVEMENT_THRESHOLD = 0.3; // 30% of screen width
  bool _isStable = true;
  
  LineDetector({required this.audioFeedback, required this.settings});

  CameraController? get cameraController => _cameraController;
  double? get deviation => currentDeviation;
  Uint8List? get debugImageBytes => _debugImageBytes;
  bool get isStable => _isStable;

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

      // Create debug visualization
      if (settings.showDebugView) {
        img.Image debugImage = img.copyResize(convertedImage, width: 320);
        
        // Draw center line (ideal position)
        int centerX = debugImage.width ~/ 2;
        for (int y = 0; y < debugImage.height; y++) {
          debugImage.setPixelRgba(centerX, y, 0, 255, 0, 128); // Semi-transparent green
        }
        
        // Draw detected line
        int? linePosition = ImageProcessing.detectLine(convertedImage, settings);
        if (linePosition != null) {
          int scaledPosition = (linePosition * debugImage.width) ~/ convertedImage.width;
          for (int y = 0; y < debugImage.height; y++) {
            debugImage.setPixelRgba(scaledPosition, y, 255, 0, 0, 255); // Red
          }
          
          // Draw deviation zone
          double sensitivity = (settings.sensitivity / 2).clamp(5.0, 50.0);
          int zoneWidth = (debugImage.width * (sensitivity / 100)).round();
          for (int y = 0; y < debugImage.height; y++) {
            debugImage.setPixelRgba(centerX - zoneWidth, y, 255, 255, 0, 128); // Yellow
            debugImage.setPixelRgba(centerX + zoneWidth, y, 255, 255, 0, 128); // Yellow
          }
        }
        
        _debugImageBytes = Uint8List.fromList(img.encodePng(debugImage));
        notifyListeners();
      }

      int? linePosition = ImageProcessing.detectLine(convertedImage, settings);
      if (linePosition != null) {
        double deviation = ImageProcessing.calculateDeviation(linePosition, convertedImage.width);
        currentDeviation = deviation;
        
        // Get sensitivity threshold from settings
        double sensitivity = (settings.sensitivity / 2).clamp(5.0, 50.0);
        
        // Check if movement is too rapid
        _isStable = deviation.abs() < MOVEMENT_THRESHOLD * convertedImage.width;
        
        bool shouldUpdateUI = false;

        if (_isStable) {
          // Update status based on deviation
          if (deviation.abs() > sensitivity) {
            bool newIsLeft = deviation < 0;
            isCentered = false;
            
            if (newIsLeft != isLeft || (!newIsLeft && isRight != true)) {
              isLeft = newIsLeft;
              isRight = !newIsLeft;
              
              // Play appropriate audio feedback with direction guidance
              if (isLeft) {
                audioFeedback.playLeftWarning();
                if (deviation.abs() > sensitivity * 1.5) {
                  audioFeedback.playMessage("Move right slowly");
                }
              } else {
                audioFeedback.playRightWarning();
                if (deviation.abs() > sensitivity * 1.5) {
                  audioFeedback.playMessage("Move left slowly");
                }
              }
              shouldUpdateUI = true;
            }
          } else {
            // Line is centered
            if (!isCentered || isLeft || isRight) {
              isLeft = false;
              isRight = false;
              isCentered = true;
              audioFeedback.playMessage("Centered");
              shouldUpdateUI = true;
            }
          }
        } else {
          // Camera movement too rapid
          audioFeedback.playMessage("Hold phone more steady");
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
          audioFeedback.playMessage("Line lost");
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