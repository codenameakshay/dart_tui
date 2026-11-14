// Run: dart test example/test
// Tests the notes CLI in example/cli_app/notes.dart: plain-mode prompts read
// from a fake stdin, and the output goes to CaptureSinks.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_tui/cli.dart';
import 'package:dart_tui/dart_tui.dart';
import 'package:dart_tui/testing.dart';
import 'package:test/test.dart';

import '../cli_app/notes.dart';

void main() {
  late String file;
  late CaptureSink out;
  late CaptureSink err;

  setUp(() {
    final profile = Style.defaultProfile;
    final darkBackground = Style.hasDarkBackground;
    Style.defaultProfile = ColorProfile.trueColor;
    Style.hasDarkBackground = true;
    addTearDown(() {
      Style.defaultProfile = profile;
      Style.hasDarkBackground = darkBackground;
    });
    final dir = Directory.systemTemp.createTempSync('notes_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    file = '${dir.path}/notes.json';
    out = CaptureSink();
    err = CaptureSink();
  });

  final stdin = StreamController<List<int>>.broadcast();
  tearDownAll(stdin.close);

  NotesRunner notes() => NotesRunner(
        logger: Logger(
          stdout: out,
          stderr: err,
          stdin: stdin.stream,
          environment: const {'ACCESSIBLE': '1'},
        ),
      );

  /// Types [line] once [question] is on screen.
  Future<void> answer(String question, String line) async {
    while (!out.text.contains(question)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    stdin.add(utf8.encode('$line\n'));
  }

  test('add asks for the text and priority, list and done use the file',
      () async {
    final added = notes().run(['add', '-f', file]);
    await answer('What should the note say?', 'Buy milk');
    await answer('Priority?', '3');
    expect(await added, 0);
    expect(out.text, contains('What should the note say?'));
    expect(out.text, contains('✓ Saved note 1'));

    await notes().run(['add', 'Call Sam', '-f', file]);
    await notes().run(['done', '1', '-f', file]);
    out.clear();
    await notes().run(['list', '-f', file]);
    expect(out.text, '2. [ ] Call Sam (normal)\n');
    out.clear();
    await notes().run(['ls', '--all', '-f', file]);
    expect(out.text, '1. [x] Buy milk (high)\n2. [ ] Call Sam (normal)\n');
  });

  test('done with a bad number is a usage error', () async {
    await expectLater(
        notes().run(['done', '7', '-f', file]), throwsA(isA<UsageException>()));
  });

  test('help groups the commands', () {
    final help = notes().usage;
    expect(help, contains('Read:\n  list'));
    expect(help, contains('Write:\n  add '));
  });
}
