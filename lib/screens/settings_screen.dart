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
                  max: 50,
                  divisions: 40,
                  label: settings.scanLines.toString(),
                  onChanged: (value) => settings.setScanLines(value.round()),
                ),
                trailing: Text(settings.scanLines.toString()),
              ),
              SwitchListTile(
                title: const Text('Use Adaptive Threshold'),
                subtitle: const Text('Better for varying lighting conditions'),
                value: settings.useAdaptiveThreshold,
                onChanged: (value) => settings.setUseAdaptiveThreshold(value),
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
                        Text('• Luminance: Brightness threshold for line detection'),
                        SizedBox(height: 8),
                        Text('• Scan Lines: Number of scanning points for detection'),
                        SizedBox(height: 8),
                        Text('• Adaptive Threshold: Helps with varying lighting conditions'),
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

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          ...children,
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context, SettingsModel settings) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pick Line Color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: settings.lineColor,
              onColorChanged: (Color color) {
                settings.setLineColor(color);
              },
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Done'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}