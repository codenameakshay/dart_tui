// Inline (normal-screen) rendering, issue #18: frames start on the cursor's
// row and move only relative to their top row, so shell history above the
// frame is never painted over.
import 'dart:convert';
import 'dart:io';

import 'package:dart_tui/src/renderer.dart';
import 'package:dart_tui/src/view.dart';
import 'package:test/test.dart';

final _absoluteRow = RegExp(r'\x1b\[\d*;\d*H|\x1b\[H|\x1b\[\d+d');

void main() {
  for (final cell in [false, true]) {
    group('${cell ? 'CellRenderer' : 'AnsiRenderer'} inline', () {
      late StringBuffer buf;
      late TeaRenderer renderer;
      var lines = 0;
      var columns = 0;

      setUp(() {
        buf = StringBuffer();
        lines = 0;
        columns = 0;
        renderer = cell
            ? CellRenderer(
                output: _StringSink(buf),
                defaultAltScreen: false,
                defaultHideCursor: true,
                terminalColumns: () => columns,
                terminalLines: () => lines,
              )
            : AnsiRenderer(
                output: _StringSink(buf),
                defaultAltScreen: false,
                defaultHideCursor: true,
                terminalColumns: () => columns,
                terminalLines: () => lines,
              );
      });

      tearDown(() {
        // No step of an inline session may use an absolute row.
        expect(buf.toString(), isNot(contains(_absoluteRow)));
      });

      test('the first frame starts on the cursor row without a CPR query', () {
        renderer.render(newView('one\ntwo'));
        final out = buf.toString();
        expect(out, isNot(contains('\x1b[6n')));
        expect(out, isNot(contains('\x1b[2J')));
        // Row 0 is the current row; row 1 is created by a newline (the
        // CellRenderer clears both rows, then writes them).
        expect('\r\n'.allMatches(out).length, 1);
        expect(out, startsWith('\x1b[?25l\x1b[?2004h'));
        expect(out, contains(cell ? '\x1b[1Aone' : '\x1b[Kone'));
        expect(out, contains('two'));
      });

      test('a redraw rewrites only the changed line', () {
        renderer.render(newView('one\ntwo\nthree'));
        buf.clear();
        renderer.render(newView('one\nTWO\nthree'));
        final out = buf.toString();
        expect(out, contains('\x1b[1A'));
        expect(out, isNot(contains('one')));
        expect(out, isNot(contains('three')));
        expect(out, contains('\r\x1b[1ATWO'));
      });

      test('growing creates rows with newlines below the frame', () {
        renderer.render(newView('one'));
        buf.clear();
        renderer.render(newView('one\ntwo\nthree'));
        final out = buf.toString();
        expect('\r\n'.allMatches(out).length, 2);
        expect(out, contains('two'));
        expect(out, contains('three'));
      });

      test('shrinking erases the leftover rows once', () {
        renderer.render(newView('one\ntwo\nthree'));
        buf.clear();
        renderer.render(newView('one'));
        expect(buf.toString(), '\r\x1b[1A\x1b[J');
      });

      test('a frame taller than the terminal shows its last rows', () {
        lines = 2;
        renderer.render(newView('a\nb\nc\nd'));
        final out = buf.toString();
        expect(out, isNot(contains('a')));
        expect(out, isNot(contains('b')));
        expect(out, contains('c'));
        expect(out, contains('d'));
        expect('\r\n'.allMatches(out).length, 1);
        buf.clear();
        // Redraws keep the clipped frame on screen: no rows are added.
        renderer.render(newView('a\nb\nc\nD'));
        expect(buf.toString(), isNot(contains('\n')));
        expect(buf.toString(), contains('D'));
      });

      test('lines are truncated to the terminal width', () {
        columns = 4;
        renderer.render(newView('abcdefgh\n你好你好'));
        final out = buf.toString();
        expect(out, contains('abcd'));
        expect(out, isNot(contains('abcde')));
        expect(out, contains('你好'));
        expect(out, isNot(contains('你好你')));
      });

      test('the cursor is placed relative to the frame top', () {
        renderer.render(View(
          content: 'a\nb\nc',
          cursor: const Cursor(x: 3, y: 1),
        ));
        expect(buf.toString(), endsWith('\r\x1b[1A\x1b[4G'));
      });

      test('the cursor follows clipped rows', () {
        lines = 2;
        renderer.render(View(
          content: 'a\nb\nc',
          cursor: const Cursor(x: 0, y: 2),
        ));
        // Row 2 of the content is row 1 of the clipped frame.
        expect(buf.toString(), endsWith('c\x1b[1 q\r'));
      });

      test('insertAbove erases the frame, prints, then redraws below', () {
        renderer.render(newView('frame\nrow'));
        buf.clear();
        renderer.insertAbove('log 1\nlog 2');
        expect(buf.toString(), '\r\x1b[1A\x1b[J\rlog 1\r\nlog 2\r\n');
        buf.clear();
        renderer.render(newView('frame\nrow'));
        final out = buf.toString();
        expect(out, startsWith('\r\x1b[K'));
        expect(out, contains('frame'));
        expect(out, contains('row'));
      });

      test('exit parks on the last row; Program adds the newline', () {
        renderer.render(newView('a\nb\nc'));
        renderer.render(newView('A\nb\nc'));
        buf.clear();
        renderer.close();
        final out = buf.toString();
        expect(out, isNot(contains('\x1b[?1049l')));
        expect(out, endsWith('\r\x1b[2B'));
      });

      test('clearScreen erases only the frame', () {
        renderer.render(newView('a\nb'));
        buf.clear();
        renderer.clearScreen();
        expect(buf.toString(), '\r\x1b[1A\x1b[J');
        buf.clear();
        renderer.render(newView('a\nb'));
        expect(buf.toString(), startsWith('\r\x1b[K'));
        expect(buf.toString(), contains('a'));
      });

      test('returning from the alt screen redraws over the inline frame', () {
        renderer.render(newView('one\ntwo'));
        renderer.render(View(content: 'alt', altScreen: true));
        buf.clear();
        renderer.render(newView('one\nTWO\nthree'));
        final out = buf.toString();
        final leave = out.indexOf('\x1b[?1049l');
        expect(leave, greaterThanOrEqualTo(0));
        // The terminal restored the cursor to row 1 of the frame, so the
        // repaint moves up to the top row and adds only the one new row.
        final body = out.substring(out.indexOf('\r', leave));
        expect(body, startsWith('\r\x1b[1A'));
        expect('\r\n'.allMatches(body).length, 1);
        expect(body, contains('TWO'));
      });

      test('quitting in the alt screen steps below the inline frame', () {
        renderer.render(newView('one\ntwo'));
        renderer.setAltScreen(true);
        buf.clear();
        renderer.close();
        final out = buf.toString();
        final leave = out.indexOf('\x1b[?1049l');
        expect(leave, greaterThanOrEqualTo(0));
        expect(out.substring(leave), endsWith('\r\r\n'));
      });

      test('quitting in alt after a trailing newline adds no blank row', () {
        renderer.render(newView('one\n'));
        renderer.setAltScreen(true);
        buf.clear();
        renderer.close();
        expect(buf.toString(), endsWith(cell ? '\r\r\n' : '\r\x1b[1A\r\n'));
      });

      test('scrolling a full terminal discards the offscreen frame anchor', () {
        lines = 2;
        renderer.render(newView('a\nb'));
        renderer.scroll(2);
        buf.clear();
        renderer.render(newView('A\nB'));
        expect(buf.toString(), isNot(contains('\x1b[3A')));
      },
          skip:
              'Decision needed: frame-local scroll or reject/no-op inline scrolling.');

      test('frame styling is reset before an erase on the next frame', () {
        renderer.render(newView('\x1b[41mone'));
        renderer.clearScreen();
        final output = buf.toString();
        final text = output.indexOf('one');
        final clear = output.indexOf('\x1b[J', text);
        expect(clear, greaterThan(text));
        expect(output.substring(text, clear), contains('\x1b[0m'));
      });

      test('insertAbove closes background style before frame erasure', () {
        renderer.render(newView('one'));
        buf.clear();
        renderer.insertAbove('\x1b[41mlog');
        renderer.render(newView('two'));
        final output = buf.toString();
        final log = output.indexOf('log');
        final clear = output.indexOf('\x1b[K', log);
        expect(clear, greaterThan(log));
        expect(output.substring(log, clear), contains('\x1b[0m'));
      });

      test('reset release from alt screen erases only the saved inline frame',
          () {
        renderer.render(newView('one\ntwo'));
        renderer.setAltScreen(true);
        buf.clear();
        renderer.release(reset: true);
        final out = buf.toString();
        final leave = out.indexOf('\x1b[?1049l');
        expect(leave, greaterThanOrEqualTo(0));
        expect(out.substring(leave), isNot(contains(_absoluteRow)));
        expect(out, endsWith('\r\x1b[1A\x1b[J'));
      });

      test('release(reset) then restore draws a new frame at the cursor', () {
        renderer.render(newView('a\nb'));
        renderer.release(reset: true);
        buf.clear();
        renderer.restore(newView('a\nb'));
        // A new frame starts on the current row: one newline, no move above
        // it before row 0 is cleared.
        expect(buf.toString(), contains('\r\x1b[K'));
        expect(buf.toString().indexOf('\x1b[1A'),
            anyOf(-1, greaterThan(buf.toString().indexOf('\r\n'))));
        expect('\r\n'.allMatches(buf.toString()).length, 1);
      });
    });
  }

  test('alt-screen rendering still uses absolute rows', () {
    for (final cell in [false, true]) {
      final buf = StringBuffer();
      final renderer = cell
          ? CellRenderer(
              output: _StringSink(buf),
              defaultAltScreen: true,
              defaultHideCursor: true,
            )
          : AnsiRenderer(
              output: _StringSink(buf),
              defaultAltScreen: true,
              defaultHideCursor: true,
            );
      renderer.render(newView('one\ntwo'));
      expect(buf.toString(), contains('\x1b[1;1H'));
      buf.clear();
      // A pure alt-screen program keeps its exact bytes, including this clear.
      renderer.release(reset: true);
      expect(buf.toString(), endsWith('\x1b[?2004l\x1b[H\x1b[2J'));
    }
  });
}

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
