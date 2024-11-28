// lib/models/settings_model.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsModel extends ChangeNotifier {
  double _sensitivity = 30.0;
  int _minLineWidth = 15;
  double _luminanceThreshold = 80.0;
  int _scanLines = 30;
  Color _lineColor = Colors.black;
  bool _useAdaptiveThreshold = true;
  bool _showDebugView = true;
  bool _showLineHighlight = true;
  double _contrastEnhancement = 1.5;

  // Getters
  double get sensitivity => _sensitivity;
  int get minLineWidth => _minLineWidth;
  double get luminanceThreshold => _luminanceThreshold;
  int get scanLines => _scanLines;
  Color get lineColor => _lineColor;
  bool get useAdaptiveThreshold => _useAdaptiveThreshold;
  bool get showDebugView => _showDebugView;
  bool get showLineHighlight => _showLineHighlight;
  double get contrastEnhancement => _contrastEnhancement;

  // Setters
  void setSensitivity(double value) {
    _sensitivity = value.clamp(10.0, 50.0);
    notifyListeners();
  }

  void setMinLineWidth(int value) {
    _minLineWidth = value;
    notifyListeners();
  }

  void setLuminanceThreshold(double value) {
    _luminanceThreshold = value;
    notifyListeners();
  }

  void setScanLines(int value) {
    _scanLines = value;
    notifyListeners();
  }

  void setLineColor(Color value) {
    _lineColor = value;
    notifyListeners();
  }

  void setUseAdaptiveThreshold(bool value) {
    _useAdaptiveThreshold = value;
    notifyListeners();
  }

  void setShowDebugView(bool value) {
    _showDebugView = value;
    notifyListeners();
  }

  void setShowLineHighlight(bool value) {
    _showLineHighlight = value;
    notifyListeners();
  }

  void setContrastEnhancement(double value) {
    _contrastEnhancement = value;
    notifyListeners();
  }
}