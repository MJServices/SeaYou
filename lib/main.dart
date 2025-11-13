import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const SeaYouApp());
}

class SeaYouApp extends StatelessWidget {
  const SeaYouApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SeaYou',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF0AC5C5),
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Montserrat',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0AC5C5),
          primary: const Color(0xFF0AC5C5),
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
