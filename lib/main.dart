// lib_2/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'services/line_detector.dart';
import 'services/audio_feedback.dart';
import 'models/settings_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Force portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF121212),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize settings
  final settings = SettingsModel();
  await settings.loadFromPreferences();
  
  runApp(BlindRunnerApp(settings: settings));
}

class BlindRunnerApp extends StatelessWidget {
  final SettingsModel settings;
  
  const BlindRunnerApp({
    super.key,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsModel>.value(
          value: settings,
        ),
        Provider<AudioFeedback>(
          create: (_) => AudioFeedback(),
        ),
        ChangeNotifierProvider<LineDetector>(
          create: (context) => LineDetector(
            settings: context.read<SettingsModel>(),
            audioFeedback: context.read<AudioFeedback>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Blind Runner App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.dark(
            primary: Colors.blue[700]!,
            secondary: Colors.blue[500]!,
            surface: const Color(0xFF1E1E1E),
            background: const Color(0xFF121212),
          ),
          scaffoldBackgroundColor: const Color(0xFF121212),
          appBarTheme: const AppBarTheme(
            elevation: 0,
            backgroundColor: Color(0xFF121212),
            centerTitle: true,
            titleTextStyle: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              shadowColor: Colors.blue.withOpacity(0.5),
            ),
          ),
          cardTheme: CardTheme(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: const Color(0xFF1E1E1E),
          ),
          sliderTheme: SliderThemeData(
            activeTrackColor: Colors.blue[700],
            inactiveTrackColor: Colors.blue[700]?.withOpacity(0.3),
            thumbColor: Colors.blue[500],
            overlayColor: Colors.blue[500]?.withOpacity(0.3),
          ),
          switchTheme: SwitchThemeData(
            thumbColor: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return Colors.blue[500];
              }
              return Colors.grey[400];
            }),
            trackColor: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return Colors.blue[700];
              }
              return Colors.grey[700];
            }),
          ),
        ),
        themeMode: ThemeMode.dark,
        initialRoute: '/',
        routes: {
          '/': (context) => const HomeScreen(),
          '/settings': (context) => const SettingsScreen(),
        },
      ),
    );
  }
}