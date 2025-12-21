import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/audio_service.dart';
import 'services/localization_service.dart';
import 'i18n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'screens/create_password_screen.dart';
// import 'screens/home_screen.dart'; // Uncomment to skip onboarding for development

final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://nenugkyvcewatuddrwvf.supabase.co',
    anonKey: 'sb_publishable_FJpEIk5UxIj73h-qrs99fA_1dlJO0LT',
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
  runApp(const SeaYouApp());
}

class SeaYouApp extends StatelessWidget {
  const SeaYouApp({super.key});

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
        home: const SplashScreen(),
      ),
    );
  }
}
