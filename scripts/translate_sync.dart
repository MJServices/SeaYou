import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

// Configuration
const String sourceLanguage = 'en';
const List<String> targetLanguages = ['fr', 'de', 'es'];
const String i18nPath = 'assets/i18n';

void main(List<String> args) async {
  print('🚀 Starting Translation Sync Tool...');

  // 1. Get API Key from environment or .env
  String? apiKey;
  final envFile = File('.env');
  if (await envFile.exists()) {
    final lines = await envFile.readAsLines();
    for (var line in lines) {
      if (line.trim().startsWith('GOOGLE_TRANSLATE_API_KEY=')) {
        apiKey = line.split('=')[1].trim();
        // Remove quotes if present
        if (apiKey.startsWith('"') && apiKey.endsWith('"')) {
          apiKey = apiKey.substring(1, apiKey.length - 1);
        } else if (apiKey.startsWith("'") && apiKey.endsWith("'")) {
          apiKey = apiKey.substring(1, apiKey.length - 1);
        }
      }
    }
  }

  if (apiKey == null || apiKey.isEmpty) {
    print('❌ Error: GOOGLE_TRANSLATE_API_KEY not found in .env');
    print('Please add GOOGLE_TRANSLATE_API_KEY=your_key to your .env file.');
    exit(1);
  }

  // 2. Load Source (en.json)
  final sourceFile = File('$i18nPath/$sourceLanguage.json');
  if (!await sourceFile.exists()) {
    print('❌ Error: Source file $sourceLanguage.json not found at $i18nPath');
    exit(1);
  }

  final Map<String, dynamic> sourceData = json.decode(await sourceFile.readAsString());

  // 3. Process each target language
  for (var lang in targetLanguages) {
    print('\n🌐 Processing language: [$lang]');
    final targetFile = File('$i18nPath/$lang.json');
    Map<String, dynamic> targetData = {};
    if (await targetFile.exists()) {
      try {
        targetData = json.decode(await targetFile.readAsString());
      } catch (e) {
        print('   ⚠️ Warning: Could not parse existing $lang.json, starting fresh.');
      }
    }

    bool changed = await syncData(sourceData, targetData, lang, apiKey);

    if (changed) {
      // Sort keys for consistency
      const encoder = JsonEncoder.withIndent('  ');
      await targetFile.writeAsString(encoder.convert(sortMap(targetData)));
      print('   ✅ Saved $lang.json');
    } else {
      print('   ℹ️ No changes needed for $lang.json');
    }
  }
  
  print('\n✨ Translation Sync Complete!');
}

Future<bool> syncData(Map<String, dynamic> source, Map<String, dynamic> target, String lang, String apiKey) async {
  bool changed = false;

  for (var key in source.keys) {
    var val = source[key];
    if (val is Map<String, dynamic>) {
      if (!target.containsKey(key) || target[key] is! Map<String, dynamic>) {
        target[key] = <String, dynamic>{};
        changed = true;
      }
      if (await syncData(val, target[key], lang, apiKey)) {
        changed = true;
      }
    } else if (val is String) {
      // Translate if missing or empty
      if (!target.containsKey(key) || target[key] == null || target[key].toString().isEmpty) {
        print('   ✨ Translating [$key]...');
        String translated = await translateText(val, lang, apiKey);
        target[key] = translated;
        changed = true;
      }
    }
  }

  return changed;
}

Future<String> translateText(String text, String targetLang, String apiKey) async {
  if (text.isEmpty) return '';

  // Preserve placeholders like {count} or {{userName}}
  final regex = RegExp(r'\{[^\}]+\}|\{\{[^\}]+\}\}');
  final matches = regex.allMatches(text).toList();
  
  if (matches.isEmpty) {
    return await _callGoogleTranslate(text, targetLang, apiKey);
  }

  String workingText = text;
  Map<String, String> replacements = {};
  for (int i = 0; i < matches.length; i++) {
    String placeholder = matches[i].group(0)!;
    String id = '___${i}___'; // Using a very distinct pattern
    replacements[id] = placeholder;
    workingText = workingText.replaceFirst(placeholder, id);
  }

  String translated = await _callGoogleTranslate(workingText, targetLang, apiKey);
  
  // Put placeholders back
  replacements.forEach((id, original) {
    // Escape for regex or just use replaceAll if simple
    translated = translated.replaceAll(id, original);
    // Google might have added spaces or changed case
    translated = translated.replaceAll(id.toLowerCase(), original);
    translated = translated.replaceAll(' $id ', ' $original ');
  });
  
  return translated;
}

Future<String> _callGoogleTranslate(String text, String targetLang, String apiKey) async {
  final url = 'https://translation.googleapis.com/language/translate/v2?key=$apiKey';
  try {
    final response = await http.post(
      Uri.parse(url),
      body: {
        'q': text,
        'target': targetLang,
        'source': sourceLanguage,
        'format': 'text',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data']['translations'][0]['translatedText'];
    } else {
      print('      ❌ API Error: ${response.body}');
      return '[[FIXME]] $text';
    }
  } catch (e) {
    print('      ❌ Network Error: $e');
    return '[[FIXME]] $text';
  }
}

Map<String, dynamic> sortMap(Map<String, dynamic> map) {
  final sortedKeys = map.keys.toList()..sort();
  final result = <String, dynamic>{};
  for (var key in sortedKeys) {
    var val = map[key];
    if (val is Map<String, dynamic>) {
      result[key] = sortMap(val);
    } else {
      result[key] = val;
    }
  }
  return result;
}
