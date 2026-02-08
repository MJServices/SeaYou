import 'package:flutter_test/flutter_test.dart';
import 'package:seayou_app/main.dart';
import 'package:seayou_app/screens/splash_screen.dart';

void main() {
  testWidgets('App starts with splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SeaYouApp(home: SplashScreen()));

    expect(find.text("S'inscrire gratuitement"), findsOneWidget);
  });

  testWidgets('Splash screen has status bar', (WidgetTester tester) async {
    await tester.pumpWidget(const SeaYouApp(home: SplashScreen()));

    expect(find.text('9:41'), findsOneWidget);
  });
}
