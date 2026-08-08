import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

void main() {
  group('ViewportModel', () {
    final content = List.generate(20, (i) => 'line $i').join('\n');

    test('starts at top', () {
      final vp = ViewportModel(content: content, height: 5);
      expect(vp.atTop, isTrue);
      expect(vp.yOffset, 0);
    });

    test('scrollBy clamps at bottom', () {
      final vp = ViewportModel(content: content, height: 5);
      final scrolled = vp.scrollBy(100);
      expect(scrolled.yOffset, 15); // 20 - 5
    });

    test('atBottom is true when at end', () {
      final vp = ViewportModel(content: content, height: 5).scrollBy(100);
      expect(vp.atBottom, isTrue);
    });

    test('scrollPercent is 0 at top, 1 at bottom', () {
      final vp = ViewportModel(content: content, height: 5);
      expect(vp.scrollPercent, 0.0);
      expect(vp.scrollBy(100).scrollPercent, 1.0);
    });

    test('setContent resets offset', () {
      final vp = ViewportModel(content: content, height: 5).scrollBy(5);
      final reset = vp.setContent('new content');
      expect(reset.yOffset, 0);
    });

    test('totalLines returns correct count', () {
      final vp = ViewportModel(content: content, height: 5);
      expect(vp.totalLines, 20);
    });

    test('gutter receives logical line and soft-wrap continuation context', () {
      final contexts = <ViewportGutterContext>[];
      final vp = ViewportModel(
        content: 'abcdef',
        width: 5,
        height: 2,
        gutterBuilder: (context) {
          contexts.add(context);
          return context.isSoftWrap ? '  ' : '${context.index + 1} ';
        },
      );

      expect(vp.view().content, '1 abc\n  def');
      expect(
          contexts,
          contains(const ViewportGutterContext(
            index: 0,
            totalLines: 1,
            isSoftWrap: true,
          )));
    });

    test('fillHeight pads the viewport to exactly its visible height', () {
      final vp = ViewportModel(
        content: 'only',
        width: 10,
        height: 3,
        fillHeight: true,
      );

      expect(vp.view().content.split('\n'), ['only', '', '']);
    });

    test('lineStyleBuilder styles each logical line before rendering', () {
      final vp = ViewportModel(
        content: 'zero\none',
        width: 10,
        height: 2,
        lineStyleBuilder: (index) => Style(isBold: index == 1),
      );

      expect(vp.view().content, contains('\x1b[1mone'));
    });

    test('line style is restored after a highlighted span', () {
      final vp = ViewportModel(
        content: 'pre hit post',
        width: 20,
        height: 1,
        lineStyleBuilder: (_) => const Style(isBold: true),
        selectedHighlightStyle: const Style(isReverse: true),
      ).withSearch('hit');

      final output = vp.view().content;
      expect(output, contains('\x1b[1m'));
      expect(output, contains('\x1b[7mhit'));
      expect(output, contains('\x1b[0m\x1b[1m post'));
    });

    test('literal search highlights matches and respects case sensitivity', () {
      final vp = ViewportModel(
        content: 'Match here\nmatch there',
        width: 20,
        height: 2,
        softWrap: false,
        highlightStyle: const Style(isUnderline: true),
        selectedHighlightStyle: const Style(isReverse: true),
      ).withSearch('match');

      expect(vp.highlights, hasLength(2));
      expect(vp.selectedHighlightIndex, 0);
      expect(vp.view().content, contains('\x1b[7mMatch'));
      expect(vp.view().content, contains('\x1b[4mmatch'));
      expect(
          vp.withSearch('match', caseSensitive: true).highlights, hasLength(1));
      expect(vp.withSearch('').highlights, isEmpty);
    });

    test('highlight navigation wraps and makes the selected line visible', () {
      final vp = ViewportModel(
        content: 'match zero\none\nmatch two',
        width: 10,
        height: 1,
        softWrap: false,
      ).withSearch('match');

      final next = vp.highlightNext();
      expect(next.selectedHighlightIndex, 1);
      expect(next.yOffset, 2);
      expect(next.highlightNext().selectedHighlightIndex, 0);
      expect(next.highlightNext().yOffset, 0);

      final previous = vp.highlightPrevious();
      expect(previous.selectedHighlightIndex, 1);
      expect(previous.yOffset, 2);
      expect(previous.clearHighlights().highlights, isEmpty);
    });

    test('selected highlight is made visible horizontally', () {
      final vp = ViewportModel(
        content: '0123456789match',
        width: 5,
        height: 1,
        softWrap: false,
      ).withSearch('match');

      expect(vp.xOffset, 10);
      expect(stripAnsi(vp.view().content), 'match');
    });

    test('search ranges count emoji sequences as one grapheme', () {
      final vp = ViewportModel(
        content: 'A❤️B ❤️',
        width: 20,
        height: 1,
      ).withSearch('❤️');

      expect(vp.highlights, hasLength(2));
      expect((vp.highlights.first.start, vp.highlights.first.end), (1, 2));
      expect((vp.highlights.last.start, vp.highlights.last.end), (4, 5));
    });

    test('stale explicit highlight ranges are safe no-ops', () {
      final vp = ViewportModel(content: 'short').withHighlights([
        const ViewportHighlight(line: 0, start: 2, end: 20),
      ]);

      expect(vp.highlights, isEmpty);
      expect(vp.view().content, 'short');
    });

    test('horizontal wheel buttons scroll unwrapped content by cells', () {
      final vp = ViewportModel(
        content: 'abcdefghij',
        width: 5,
        height: 1,
        softWrap: false,
      );

      final (rightModel, _) = vp.update(MouseWheelMsg(const Mouse(
        x: 0,
        y: 0,
        button: MouseButton.wheelRight,
      )));
      final right = rightModel as ViewportModel;
      expect(right.xOffset, 5);
      expect(right.view().content, 'fghij');

      final (leftModel, _) = right.update(MouseWheelMsg(const Mouse(
        x: 0,
        y: 0,
        button: MouseButton.wheelLeft,
      )));
      expect((leftModel as ViewportModel).xOffset, 0);
    });

    test('gutter remains fixed during horizontal scrolling', () {
      final vp = ViewportModel(
        content: 'abcdefghij',
        width: 7,
        height: 1,
        softWrap: false,
        gutterBuilder: (_) => '1 ',
      ).scrollRight(100);

      expect(vp.view().content, '1 fghij');
    });
  });
}
