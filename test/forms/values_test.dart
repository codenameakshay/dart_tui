import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

void main() {
  test('FormValues get/has/toMap', () {
    const v = FormValues({'name': 'ada', 'n': 3, 'ok': true});
    expect(v.get<String>('name'), 'ada');
    expect(v.get<int>('n'), 3);
    expect(v.get<String>('missing'), isNull);
    expect(v.has('ok'), isTrue);
    expect(v.has('missing'), isFalse);
    expect(() => v.toMap()['x'] = 1, throwsUnsupportedError);
  });

  test('Option holds label + typed value', () {
    const o = Option<int>('Three', 3);
    expect(o.label, 'Three');
    expect(o.value, 3);
  });
}
