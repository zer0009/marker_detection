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

  double _cannyThreshold1 = 30.0;
  double _cannyThreshold2 = 90.0;
  int _gaussianBlurSize = 3;
  int _guidanceCooldown = 3;

  SettingsModel({
    double sensitivity = 30.0,
    int minLineWidth = 15,
    double luminanceThreshold = 80.0,
    int scanLines = 30,
    Color lineColor = Colors.black,
    bool useAdaptiveThreshold = true,
    bool showDebugView = true,
    bool showLineHighlight = true,
    double contrastEnhancement = 1.5,
    double cannyThreshold1 = 30.0,
    double cannyThreshold2 = 90.0,
    int gaussianBlurSize = 3,
    int guidanceCooldown = 3,
  })  : _sensitivity = sensitivity,
        _minLineWidth = minLineWidth,
        _luminanceThreshold = luminanceThreshold,
        _scanLines = scanLines,
        _lineColor = lineColor,
        _useAdaptiveThreshold = useAdaptiveThreshold,
        _showDebugView = showDebugView,
        _showLineHighlight = showLineHighlight,
        _contrastEnhancement = contrastEnhancement,
        _cannyThreshold1 = cannyThreshold1,
        _cannyThreshold2 = cannyThreshold2,
        _gaussianBlurSize = gaussianBlurSize,
        _guidanceCooldown = guidanceCooldown;

  double get sensitivity => _sensitivity;
  int get minLineWidth => _minLineWidth;
  double get luminanceThreshold => _luminanceThreshold;
  int get scanLines => _scanLines;
  Color get lineColor => _lineColor;
  bool get useAdaptiveThreshold => _useAdaptiveThreshold;
  bool get showDebugView => _showDebugView;
  bool get showLineHighlight => _showLineHighlight;
  double get contrastEnhancement => _contrastEnhancement;
  double get cannyThreshold1 => _cannyThreshold1;
  double get cannyThreshold2 => _cannyThreshold2;
  int get gaussianBlurSize => _gaussianBlurSize;
  int get guidanceCooldown => _guidanceCooldown;

  void setSensitivity(double value) {
    _sensitivity = value.clamp(10.0, 100.0);
    notifyListeners();
    _saveToPreferences();
  }

  void setMinLineWidth(int value) {
    _minLineWidth = value.clamp(5, 50);
    notifyListeners();
    _saveToPreferences();
  }

  void setLuminanceThreshold(double value) {
    _luminanceThreshold = value.clamp(50.0, 200.0);
    notifyListeners();
    _saveToPreferences();
  }

  void setScanLines(int value) {
    _scanLines = value.clamp(10, 60);
    notifyListeners();
    _saveToPreferences();
  }

  void setLineColor(Color value) {
    _lineColor = value;
    notifyListeners();
    _saveToPreferences();
  }

  void setUseAdaptiveThreshold(bool value) {
    _useAdaptiveThreshold = value;
    notifyListeners();
    _saveToPreferences();
  }

  void setShowDebugView(bool value) {
    _showDebugView = value;
    notifyListeners();
    _saveToPreferences();
  }

  void setShowLineHighlight(bool value) {
    _showLineHighlight = value;
    notifyListeners();
    _saveToPreferences();
  }

  void setContrastEnhancement(double value) {
    _contrastEnhancement = value.clamp(1.0, 2.0);
    notifyListeners();
    _saveToPreferences();
  }

  void setCannyThreshold1(double value) {
    _cannyThreshold1 = value.clamp(0.0, 255.0);
    notifyListeners();
    _saveToPreferences();
  }

  void setCannyThreshold2(double value) {
    _cannyThreshold2 = value.clamp(0.0, 255.0);
    notifyListeners();
    _saveToPreferences();
  }

  void setGaussianBlurSize(int value) {
    _gaussianBlurSize = value.clamp(1, 10);
    notifyListeners();
    _saveToPreferences();
  }

  void setGuidanceCooldown(int value) {
    _guidanceCooldown = value.clamp(1, 10);
    notifyListeners();
    _saveToPreferences();
  }

  Future<void> loadFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _sensitivity = prefs.getDouble('sensitivity') ?? _sensitivity;
    _minLineWidth = prefs.getInt('minLineWidth') ?? _minLineWidth;
    _luminanceThreshold = prefs.getDouble('luminanceThreshold') ?? _luminanceThreshold;
    _scanLines = prefs.getInt('scanLines') ?? _scanLines;
    _lineColor = Color(prefs.getInt('lineColor') ?? _lineColor.value);
    _useAdaptiveThreshold = prefs.getBool('useAdaptiveThreshold') ?? _useAdaptiveThreshold;
    _showDebugView = prefs.getBool('showDebugView') ?? _showDebugView;
    _showLineHighlight = prefs.getBool('showLineHighlight') ?? _showLineHighlight;
    _contrastEnhancement = prefs.getDouble('contrastEnhancement') ?? _contrastEnhancement;
    _cannyThreshold1 = prefs.getDouble('cannyThreshold1') ?? _cannyThreshold1;
    _cannyThreshold2 = prefs.getDouble('cannyThreshold2') ?? _cannyThreshold2;
    _gaussianBlurSize = prefs.getInt('gaussianBlurSize') ?? _gaussianBlurSize;
    _guidanceCooldown = prefs.getInt('guidanceCooldown') ?? _guidanceCooldown;
    notifyListeners();
  }

  Future<void> _saveToPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('sensitivity', _sensitivity);
    await prefs.setInt('minLineWidth', _minLineWidth);
    await prefs.setDouble('luminanceThreshold', _luminanceThreshold);
    await prefs.setInt('scanLines', _scanLines);
    await prefs.setInt('lineColor', _lineColor.value);
    await prefs.setBool('useAdaptiveThreshold', _useAdaptiveThreshold);
    await prefs.setBool('showDebugView', _showDebugView);
    await prefs.setBool('showLineHighlight', _showLineHighlight);
    await prefs.setDouble('contrastEnhancement', _contrastEnhancement);
    await prefs.setDouble('cannyThreshold1', _cannyThreshold1);
    await prefs.setDouble('cannyThreshold2', _cannyThreshold2);
    await prefs.setInt('gaussianBlurSize', _gaussianBlurSize);
    await prefs.setInt('guidanceCooldown', _guidanceCooldown);
  }

  void initialize() {
    loadFromPreferences();
  }
}