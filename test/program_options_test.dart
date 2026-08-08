// Integration tests for Program ProgramOption functions.
//
// These tests run headless (no TTY): withInput(null) disables stdin,
// withOutput(sink) captures ANSI output.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Minimal model that quits immediately from init.
final class _ImmediateQuit extends Model {
  @override
  Cmd? init() => () => quit();

  @override
  (Model, Cmd?) update(Msg msg) => (this, null);

  @override
  View view() => newView('');
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('withAltScreen()', () {
    test('emits alt-screen enter sequence', () async {
      final chunks = <String>[];
      final controller = StreamController<List<int>>();
      controller.stream.listen((d) => chunks.add(utf8.decode(d)));
      final sink = IOSink(controller.sink);

      await Program(
        options: [
          withInput(null),
          withOutput(sink),
          withAltScreen(),
        ],
      ).run(_ImmediateQuit());

      await sink.flush();
      final out = chunks.join();
      await sink.close();
      await controller.close();

      // ?1049h = enter alt screen
      expect(out, contains('\x1b[?1049h'));
    });
  });

  group('withReportFocus()', () {
    test('emits focus-reporting enable sequence', () async {
      final chunks = <String>[];
      final controller = StreamController<List<int>>();
      controller.stream.listen((d) => chunks.add(utf8.decode(d)));
      final sink = IOSink(controller.sink);

      await Program(
        options: [
          withInput(null),
          withOutput(sink),
          withReportFocus(),
        ],
      ).run(_ImmediateQuit());

      await sink.flush();
      final out = chunks.join();
      await sink.close();
      await controller.close();

      // ?1004h = enable focus reporting
      expect(out, contains('\x1b[?1004h'));
    });
  });

  group('withMouseCellMotion()', () {
    test('emits cell-motion mouse enable sequence', () async {
      final chunks = <String>[];
      final controller = StreamController<List<int>>();
      controller.stream.listen((d) => chunks.add(utf8.decode(d)));
      final sink = IOSink(controller.sink);

      await Program(
        options: [
          withInput(null),
          withOutput(sink),
          withMouseCellMotion(),
        ],
      ).run(_ImmediateQuit());

      await sink.flush();
      final out = chunks.join();
      await sink.close();
      await controller.close();

      // ?1002h = button-event tracking; ?1006h = SGR extended coords
      expect(out, contains('\x1b[?1002h'));
      expect(out, contains('\x1b[?1006h'));
    });
  });

  group('withMouseAllMotion()', () {
    test('emits all-motion mouse enable sequence', () async {
      final chunks = <String>[];
      final controller = StreamController<List<int>>();
      controller.stream.listen((d) => chunks.add(utf8.decode(d)));
      final sink = IOSink(controller.sink);

      await Program(
        options: [
          withInput(null),
          withOutput(sink),
          withMouseAllMotion(),
        ],
      ).run(_ImmediateQuit());

      await sink.flush();
      final out = chunks.join();
      await sink.close();
      await controller.close();

      // ?1003h = any-event tracking
      expect(out, contains('\x1b[?1003h'));
      expect(out, contains('\x1b[?1006h'));
    });
  });

  group('withTickInterval()', () {
    test('program exits cleanly with tick interval enabled', () async {
      // If the tick mechanism crashes, the future will throw.
      await Program(
        options: [
          withInput(null),
          withTickInterval(const Duration(milliseconds: 5)),
        ],
      ).run(_ImmediateQuit());
    });
  });

  group('withHideCursor()', () {
    test('withHideCursor(false) does NOT emit hide-cursor sequence', () async {
      final chunks = <String>[];
      final controller = StreamController<List<int>>();
      controller.stream.listen((d) => chunks.add(utf8.decode(d)));
      final sink = IOSink(controller.sink);

      await Program(
        options: [
          withInput(null),
          withOutput(sink),
          withHideCursor(false),
        ],
      ).run(_ImmediateQuit());

      await sink.flush();
      final out = chunks.join();
      await sink.close();
      await controller.close();

      // ?25l = hide cursor — should NOT appear
      expect(out, isNot(contains('\x1b[?25l')));
    });
  });

  group('withWindowSize()', () {
    test('WindowSizeMsg has the injected dimensions', () async {
      int? receivedWidth;
      int? receivedHeight;

      final model = _WindowSizeCapture(
        onSize: (w, h) {
          receivedWidth = w;
          receivedHeight = h;
        },
      );

      await Program(
        options: [
          withInput(null),
          withWindowSize(120, 40),
        ],
      ).run(model);

      expect(receivedWidth, 120);
      expect(receivedHeight, 40);
    });
  });

  group('withLogFile()', () {
    test('writes rendered output to the selected file', () async {
      final directory = await Directory.systemTemp.createTemp('dart_tui_log_');
      addTearDown(() => directory.delete(recursive: true));
      final logFile = File('${directory.path}/program.log');

      await Program(
        options: [withInput(null), withLogFile(logFile)],
      ).run(_ImmediateQuit());

      expect(await logFile.readAsString(), isNotEmpty);
    });
  });
}

// ── Aux models ────────────────────────────────────────────────────────────────

final class _WindowSizeCapture extends Model {
  _WindowSizeCapture({required this.onSize});
  final void Function(int w, int h) onSize;
  bool _received = false;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is WindowSizeMsg && !_received) {
      _received = true;
      onSize(msg.width, msg.height);
      return (this, () => quit());
    }
    return (this, null);
  }

  @override
  View view() => newView('');
}
