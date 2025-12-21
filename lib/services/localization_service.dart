import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationService {
  LocalizationService._();
  static final LocalizationService instance = LocalizationService._();

  final ValueNotifier<Locale> locale = ValueNotifier<Locale>(const Locale('en'));

  static const _prefKey = 'preferred_locale';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null && ['en', 'fr', 'de', 'es'].contains(saved)) {
      locale.value = Locale(saved);
    } else {
      final system = WidgetsBinding.instance.platformDispatcher.locale;
      final lang = system.languageCode;
      locale.value = ['en', 'fr', 'de', 'es'].contains(lang) ? Locale(lang) : const Locale('en');
    }
  }

  Future<void> setLocale(Locale l) async {
    locale.value = l;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, l.languageCode);
  }
}

