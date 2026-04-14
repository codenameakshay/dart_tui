import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

void main() {
  group('ProgressModel', () {
    test('fraction 0 shows empty bar', () {
      final p = ProgressModel(fraction: 0, width: 10);
      final content = p.view().content;
      expect(content, contains('0%'));
      // No filled cells
      expect(content, isNot(contains('█')));
    });

    test('fraction 1 shows full bar', () {
      final p = ProgressModel(fraction: 1, width: 10);
      final content = p.view().content;
      expect(content, contains('100%'));
      expect(content, contains('█' * 10));
    });

    test('fraction 0.5 fills half the bar', () {
      final p = ProgressModel(fraction: 0.5, width: 10);
      final content = p.view().content;
      expect(content, contains('50%'));
      expect(content, contains('█' * 5));
      expect(content, contains('░' * 5));
    });

    test('label is included in view when set', () {
      final p = ProgressModel(fraction: 0.5, label: 'Loading');
      expect(p.view().content, contains('Loading'));
    });

    test('update returns self unchanged', () {
      final p = ProgressModel(fraction: 0.3);
      final (next, cmd) = p.update(TickMsg(DateTime.now()));
      expect(identical(p, next), isTrue);
      expect(cmd, isNull);
    });

    test('assert throws for fraction < 0', () {
      expect(() => ProgressModel(fraction: -0.1), throwsA(isA<AssertionError>()));
    });

    test('assert throws for fraction > 1', () {
      expect(() => ProgressModel(fraction: 1.1), throwsA(isA<AssertionError>()));
    });
  });
}
