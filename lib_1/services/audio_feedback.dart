// lib_2/services/audio_feedback.dart
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:math' as math;

import '../models/line_position.dart';

class AudioFeedback {
  final FlutterTts _flutterTts = FlutterTts();
  DateTime? _lastMessageTime;
  bool _isSpeaking = false;
  String _lastMessage = '';
  
  // Enhanced feedback timing
  static const Duration URGENT_COOLDOWN = Duration(milliseconds: 1500);
  static const Duration NORMAL_COOLDOWN = Duration(milliseconds: 2000);
  static const Duration STABLE_COOLDOWN = Duration(milliseconds: 3000);
  
  // Deviation thresholds
  static const double SLIGHT_DEVIATION = 5.0;
  static const double MODERATE_DEVIATION = 15.0;
  static const double SEVERE_DEVIATION = 30.0;

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
      await _flutterTts.setSpeechRate(0.45);  // Slower for better clarity
      await _flutterTts.setVolume(0.9);
      await _flutterTts.setPitch(1.0);
      
      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
      });

      // Set up error handler
      _flutterTts.setErrorHandler((msg) {
        _isSpeaking = false;
        print('TTS error: $msg');
      });

    } catch (e) {
      print('Error initializing TTS: $e');
    }
  }

  Future<void> playMessage(String message, {
    bool isUrgent = false,
    bool isPositive = false,
  }) async {
    try {
      if (_isSpeaking || message.isEmpty) return;

      // Check cooldown period
      Duration cooldown = isUrgent ? URGENT_COOLDOWN : 
                         isPositive ? STABLE_COOLDOWN : NORMAL_COOLDOWN;

      if (_lastMessageTime != null && 
          DateTime.now().difference(_lastMessageTime!) < cooldown) {
        return;
      }

      // Handle message repetition
      if (message == _lastMessage) {
        _repeatCount++;
        if (_repeatCount >= MAX_REPEATS) {
          return;
        }
      } else {
        _repeatCount = 0;
      }

      // Stop any ongoing speech
      await _flutterTts.stop();
      
      _isSpeaking = true;
      _lastMessageTime = DateTime.now();
      _lastMessage = message;

      // Adjust speech parameters based on message type
      await _flutterTts.setSpeechRate(isUrgent ? 0.48 : 0.45);
      await _flutterTts.setPitch(isUrgent ? 1.1 : 1.0);
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

    // Skip feedback if deviation hasn't changed significantly
    if (_lastDeviation != null && deviation != null) {
      double deviationDiff = (deviation - _lastDeviation!).abs();
      if (deviationDiff < 3.0 && !isLineLost) return;
    }

    String message = '';
    bool isUrgent = false;
    bool isPositive = false;
    
    // Handle line position states first
    if (linePosition != null) {
      switch (linePosition) {
        case LinePosition.enteringLeft:
          message = "Line entering from left";
          isUrgent = true;
          break;
        case LinePosition.enteringRight:
          message = "Line entering from right";
          isUrgent = true;
          break;
        case LinePosition.leavingLeft:
          message = "Line leaving to left";
          isUrgent = true;
          break;
        case LinePosition.leavingRight:
          message = "Line leaving to right";
          isUrgent = true;
          break;
        case LinePosition.visible:
          // Handle deviation-based feedback
          if (deviation != null) {
            double deviationAbs = deviation.abs();
            if (deviationAbs <= SLIGHT_DEVIATION) {
              if (!_wasCentered) {
                message = "Centered";
                isPositive = true;
              }
            } else if (deviationAbs > SEVERE_DEVIATION) {
              message = "Move ${deviation < 0 ? 'right' : 'left'} quickly";
              isUrgent = true;
            } else if (deviationAbs > MODERATE_DEVIATION) {
              message = "Move ${deviation < 0 ? 'right' : 'left'}";
              isUrgent = true;
            } else {
              message = "Slight ${deviation < 0 ? 'right' : 'left'}";
            }
          }
          break;
        case LinePosition.unknown:
        default:
          if (isLineLost) {
            message = "Line lost";
            isUrgent = true;
          }
          break;
      }
    } else if (isLineLost) {
      message = "Line lost";
      isUrgent = true;
    }

    // Update state tracking
    _wasStable = isStable;
    _wasCentered = isCentered;
    _lastDeviation = deviation;

    if (message.isNotEmpty) {
      await playMessage(message, isUrgent: isUrgent, isPositive: isPositive);
    }
  }

  // System messages with reduced frequency
  Future<void> playStarting() async {
    _resetState();
    await playMessage("Starting", isPositive: true);
  }

  Future<void> playStopping() async {
    _resetState();
    await playMessage("Stopping");
  }

  Future<void> playSystemReady() async {
    _resetState();
    await playMessage("Ready", isPositive: true);
  }

  Future<void> playLowBattery() async {
    await playMessage("Low battery", isUrgent: true);
  }

  Future<void> playConnectionLost() async {
    _resetState();
    await playMessage("Camera lost", isUrgent: true);
  }

  /// Plays line lost feedback with appropriate urgency
  Future<void> playLineLost() async {
    // Reset state to ensure message is played
    _resetState();
    
    // Use different messages to avoid monotony
    final List<String> messages = [
      "Line lost",
      "Stop and scan",
      "Line not found",
    ];
    
    // Select a random message
    final random = math.Random();
    final message = messages[random.nextInt(messages.length)];
    
    await playMessage(
      message,
      isUrgent: true,
    );
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