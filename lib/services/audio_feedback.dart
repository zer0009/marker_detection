// lib/services/audio_feedback.dart
import 'package:flutter_tts/flutter_tts.dart';

class AudioFeedback {
  final FlutterTts _flutterTts = FlutterTts();
  DateTime? _lastMessageTime;
  static const messageCooldown = Duration(milliseconds: 2000);
  bool _isSpeaking = false;

  AudioFeedback() {
    _initializeTTS();
  }

  Future<void> _initializeTTS() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.4);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        print('TTS completed speaking');
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

  @override
  void dispose() {
    try {
      _flutterTts.stop();
    } catch (e) {
      print('Error disposing audio feedback: $e');
    }
  }
}