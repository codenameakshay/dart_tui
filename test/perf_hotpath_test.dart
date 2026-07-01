import 'dart:convert';
import 'dart:io';

import 'package:dart_tui/dart_tui.dart';
import 'package:dart_tui/src/renderer.dart';
import 'package:test/test.dart';

/// Buffer-backed IOSink mirroring test/renderer_test.dart: the renderers emit
/// strings via `write`/`writeln`, so capturing those into a StringBuffer gives
/// the full output. `add(List<int>)` is unused by the renderers.
class _StringSink implements IOSink {
  _StringSink(this._buf);
  final StringBuffer _buf;
  @override
  void write(Object? obj) => _buf.write(obj);
  @override
  void writeln([Object? obj = '']) => _buf.writeln(obj);
  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) =>
      _buf.writeAll(objects, separator);
  @override
  void writeCharCode(int charCode) => _buf.writeCharCode(charCode);
  @override
  Future<void> flush() async {}
  @override
  Future<void> close() async {}
  @override
  Future<void> get done async {}
  @override
  void add(List<int> data) {}
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future<void> addStream(Stream<List<int>> stream) async {}
  @override
  Encoding get encoding => utf8;
  @override
  set encoding(Encoding value) {}
}

void main() {
  group('style width/strip fast-path (Task 1)', () {
    test('stripAnsi is identity for strings with no escape', () {
      const plain = 'hello world — no escapes here';
      expect(stripAnsi(plain), plain);
    });

    test('stripAnsi still removes SGR sequences', () {
      expect(stripAnsi('\x1b[1;32mgreen\x1b[0m'), 'green');
    });

    test('getWidth matches for plain, ANSI, and double-width', () {
      expect(getWidth('abc'), 3);
      expect(getWidth('\x1b[31mabc\x1b[0m'), 3);
      expect(getWidth('你好'), 4); // two double-width CJK
      expect(getWidth('a你b'), 4);
    });

    test('truncate preserves ANSI and respects visible width', () {
      expect(truncate('abcdef', 3), 'abc');
      expect(truncate('\x1b[31mabcdef\x1b[0m', 3), '\x1b[31mabc');
      expect(truncate('你好世界', 4), '你好'); // 2 cols each
    });

    test('truncateLeft keeps the trailing columns', () {
      expect(truncateLeft('abcdef', 3), 'def');
      expect(truncateLeft('你好世界', 4), '世界');
    });
  });

  group('viewport wrap memoization (Task 2)', () {
    test('soft-wrap splits a long line to width', () {
      final vp = ViewportModel(
          content: 'aaaaaaaaaa', width: 4, height: 10, softWrap: true);
      expect(vp.totalLines, 3); // 4 + 4 + 2
    });

    test('scrolling preserves wrapped content and window', () {
      final content = List.generate(20, (i) => 'line$i').join('\n');
      final vp =
          ViewportModel(content: content, width: 80, height: 5, softWrap: true);
      final scrolled = vp.scrollBy(3);
      expect(scrolled.totalLines, 20);
      expect(scrolled.view().content.split('\n').first, 'line3');
      expect(scrolled.view().content.split('\n').length, 5);
    });

    test('setContent re-wraps', () {
      final vp = ViewportModel(content: 'a', width: 4, height: 10);
      final vp2 = vp.setContent('aaaaaaaa');
      expect(vp2.totalLines, 2);
    });
  });

  group('list filter memoization (Task 5)', () {
    test('filteredItems returns the identical cached list across calls', () {
      final m = ListModel(
        items: [
          ListItem(title: 'apple'),
          ListItem(title: 'banana'),
          ListItem(title: 'apricot'),
        ],
        filter: 'ap',
      );
      expect(identical(m.filteredItems, m.filteredItems), isTrue);
    });

    test('filtering results are unchanged', () {
      final m = ListModel(
        items: [
          ListItem(title: 'apple'),
          ListItem(title: 'banana'),
          ListItem(title: 'apricot'),
        ],
        filter: 'ap',
      );
      expect(m.filteredItems.map((i) => i.title), ['apple', 'apricot']);
    });
  });

  group('tree flatten reuse (Task 6)', () {
    TreeNode sample() => TreeNode(label: 'root', isExpanded: true, children: [
          TreeNode(label: 'a'),
          TreeNode(label: 'b', isExpanded: true, children: [
            TreeNode(label: 'b1'),
          ]),
        ]);

    test('cursor navigation preserves node count and structure', () {
      final t = TreeModel(root: sample());
      final before = t.nodeCount;
      final (moved, _) = t.update(KeyPressMsg(const TeaKey(code: KeyCode.down)));
      expect((moved as TreeModel).nodeCount, before);
      expect(moved.nodeCount, 4);
    });

    test('toggling collapse changes node count', () {
      final t = TreeModel(root: sample());
      final before = t.nodeCount; // root + a + b + b1 = 4
      var m = t;
      m = m.update(KeyPressMsg(const TeaKey(code: KeyCode.down))).$1 as TreeModel;
      m = m.update(KeyPressMsg(const TeaKey(code: KeyCode.down))).$1 as TreeModel;
      m = m.update(KeyPressMsg(const TeaKey(code: KeyCode.left))).$1 as TreeModel;
      expect(m.nodeCount, lessThan(before));
    });
  });

  rendererTests();
}

void rendererTests() {
  group('CellRenderer identical-frame guard (Task 3)', () {
    test('second identical render emits no new output', () {
      final buf = StringBuffer();
      final r = CellRenderer(
        output: _StringSink(buf),
        defaultAltScreen: false,
        defaultHideCursor: false,
      );
      r.render(View(content: 'hello\nworld'));
      final afterFirst = buf.length;
      r.render(View(content: 'hello\nworld'));
      expect(buf.length, afterFirst,
          reason: 'identical content must produce no additional bytes');
    });

    test('changed frame still emits', () {
      final buf = StringBuffer();
      final r = CellRenderer(
        output: _StringSink(buf),
        defaultAltScreen: false,
        defaultHideCursor: false,
      );
      r.render(View(content: 'hello'));
      final afterFirst = buf.length;
      r.render(View(content: 'jello'));
      expect(buf.length, greaterThan(afterFirst));
    });
  });

  group('AnsiRenderer identical-frame guard (Task 4)', () {
    test('second identical render emits no new output', () {
      final buf = StringBuffer();
      final r = AnsiRenderer(
        output: _StringSink(buf),
        defaultAltScreen: false,
        defaultHideCursor: false,
      );
      r.render(View(content: 'a\nb\nc'));
      final afterFirst = buf.length;
      r.render(View(content: 'a\nb\nc'));
      expect(buf.length, afterFirst);
    });

    test('changed line is re-emitted', () {
      final buf = StringBuffer();
      final r = AnsiRenderer(
        output: _StringSink(buf),
        defaultAltScreen: false,
        defaultHideCursor: false,
      );
      r.render(View(content: 'a\nb\nc'));
      final afterFirst = buf.length;
      r.render(View(content: 'a\nX\nc'));
      expect(buf.length, greaterThan(afterFirst));
    });
  });
}
