
import 'dart:convert';
import 'dart:io';

void main() {
  final frData = File('e:/seayou_app/assets/i18n/fr.json').readAsStringSync();
  final Map<String, dynamic> frMap = json.decode(frData);

  final enData = File('e:/seayou_app/assets/i18n/en.json').readAsStringSync();
  final Map<String, dynamic> enMap = json.decode(enData);

  String tr(Map<String, dynamic> map, String key) {
    final parts = key.split('.');
    dynamic node = map;
    for (final p in parts) {
      if (node is Map<String, dynamic> && node.containsKey(p)) {
        node = node[p];
      } else {
        return key;
      }
    }
    return node.toString();
  }

  print('Testing Sexual Orientation (French):');
  print('heterosexual -> ${tr(frMap, "onboarding.sexual_orientation.options.heterosexual")}');
  print('gay -> ${tr(frMap, "onboarding.sexual_orientation.options.gay")}');
  print('lesbian -> ${tr(frMap, "onboarding.sexual_orientation.options.lesbian")}');

  print('\nTesting Interests (French):');
  print('photography -> ${tr(frMap, "onboarding.interests.options.photography")}');
  print('nature -> ${tr(frMap, "onboarding.interests.options.nature")}');
  
  // Test the slug logic
  String getSlug(String interest) {
    return interest.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
  }

  final testInterests = ['Photography', 'Nature', 'Netflix & chill', 'Geek/Pop culture'];
  for (final interest in testInterests) {
    final slug = getSlug(interest);
    final key = "onboarding.interests.options.$slug";
    print('Interest: "$interest" -> Slug: "$slug" -> French: ${tr(frMap, key)}');
  }
}
