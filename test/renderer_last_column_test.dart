import 'dart:convert';
import 'dart:io';

import 'package:dart_tui/src/renderer.dart';
import 'package:dart_tui/src/view.dart';
import 'package:test/test.dart';

/// Minimal [IOSink] that captures everything written into a [StringBuffer].
class _CaptureSink implements IOSink {
  _CaptureSink(this._buf);
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

/// Erase-to-end-of-line (EL). Emitted after a full-width line, it lands on the
/// pending-wrap last column and wipes the just-painted cell — issue #7.
const _el = '\x1b[K';

AnsiRenderer _renderer(StringBuffer buf) => AnsiRenderer(
      output: _CaptureSink(buf),
      defaultAltScreen: false,
      defaultHideCursor: false,
    );

void main() {
  group('AnsiRenderer last-column handling (issue #7)', () {
    test(
        'does not erase-to-end-of-line when the redrawn line is the same '
        'width (erasing would wipe the last column of a full-width line)', () {
      final buf = StringBuffer();
      final r = _renderer(buf);
      r.render(newView('aaaaa'));
      buf.clear();
      r.render(newView('bbbbb')); // same visible width, changed content
      expect(buf.toString(), isNot(contains(_el)));
    });

    test('does not erase-to-end-of-line when the redrawn line is wider', () {
      final buf = StringBuffer();
      final r = _renderer(buf);
      r.render(newView('aa'));
      buf.clear();
      r.render(newView('bbbbb')); // wider: fully overwrites the old cells
      expect(buf.toString(), isNot(contains(_el)));
    });

    test(
        'erases-to-end-of-line when the redrawn line is narrower '
        '(stale cells from the previous frame must be cleared)', () {
      final buf = StringBuffer();
      final r = _renderer(buf);
      r.render(newView('aaaaa'));
      buf.clear();
      r.render(newView('bb')); // narrower: columns 2..4 still hold old glyphs
      expect(buf.toString(), contains(_el));
    });

    test('compares visible width, ignoring SGR escape sequences', () {
      final buf = StringBuffer();
      final r = _renderer(buf);
      // prev renders 5 visible cells, but the raw string is long (color codes).
      r.render(newView('\x1b[41mAAAAA\x1b[0m'));
      buf.clear();
      // next is 8 visible cells (wider) → no stale cells → no erase.
      // A naive string-length compare (8 < 14) would wrongly erase here.
      r.render(newView('BBBBBBBB'));
      expect(buf.toString(), isNot(contains(_el)));
    });
  });
}
