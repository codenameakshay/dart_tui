import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

void main() {
  test('FormStyles.defaults renders each slot without throwing', () {
    const s = FormStyles.defaults;
    for (final st in [
      s.title,
      s.activeTitle,
      s.description,
      s.error,
      s.cursor,
      s.option,
      s.selectedOption,
      s.checkedBox,
      s.uncheckedBox,
      s.help,
      s.pageIndicator,
    ]) {
      expect(stripAnsi(st.render('x')), 'x');
    }
  });
}
