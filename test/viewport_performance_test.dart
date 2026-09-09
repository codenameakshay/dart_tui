import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

void main() {
  test('scroll copies reuse the wrapped layout', () {
    final model = ViewportModel(
      content: List.generate(1000, (i) => 'line $i').join('\n'),
      width: 80,
      height: 20,
    );

    final scrolled = model.scrollBy(1);

    expect(scrolled.totalLines, model.totalLines);
    expect(scrolled.view().content.split('\n').first, 'line 1');
  });

  test('gutter callbacks are reevaluated for rebuilt scroll copies', () {
    var prefix = '';
    final model = ViewportModel(
      content: 'abcdefghij',
      width: 5,
      height: 1,
      gutterBuilder: (_) => prefix,
    );
    prefix = '1234';

    final rebuilt = model.scrollBy(1);
    expect(rebuilt.totalLines, greaterThan(model.totalLines));
  });

  test('changing highlight lines invalidates the per-line index', () {
    final model = ViewportModel(
      content: 'alpha\nbeta',
      width: 20,
      height: 2,
      softWrap: false,
    ).withHighlights([
      const ViewportHighlight(line: 0, start: 0, end: 1),
    ]);
    model.view();

    final changed = model.withHighlights([
      const ViewportHighlight(line: 1, start: 0, end: 1),
    ]);
    expect(changed.view().content, contains('\x1b[7m'));
  });
}
