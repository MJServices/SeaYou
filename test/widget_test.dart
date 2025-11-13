import 'package:flutter_test/flutter_test.dart';
import 'package:seayou_app/main.dart';

void main() {
  testWidgets('App starts with splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SeaYouApp());

    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('Splash screen has status bar', (WidgetTester tester) async {
    await tester.pumpWidget(const SeaYouApp());

    expect(find.text('9:41'), findsOneWidget);
  });
}
