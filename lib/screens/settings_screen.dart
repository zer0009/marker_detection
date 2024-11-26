// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/settings_model.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ListTile(
              title: const Text('Sensitivity'),
              subtitle: Slider(
                value: settings.sensitivity,
                min: 10,
                max: 100,
                divisions: 9,
                label: settings.sensitivity.round().toString(),
                onChanged: (double value) {
                  settings.setSensitivity(value);
                },
              ),
              trailing: Text(settings.sensitivity.round().toString()),
            ),
            // Additional settings can be added here
          ],
        ),
      ),
    );
  }
}