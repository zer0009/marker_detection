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

  void _initializeTTS() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _initializePlayer() async {
    await _player.openPlayer();
    _isPlayerInitialized = true;
  }

  Future<void> speakLeft() async {
    await _flutterTts.speak("You are veering to the left.");
  }

  Future<void> speakRight() async {
    await _flutterTts.speak("You are veering to the right.");
  }

  Future<void> playLeftWarning() async {
    if (_isPlayerInitialized) {
      Uint8List audioData = await _loadAsset('assets/audio/left_warning.mp3');
      await _player.startPlayer(
        fromDataBuffer: audioData,
        codec: Codec.mp3,
      );
    }
  }

  Future<void> playRightWarning() async {
    if (_isPlayerInitialized) {
      Uint8List audioData = await _loadAsset('assets/audio/right_warning.mp3');
      await _player.startPlayer(
        fromDataBuffer: audioData,
        codec: Codec.mp3,
      );
    }
  }

  Future<Uint8List> _loadAsset(String path) async {
    ByteData data = await rootBundle.load(path);
    return data.buffer.asUint8List();
  }

  Future<void> stopPlayer() async {
    if (_isPlayerInitialized) {
      await _player.stopPlayer();
    }
  }

  void dispose() {
    _flutterTts.stop();
    _player.closePlayer();
  }
}