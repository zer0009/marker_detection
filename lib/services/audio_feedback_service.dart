import 'package:flutter_tts/flutter_tts.dart';
import '../models/line_detection_result.dart';

class AudioFeedbackService {
  final FlutterTts _tts = FlutterTts();
  LineDetectionResult? _lastResult;
  DateTime? _lastFeedbackTime;
  bool _isSpeaking = false;
  double _lastPosition = 0.5;
  
  AudioFeedbackService() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.8);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
    });
  }

  Future<void> provideFeedback(LineDetectionResult result, double linePosition) async {
    if (_lastFeedbackTime != null && 
        DateTime.now().difference(_lastFeedbackTime!) < const Duration(milliseconds: 1200)) {
      return;
    }

    if (_isSpeaking) return;

    if (_shouldProvideFeedback(result, linePosition)) {
      String message = _getFeedbackMessage(result, linePosition);

      if (message.isNotEmpty) {
        _isSpeaking = true;
        _lastFeedbackTime = DateTime.now();
        _lastResult = result;
        _lastPosition = linePosition;
        await _tts.speak(message);
      }
    }
  }

  bool _shouldProvideFeedback(LineDetectionResult result, double position) {
    if (result != _lastResult) return true;
    
    double positionChange = (position - _lastPosition).abs();
    
    if (positionChange > 0.15) return true;
    
    if (result == LineDetectionResult.lineNotFound) return true;
    
    return false;
  }

  String _getFeedbackMessage(LineDetectionResult result, double linePosition) {
    switch (result) {
      case LineDetectionResult.leftDeviation:
        final deviation = (0.5 - linePosition).abs();
        if (deviation > 0.3) {
          return 'Far right';
        } else if (deviation > 0.15) {
          return 'Move left';
        }
        return 'Slightly left';
        
      case LineDetectionResult.rightDeviation:
        final deviation = (linePosition - 0.5).abs();
        if (deviation > 0.3) {
          return 'Far left';
        } else if (deviation > 0.15) {
          return 'Move right';
        }
        return 'Slightly right';
        
      case LineDetectionResult.centered:
        if (_lastResult != LineDetectionResult.centered) {
          return 'Centered';
        }
        return '';
        
      case LineDetectionResult.lineNotFound:
        if (_lastResult != LineDetectionResult.lineNotFound) {
          return 'Line lost, searching';
        }
        return '';
        
      default:
        return '';
    }
  }

  Future<void> stop() async {
    _isSpeaking = false;
    await _tts.stop();
  }

  void dispose() {
    stop();
  }
} 