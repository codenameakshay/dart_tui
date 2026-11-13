import 'dart:convert';
import 'dart:io';

import 'package:dart_tui/dart_tui.dart';
import 'package:dart_tui/src/input_decoder.dart';
import 'package:dart_tui/testing.dart';
import 'package:test/test.dart';

final class _Keys extends Model {
  final List<KeyPressMsg> keys = [];

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is KeyPressMsg) keys.add(msg);
    return (this, null);
  }

  @override
  View view() => newView('');
}

List<Msg> _decode(String bytes) {
  final decoder = TerminalInputDecoder();
  return [
    ...decoder.feed(utf8.encode(bytes)),
    ...decoder.takeLoneEscapeIfStillPending(),
  ];
}

void main() {
  setUp(() {
    final profile = Style.defaultProfile;
    final dark = Style.hasDarkBackground;
    Style.defaultProfile = ColorProfile.noColor;
    Style.hasDarkBackground = true;
    addTearDown(() {
      Style.defaultProfile = profile;
      Style.hasDarkBackground = dark;
    });
  });

  test('CaptureSink decodes UTF-8 split between add calls', () async {
    final sink = CaptureSink();
    sink.add([0xf0, 0x9f]);
    sink.add([0x91]);
    sink.add([0x8b]);
    await sink.flush();
    expect(sink.text, '👋');
  });

  test('CaptureSink decodes UTF-8 split between stream chunks', () async {
    final sink = CaptureSink();
    await sink.addStream(Stream.fromIterable([
      [0xc3],
      [0xa9, 0xf0, 0x9f],
      [0x91, 0x8b],
    ]));
    expect(sink.text, 'é👋');
  });

  test('CaptureSink respects encoding changes between byte writes', () async {
    final sink = CaptureSink()..add(utf8.encode('é'));
    sink.encoding = latin1;
    sink.add([0xe9]);
    await sink.close();
    expect(sink.text, 'éé');
  });

  test('keyPressFor preserves decoder event fields for terminal encodings', () {
    final cases = {
      'A': 'A',
      'é': 'é',
      '👋': '👋',
      'f3': '\x1bOR',
      'f12': '\x1b[24~',
      'shift+tab': '\x1b[Z',
      'ctrl+alt+right': '\x1b[1;7C',
      'super+a': '\x1b[97;9u',
      'ctrl+enter': '\x1b[13;5u',
      'alt+backspace': '\x1b\x7f',
      'ctrl+space': '\x00',
      '+': '+',
      'ctrl++': '\x1b[43;5u',
    };
    for (final entry in cases.entries) {
      final actual = keyPressFor(entry.key).keyEvent;
      final expected = (_decode(entry.value).single as KeyPressMsg).keyEvent;
      expect(actual.code, expected.code, reason: entry.key);
      expect(actual.text, expected.text, reason: entry.key);
      expect(actual.modifiers, expected.modifiers, reason: entry.key);
      expect(actual.isRepeat, expected.isRepeat, reason: entry.key);
    }
  });

  test('type emits one key per scalar including combining marks and controls',
      () async {
    final model = _Keys();
    final t = TuiTester(model);
    addTearDown(t.dispose);
    await t.type('e\u0301👩\u200d💻 \n\t\x1b\u009b');
    expect(model.keys.map((key) => key.key).toList(), [
      'e',
      '\u0301',
      '👩',
      '\u200d',
      '💻',
      'space',
      'enter',
      'tab',
      'esc',
      '\u009b'
    ]);
  });

  test('golden update round-trips empty and trailing-newline screens', () {
    final dir = Directory.systemTemp.createTempSync('tui_parity');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/screen.txt';
    for (final actual in ['', 'one', 'one\n', 'one\n\n']) {
      expectScreen(actual, path, update: true);
      expect(File(path).readAsStringSync(), '$actual\n');
      expectScreen(actual, path, update: false);
      File(path).writeAsStringSync('$actual\n'.replaceAll('\n', '\r\n'));
      expectScreen(actual, path, update: false);
    }
  });
}
