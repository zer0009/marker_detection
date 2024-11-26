// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'services/line_detector.dart';
import 'services/audio_feedback.dart';
import 'models/settings_model.dart';

void main() {
  runApp(const BlindRunnerApp());
}

class BlindRunnerApp extends StatelessWidget {
  const BlindRunnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsModel>(
          create: (_) => SettingsModel(),
        ),
        Provider<AudioFeedback>(
          create: (_) => AudioFeedback(),
        ),
        ChangeNotifierProvider<LineDetector>(
          create: (context) => LineDetector(
            audioFeedback: context.read<AudioFeedback>(),
            settings: context.read<SettingsModel>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Blind Runner App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const HomeScreen(),
          '/settings': (context) => const SettingsScreen(),
        },
      ),
    );
  }
}