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

  rendererTests();
}

void rendererTests() {}
