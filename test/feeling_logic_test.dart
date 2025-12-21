import 'package:flutter_test/flutter_test.dart';
import 'package:seayou_app/utils/feeling_logic.dart';

void main() {
  test('Single sided messages do not advance', () {
    final fc = FeelingComputer();
    expect(fc.apply('A'), 0);
    expect(fc.apply('A'), 0);
    expect(fc.apply('A'), 0);
  });

  test('A then B advances by 10%', () {
    final fc = FeelingComputer();
    expect(fc.apply('A'), 0);
    expect(fc.apply('B'), 10);
  });

  test('Alternating pairs advance strictly in 10% steps', () {
    final fc = FeelingComputer();
    fc.apply('A');
    fc.apply('B');
    expect(fc.apply('A'), 10);
    expect(fc.apply('B'), 20);
    expect(fc.apply('A'), 20);
    expect(fc.apply('B'), 30);
  });
}
