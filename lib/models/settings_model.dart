// lib/models/settings_model.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsModel with ChangeNotifier {
  double _sensitivity = 30.0; // Default sensitivity

  double get sensitivity => _sensitivity;

  SettingsModel() {
    _loadSettings();
  }

  void setSensitivity(double value) {
    _sensitivity = value;
    notifyListeners();
    _saveSettings();
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _sensitivity = prefs.getDouble('sensitivity') ?? 30.0;
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('sensitivity', _sensitivity);
  }
}