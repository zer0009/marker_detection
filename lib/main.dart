import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'app.dart';

void main() {
  runApp(const AppLoader());
}

class AppLoader extends StatelessWidget {
  const AppLoader({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: FutureBuilder<List<CameraDescription>>(
        future: _initializeApp(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingScreen();
          }

          if (snapshot.hasError) {
            return ErrorScreen(error: snapshot.error.toString());
          }

          final cameras = snapshot.data ?? [];
          return LineDetectionApp(cameras: cameras);
        },
      ),
    );
  }

  Future<List<CameraDescription>> _initializeApp() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      
      // Set preferred orientations
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);

      // Get available cameras
      final cameras = await availableCameras();
      return cameras;
    } catch (e) {
      debugPrint('Initialization error: $e');
      return [];
    }
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Initializing Camera...',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorScreen extends StatelessWidget {
  final String error;

  const ErrorScreen({Key? key, required this.error}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Initialization Error',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => SystemNavigator.pop(),
                child: const Text('Exit App'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}