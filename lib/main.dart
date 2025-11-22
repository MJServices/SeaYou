import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
// import 'screens/home_screen.dart'; // Uncomment to skip onboarding for development

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://nenugkyvcewatuddrwvf.supabase.co',
    anonKey: 'sb_publishable_FJpEIk5UxIj73h-qrs99fA_1dlJO0LT',
  );

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
      // Onboarding enabled - starts with splash screen
      home: const SplashScreen(),
      // home: const HomeScreen(), // Uncomment to skip onboarding for development
    );
  }
}
