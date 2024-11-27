// lib/services/audio_feedback.dart
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';

class AudioFeedback {
  final FlutterTts _flutterTts = FlutterTts();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool _isPlayerInitialized = false;

  AudioFeedback() {
    _initializeTTS();
    _initializePlayer();
  }

  Future<void> _initializeTTS() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      print('TTS initialized successfully');
    } catch (e) {
      print('Error initializing TTS: $e');
    }
  }

  Future<void> _initializePlayer() async {
    try {
      await _player.openPlayer();
      _isPlayerInitialized = true;
      print('Sound player initialized successfully');
    } catch (e) {
      print('Error initializing sound player: $e');
      _isPlayerInitialized = false;
    }
  }

  Future<void> speakLeft() async {
    await _flutterTts.speak("You are veering to the left.");
  }

  Future<void> speakRight() async {
    await _flutterTts.speak("You are veering to the right.");
  }

  Future<void> playLeftWarning() async {
    if (!_isPlayerInitialized) {
      print('Player not initialized, falling back to TTS');
      return await speakLeft();
    }

    try {
      final audioData = await _loadAsset('assets/audio/left_warning.mp3');
      await _player.startPlayer(
        fromDataBuffer: audioData,
        codec: Codec.mp3,
        whenFinished: () {
          print('Left warning sound completed');
        },
      );
    } catch (e) {
      print('Error playing left warning sound: $e');
      // Fallback to TTS if sound fails
      await speakLeft();
    }
  }

  Future<void> playRightWarning() async {
    if (!_isPlayerInitialized) {
      print('Player not initialized, falling back to TTS');
      return await speakRight();
    }

    try {
      final audioData = await _loadAsset('assets/audio/right_warning.mp3');
      await _player.startPlayer(
        fromDataBuffer: audioData,
        codec: Codec.mp3,
        whenFinished: () {
          print('Right warning sound completed');
        },
      );
    } catch (e) {
      print('Error playing right warning sound: $e');
      // Fallback to TTS if sound fails
      await speakRight();
    }
  }

  Future<Uint8List> _loadAsset(String path) async {
    try {
      final ByteData data = await rootBundle.load(path);
      return data.buffer.asUint8List();
    } catch (e) {
      print('Error loading asset $path: $e');
      throw Exception('Failed to load audio asset');
    }
  }

  @override
  void dispose() {
    try {
      _flutterTts.stop();
      if (_isPlayerInitialized) {
        _player.closePlayer();
      }
    } catch (e) {
      print('Error disposing audio feedback: $e');
    }
  }
}