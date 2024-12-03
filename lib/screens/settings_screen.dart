// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/settings_model.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSection(
            'Detection Settings',
            [
              ListTile(
                title: const Text('Sensitivity'),
                subtitle: Slider(
                  value: settings.sensitivity,
                  min: 10,
                  max: 100,
                  divisions: 90,
                  label: settings.sensitivity.round().toString(),
                  onChanged: (value) => settings.setSensitivity(value),
                ),
                trailing: Text(settings.sensitivity.round().toString()),
              ),
              ListTile(
                title: const Text('Minimum Line Width (pixels)'),
                subtitle: Slider(
                  value: settings.minLineWidth.toDouble(),
                  min: 5,
                  max: 50,
                  divisions: 45,
                  label: settings.minLineWidth.toString(),
                  onChanged: (value) => settings.setMinLineWidth(value.round()),
                ),
                trailing: Text(settings.minLineWidth.toString()),
              ),
              ListTile(
                title: const Text('Canny Threshold 1'),
                subtitle: Slider(
                  value: settings.cannyThreshold1,
                  min: 0,
                  max: 255,
                  divisions: 255,
                  label: settings.cannyThreshold1.round().toString(),
                  onChanged: (value) => settings.setCannyThreshold1(value),
                ),
                trailing: Text(settings.cannyThreshold1.round().toString()),
              ),
              ListTile(
                title: const Text('Canny Threshold 2'),
                subtitle: Slider(
                  value: settings.cannyThreshold2,
                  min: 0,
                  max: 255,
                  divisions: 255,
                  label: settings.cannyThreshold2.round().toString(),
                  onChanged: (value) => settings.setCannyThreshold2(value),
                ),
                trailing: Text(settings.cannyThreshold2.round().toString()),
              ),
            ],
          ),
          _buildSection(
            'Image Processing',
            [
              ListTile(
                title: const Text('Luminance Threshold'),
                subtitle: Slider(
                  value: settings.luminanceThreshold,
                  min: 50,
                  max: 200,
                  divisions: 150,
                  label: settings.luminanceThreshold.round().toString(),
                  onChanged: (value) => settings.setLuminanceThreshold(value),
                ),
                trailing: Text(settings.luminanceThreshold.round().toString()),
              ),
              ListTile(
                title: const Text('Scan Lines'),
                subtitle: Slider(
                  value: settings.scanLines.toDouble(),
                  min: 10,
                  max: 60,
                  divisions: 50,
                  label: settings.scanLines.toString(),
                  onChanged: (value) => settings.setScanLines(value.round()),
                ),
                trailing: Text(settings.scanLines.toString()),
              ),
              ListTile(
                title: const Text('Gaussian Blur Size'),
                subtitle: Slider(
                  value: settings.gaussianBlurSize.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: settings.gaussianBlurSize.toString(),
                  onChanged: (value) => settings.setGaussianBlurSize(value.round()),
                ),
                trailing: Text(settings.gaussianBlurSize.toString()),
              ),
              ListTile(
                title: const Text('Guidance Cooldown (seconds)'),
                subtitle: Slider(
                  value: settings.guidanceCooldown.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: settings.guidanceCooldown.toString(),
                  onChanged: (value) => settings.setGuidanceCooldown(value.round()),
                ),
                trailing: Text(settings.guidanceCooldown.toString()),
              ),
              SwitchListTile(
                title: const Text('Use Adaptive Threshold'),
                subtitle: const Text('Better for varying lighting conditions'),
                value: settings.useAdaptiveThreshold,
                onChanged: (value) => settings.setUseAdaptiveThreshold(value),
              ),
              SwitchListTile(
                title: const Text('Show Debug View'),
                subtitle: const Text('Display line detection visualization'),
                value: settings.showDebugView,
                onChanged: (value) => settings.setShowDebugView(value),
              ),
              ListTile(
                title: const Text('Contrast Enhancement'),
                subtitle: Slider(
                  value: settings.contrastEnhancement,
                  min: 1.0,
                  max: 2.0,
                  divisions: 20,
                  label: settings.contrastEnhancement.toStringAsFixed(1),
                  onChanged: (value) => settings.setContrastEnhancement(value),
                ),
                trailing: Text(settings.contrastEnhancement.toStringAsFixed(1)),
              ),
              SwitchListTile(
                title: const Text('Show Line Highlight'),
                subtitle: const Text('Highlight detected line position'),
                value: settings.showLineHighlight,
                onChanged: (value) => settings.setShowLineHighlight(value),
              ),
            ],
          ),
          _buildSection(
            'Line Color',
            [
              ListTile(
                title: const Text('Target Line Color'),
                subtitle: const Text('Tap to change color'),
                trailing: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: settings.lineColor,
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onTap: () => _showColorPicker(context, settings),
              ),
            ],
          ),
          _buildSection(
            'Help',
            [
              const ExpansionTile(
                title: Text('Settings Guide'),
                children: [
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• Sensitivity: Controls how quickly the app responds to deviation'),
                        SizedBox(height: 8),
                        Text('• Line Width: Minimum width of the line to detect'),
                        SizedBox(height: 8),
                        Text('• Canny Thresholds: Define the lower and upper bounds for edge detection'),
                        SizedBox(height: 8),
                        Text('• Gaussian Blur Size: Determines the level of blur applied to the image'),
                        SizedBox(height: 8),
                        Text('• Guidance Cooldown: Time between guidance messages'),
                        SizedBox(height: 8),
                        Text('• Luminance: Brightness threshold for line detection'),
                        SizedBox(height: 8),
                        Text('• Scan Lines: Number of scanning points for detection'),
                        SizedBox(height: 8),
                        Text('• Adaptive Threshold: Helps with varying lighting conditions'),
                        SizedBox(height: 8),
                        Text('• Contrast Enhancement: Enhances contrast in processed images'),
                        SizedBox(height: 8),
                        Text('• Show Debug View: Display line detection visualization'),
                        SizedBox(height: 8),
                        Text('• Show Line Highlight: Highlight detected line position'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method to build sections
  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Section Content
          ...children,
        ],
      ),
    );
  }

  // Method to display color picker dialog
  void _showColorPicker(BuildContext context, SettingsModel settings) {
    Color tempColor = settings.lineColor;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pick Line Color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: tempColor,
              onColorChanged: (Color color) {
                tempColor = color;
              },
              showLabel: true,
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Done'),
              onPressed: () {
                settings.setLineColor(tempColor);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}