// lib/services/audio_feedback.dart
import 'package:flutter_tts/flutter_tts.dart';

class AudioFeedback {
  final FlutterTts _flutterTts = FlutterTts();
  DateTime? _lastMessageTime;
  static const messageCooldown = Duration(milliseconds: 2000);
  bool _isSpeaking = false;

  String _lastMessage = '';
  int _repeatCount = 0;
  static const int MAX_REPEATS = 3;
  static const Duration URGENT_COOLDOWN = Duration(milliseconds: 1000);
  static const Duration NORMAL_COOLDOWN = Duration(milliseconds: 2000);

  AudioFeedback() {
    _initializeTTS();
  }

  Future<void> _initializeTTS() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.45);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      
      var voices = await _flutterTts.getVoices;
      for (var voice in voices) {
        if (voice.toString().contains("en-US")) {
          await _flutterTts.setVoice({"name": voice.toString(), "locale": "en-US"});
          break;
        }
      }

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
      });

      print('TTS initialized successfully');
    } catch (e) {
      print('Error initializing TTS: $e');
    }
  }

  Future<void> playMessage(String message, {bool isWarning = false}) async {
    try {
      if (_isSpeaking || 
          (_lastMessageTime != null && 
           DateTime.now().difference(_lastMessageTime!) < messageCooldown)) {
        return;
      }

      _isSpeaking = true;
      _lastMessageTime = DateTime.now();
      
      await _flutterTts.stop();
      
      if (isWarning) {
        await _flutterTts.setSpeechRate(0.45);
        await _flutterTts.setPitch(1.1);
      } else {
        await _flutterTts.setSpeechRate(0.4);
        await _flutterTts.setPitch(1.0);
      }
      
      var result = await _flutterTts.speak(message);
      if (result != 1) {
        _isSpeaking = false;
      }
    } catch (e) {
      print('Error in playMessage: $e');
      _isSpeaking = false;
    }
  }

  Future<void> playLeftWarning() async {
    await playMessage("Move Right", isWarning: true);
  }

  Future<void> playRightWarning() async {
    await playMessage("Move Left", isWarning: true);
  }

  Future<void> playCentered() async {
    await playMessage("On Track");
  }

  Future<void> playLineLost() async {
    await playMessage("Stop, Line Lost", isWarning: true);
  }

  Future<void> playHoldSteady() async {
    await playMessage("Hold Steady", isWarning: true);
  }

  Future<void> playStarting() async {
    await playMessage("Starting Line Detection");
  }

  Future<void> playStopping() async {
    await playMessage("Stopping");
  }

  Future<void> provideFeedback({
    required bool isLeft,
    required bool isRight,
    required bool isCentered,
    required bool isLineLost,
    required bool isStable,
    required bool needsCorrection,
    double? deviation,
  }) async {
    if (_isSpeaking) return;

    String message = '';
    bool isUrgent = false;
    
    if (isLineLost) {
      message = "Stop, Line Lost";
      isUrgent = true;
    } else if (needsCorrection) {
      if (isLeft) {
        message = "Move Right Now";
      } else if (isRight) {
        message = "Move Left Now";
      }
      isUrgent = true;
    } else if (!isStable) {
      if (isLeft) {
        message = "Slight Right";
      } else if (isRight) {
        message = "Slight Left";
      }
    } else if (isCentered && isStable) {
      message = "Good";
      _repeatCount = 0; // Reset repeat count for centered position
    }

    // Handle message repetition and cooldown
    if (message == _lastMessage) {
      _repeatCount++;
      if (_repeatCount >= MAX_REPEATS) {
        return; // Don't repeat too many times
      }
    } else {
      _repeatCount = 0;
      _lastMessage = message;
    }

    // Check cooldown
    if (_lastMessageTime != null) {
      Duration cooldown = isUrgent ? URGENT_COOLDOWN : NORMAL_COOLDOWN;
      if (DateTime.now().difference(_lastMessageTime!) < cooldown) {
        return;
      }
    }

    if (message.isNotEmpty) {
      await playMessage(message, isWarning: isUrgent);
    }
  }

  @override
  void dispose() {
    try {
      _flutterTts.stop();
    } catch (e) {
      print('Error disposing audio feedback: $e');
    }
  }
}