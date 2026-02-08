import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/audio_service.dart';
import 'services/localization_service.dart';
import 'i18n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'screens/create_password_screen.dart';
// import 'widgets/tap_to_mute_wrapper.dart'; // Removed as only used locally in splash
import 'screens/home_screen.dart'; // Uncomment to skip onboarding for development

final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  await GlobalAudioController.instance.init();
  await LocalizationService.instance.init();
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.passwordRecovery) {
      final email = data.session?.user.email ?? '';
      navKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => CreatePasswordScreen(
            email: email,
            selectedLanguage:
                LocalizationService.instance.locale.value.languageCode,
            isRecovery: true,
          ),
        ),
      );
    }
  });
  // Check for active session
  final session = Supabase.instance.client.auth.currentSession;
  final Widget initialScreen = session != null ? const HomeScreen() : const SplashScreen();

  runApp(SeaYouApp(home: initialScreen));
}

class SeaYouApp extends StatelessWidget {
  final Widget home;
  
  const SeaYouApp({
    super.key,
    required this.home,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: LocalizationService.instance.locale,
      builder: (context, locale, _) => MaterialApp(
        title: 'SeaYou',
        navigatorKey: navKey,
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
        locale: locale,
        supportedLocales: const [
          Locale('en'),
          Locale('fr'),
          Locale('de'),
          Locale('es')
        ],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => child ?? const SizedBox(),
        home: home,
      ),
    );
  }
}
