import 'dart:convert';
import 'dart:io';

void main() {
  final files = ['assets/i18n/en.json', 'assets/i18n/fr.json', 'assets/i18n/es.json', 'assets/i18n/de.json'];
  bool hasError = false;

  for (final path in files) {
    final file = File(path);
    if (!file.existsSync()) {
      print('❌ File not found: $path');
      continue;
    }

    try {
      final content = file.readAsStringSync();
      json.decode(content);
      print('✅ Valid JSON: $path');
    } catch (e) {
      print('❌ Invalid JSON in $path: $e');
      hasError = true;
    }
  }

  if (hasError) exit(1);
}
