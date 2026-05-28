import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seayou_app/widgets/feeling_progress.dart';

void main() {
  testWidgets('FeelingProgress shows milestones semantics at thresholds',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: FeelingProgress(percent: 25, compact: true)),
    ));

    expect(find.bySemanticsLabel('25% - Quote Unlocked'), findsOneWidget);
    expect(find.bySemanticsLabel('50% - Voice Message Unlocked'), findsOneWidget);
    expect(find.bySemanticsLabel('75% - Intimate Question Unlocked'), findsOneWidget);
    expect(find.bySemanticsLabel('100% - Photo Reveal Available'), findsOneWidget);

    // Update percent
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: FeelingProgress(percent: 80, compact: true)),
    ));
    expect(find.bySemanticsLabel('25% - Quote Unlocked'), findsOneWidget);
    expect(find.bySemanticsLabel('50% - Voice Message Unlocked'), findsOneWidget);
    expect(find.bySemanticsLabel('75% - Intimate Question Unlocked'), findsOneWidget);
    expect(find.bySemanticsLabel('100% - Photo Reveal Available'), findsOneWidget);
  });
}
