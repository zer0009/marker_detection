// lib/models/settings_model.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsModel with ChangeNotifier {
  double _sensitivity = 50;
  int _minLineWidth = 15;
  double _luminanceThreshold = 120;
  int _scanLines = 30;
  Color _lineColor = Colors.black;
  bool _useAdaptiveThreshold = true;
  bool _showDebugView = false;

  // Getters
  double get sensitivity => _sensitivity;
  int get minLineWidth => _minLineWidth;
  double get luminanceThreshold => _luminanceThreshold;
  int get scanLines => _scanLines;
  Color get lineColor => _lineColor;
  bool get useAdaptiveThreshold => _useAdaptiveThreshold;
  bool get showDebugView => _showDebugView;

  // Setters
  void setSensitivity(double value) {
    _sensitivity = value;
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
}