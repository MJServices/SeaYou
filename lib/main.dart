import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/audio_service.dart';
import 'services/iap_service.dart';
import 'services/localization_service.dart';
import 'i18n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'screens/create_password_screen.dart';
// import 'widgets/tap_to_mute_wrapper.dart'; // Removed as only used locally in splash
import 'screens/home_screen.dart';
import 'services/presence_service.dart';

final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  await GlobalAudioController.instance.init();
  await LocalizationService.instance.init();
  await IapService().initialize();
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
  Widget initialScreen = const SplashScreen();
  final session = Supabase.instance.client.auth.currentSession;
  
  if (session != null) {
    PresenceService.instance.init();
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', session.user.id)
          .maybeSingle();

      if (profile != null) {
        bool isFieldEmpty(dynamic value) {
          if (value == null) return true;
          if (value is String) return value.trim().isEmpty;
          if (value is List) return value.isEmpty;
          return false;
        }

        final isComplete = !isFieldEmpty(profile['full_name']) &&
            !isFieldEmpty(profile['gender']) &&
            !isFieldEmpty(profile['sexual_orientation']) &&
            !isFieldEmpty(profile['expectation']) &&
            !isFieldEmpty(profile['interests']) &&
            !isFieldEmpty(profile['avatar_url']);

        if (isComplete) {
          initialScreen = const HomeScreen();
        }
      }
    } catch (_) {}
  }

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
        navigatorObservers: [routeObserver],
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
