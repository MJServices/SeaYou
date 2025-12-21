import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seayou_app/widgets/feeling_progress.dart';

void main() {
  testWidgets('FeelingProgress shows milestones semantics at thresholds',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: FeelingProgress(percent: 25, compact: true)),
    ));

    expect(find.bySemanticsLabel('Jalon 25% (citation)'), findsOneWidget);
    expect(find.bySemanticsLabel('Jalon 50% (voix)'), findsOneWidget);
    expect(find.bySemanticsLabel('Jalon 75% (surprise)'), findsOneWidget);
    expect(find.bySemanticsLabel('Jalon 100% (photo finale)'), findsOneWidget);

    // Update percent
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: FeelingProgress(percent: 80, compact: true)),
    ));
    expect(find.bySemanticsLabel('Jalon 25% (citation)'), findsOneWidget);
    expect(find.bySemanticsLabel('Jalon 50% (voix)'), findsOneWidget);
    expect(find.bySemanticsLabel('Jalon 75% (surprise)'), findsOneWidget);
    expect(find.bySemanticsLabel('Jalon 100% (photo finale)'), findsOneWidget);
  });
}
