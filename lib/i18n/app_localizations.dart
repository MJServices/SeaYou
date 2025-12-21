import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class AppLocalizations {
  final Locale locale;
  late final Map<String, dynamic> _map;

  AppLocalizations(this.locale);

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  Future<void> load() async {
    final data = await rootBundle.loadString('assets/i18n/${locale.languageCode}.json');
    _map = json.decode(data) as Map<String, dynamic>;
  }

  String tr(String key, {Map<String, String>? params}) {
    final parts = key.split('.');
    dynamic node = _map;
    for (final p in parts) {
      if (node is Map<String, dynamic> && node.containsKey(p)) {
        node = node[p];
      } else {
        node = key; // fallback to key if missing
        break;
      }
    }
    var s = node is String ? node : node.toString();
    if (params != null) {
      params.forEach((k, v) => s = s.replaceAll('{$k}', v));
    }
    return s;
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'fr', 'de', 'es'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final l = AppLocalizations(locale);
    await l.load();
    return l;
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}

