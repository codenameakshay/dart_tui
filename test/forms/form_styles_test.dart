import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

void main() {
  test('form applies configured active title and error styles', () {
    const styles = FormStyles(
      activeTitle: Style(isBold: true),
      error: Style(isUnderline: true),
    );
    final form = Form([
      Group([
        Field.input(key: 'name', title: 'Name').withError('required'),
      ]),
    ], styles: styles);

    final output = form.view().content;
    expect(output, contains('\x1b[1mName\x1b[0m'));
    expect(output, contains('\x1b[4m✗ required\x1b[0m'));
  });
}
