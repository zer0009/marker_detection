import 'package:flutter_tts/flutter_tts.dart';
import '../models/line_position.dart';

class AudioFeedback {
  final FlutterTts _flutterTts = FlutterTts();
  DateTime? _lastMessageTime;
  bool _isSpeaking = false;
  String _lastMessage = '';
  
  // Adjusted timing for better responsiveness
  static const Duration URGENT_COOLDOWN = Duration(milliseconds: 800);    // Reduced for faster response
  static const Duration NORMAL_COOLDOWN = Duration(milliseconds: 1500);   // Reduced for better flow
  static const Duration STABLE_COOLDOWN = Duration(milliseconds: 2500);   // Kept longer for stable states
  
  // Refined deviation thresholds
  static const double SLIGHT_DEVIATION = 0.1;    // 10% from center
  static const double MODERATE_DEVIATION = 0.2;  // 20% from center
  static const double SEVERE_DEVIATION = 0.4;    // 40% from center

  // State tracking
  bool _wasStable = false;
  bool _wasCentered = false;
  double? _lastDeviation;
  int _repeatCount = 0;
  static const int MAX_REPEATS = 2;

  AudioFeedback() {
    _initializeTTS();
  }

  Future<void> _initializeTTS() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.48);  // Slightly faster for better responsiveness
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      
      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
      });

      _flutterTts.setErrorHandler((msg) {
        _isSpeaking = false;
        print('TTS error: $msg');
      });
    } catch (e) {
      print('Error initializing TTS: $e');
    }
  }

  Future<void> provideFeedback({
    required bool isLeft,
    required bool isRight,
    required bool isCentered,
    required bool isLineLost,
    required bool isStable,
    required bool needsCorrection,
    double? deviation,
    LinePosition? linePosition,
  }) async {
    if (_isSpeaking) return;

    // More sensitive deviation change detection
    if (_lastDeviation != null && deviation != null) {
      double deviationDiff = (deviation - _lastDeviation!).abs();
      if (deviationDiff < 0.05 && !isLineLost && isStable) return;  // Skip minor changes when stable
    }

    String message = '';
    bool isUrgent = false;
    bool isPositive = false;

    if (linePosition != null) {
      switch (linePosition) {
        case LinePosition.enteringLeft:
          message = "Line on left";
          break;
        case LinePosition.enteringRight:
          message = "Line on right";
          break;
        case LinePosition.leavingLeft:
          message = "Turn right";
          isUrgent = true;
          break;
        case LinePosition.leavingRight:
          message = "Turn left";
          isUrgent = true;
          break;
        case LinePosition.visible:
          if (deviation != null) {
            double deviationAbs = deviation.abs();
            if (deviationAbs <= SLIGHT_DEVIATION) {
              if (!_wasCentered || isStable) {
                message = "Good";
                isPositive = true;
              }
            } else if (deviationAbs > SEVERE_DEVIATION) {
              message = "${deviation < 0 ? 'Right' : 'Left'} more";
              isUrgent = true;
            } else if (deviationAbs > MODERATE_DEVIATION) {
              message = "Go ${deviation < 0 ? 'right' : 'left'}";
            } else {
              message = "Slight ${deviation < 0 ? 'right' : 'left'}";
            }
          }
          break;
        case LinePosition.unknown:
          if (!isLineLost) {
            message = "Scanning";
          }
          break;
      }
    }

    // Update state tracking
    _wasStable = isStable;
    _wasCentered = isCentered;
    _lastDeviation = deviation;

    if (message.isNotEmpty) {
      await playMessage(message, isUrgent: isUrgent, isPositive: isPositive);
    }
  }

  Future<void> playMessage(String message, {
    bool isUrgent = false,
    bool isPositive = false,
  }) async {
    try {
      if (_isSpeaking || message.isEmpty) return;

      Duration cooldown = isUrgent ? URGENT_COOLDOWN : 
                         isPositive ? STABLE_COOLDOWN : NORMAL_COOLDOWN;

      if (_lastMessageTime != null && 
          DateTime.now().difference(_lastMessageTime!) < cooldown) {
        return;
      }

      if (message == _lastMessage) {
        _repeatCount++;
        if (_repeatCount >= MAX_REPEATS) return;
      } else {
        _repeatCount = 0;
      }

      await _flutterTts.stop();
      
      _isSpeaking = true;
      _lastMessageTime = DateTime.now();
      _lastMessage = message;

      // Adjust speech parameters for clarity
      await _flutterTts.setSpeechRate(isUrgent ? 0.5 : 0.48);
      await _flutterTts.setPitch(isUrgent ? 1.1 : isPositive ? 1.2 : 1.0);
      await _flutterTts.setVolume(isUrgent ? 1.0 : 0.9);
      
      var result = await _flutterTts.speak(message);
      if (result != 1) {
        _isSpeaking = false;
      }
    } catch (e) {
      print('Error in playMessage: $e');
      _isSpeaking = false;
    }
  }

  // Simplified system messages
  Future<void> playStarting() async {
    _resetState();
    await playMessage("Ready", isPositive: true);
  }

  Future<void> playStopping() async {
    _resetState();
    await playMessage("Stopped");
  }

  void _resetState() {
    _lastMessage = '';
    _lastMessageTime = null;
    _lastDeviation = null;
    _wasStable = false;
    _wasCentered = false;
    _repeatCount = 0;
  }

  Future<void> dispose() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      print('Error disposing audio feedback: $e');
    }
  }
}