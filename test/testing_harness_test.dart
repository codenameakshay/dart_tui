import 'dart:io';

import 'package:dart_tui/dart_tui.dart';
import 'package:dart_tui/src/input_decoder.dart';
import 'package:dart_tui/testing.dart';
import 'package:test/test.dart';

/// Records every message it gets (except startup noise) and shows them.
final class _Log extends Model {
  _Log([this.seen = const []]);
  final List<String> seen;

  @override
  (Model, Cmd?) update(Msg msg) => switch (msg) {
        KeyPressMsg() => (_Log([...seen, 'key:${msg.key}']), null),
        PasteMsg() => (_Log([...seen, 'paste:${msg.content}']), null),
        PasteStartMsg() => (_Log([...seen, 'paste-start']), null),
        PasteEndMsg() => (_Log([...seen, 'paste-end']), null),
        WindowSizeMsg() => (
            _Log([...seen, 'size:${msg.width}x${msg.height}']),
            null
          ),
        _ => (this, null),
      };

  @override
  View view() => newView(seen.join('\n'));
}

final class _Boom extends Model {
  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is KeyPressMsg && msg.key == 'x') throw StateError('boom');
    return (this, null);
  }

  @override
  View view() => newView('ok');
}

/// Colours its text, so the pinned profile shows in styledScreen.
final class _Styled extends Model {
  @override
  (Model, Cmd?) update(Msg msg) => (this, null);
  @override
  View view() =>
      newView(const Style(foregroundRgb: RgbColor(255, 0, 0)).render('red   '));
}

final class _Pick extends Model implements OutcomeModel<String> {
  _Pick([this.outcome]);
  @override
  final String? outcome;
  @override
  (Model, Cmd?) update(Msg msg) => msg is KeyPressMsg && msg.key == 'enter'
      ? (_Pick('picked'), null)
      : (this, null);
  @override
  View view() => newView(outcome ?? 'choose');
}

/// Counts ticks, to test a timer with waitFor.
final class _Ticks extends Model {
  _Ticks([this.n = 0]);
  final int n;
  @override
  (Model, Cmd?) update(Msg msg) =>
      msg is TickMsg ? (_Ticks(n + 1), null) : (this, null);
  @override
  View view() => newView('ticks: $n');
}

void main() {
  test('press, type and paste reach update in order', () async {
    final t = TuiTester(_Log(), width: 40, height: 10);
    addTearDown(t.dispose);
    await t.press('enter');
    await t.press('ctrl+c');
    await t.press('shift+tab');
    await t.type('hé 👋');
    await t.paste('a b');
    await t.resize(100, 30);
    expect(t.screen.split('\n'), [
      'size:40x10',
      'key:enter',
      'key:ctrl+c',
      'key:shift+tab',
      'key:h',
      'key:é',
      'key:space',
      'key:👋',
      'paste-start',
      'paste:a b',
      'paste-end',
      'size:100x30',
    ]);
  });

  test('press builds the KeyPressMsg the decoder builds', () {
    final cases = {
      'enter': [0x0d],
      'esc': [0x1b],
      'ctrl+c': [0x03],
      'shift+tab': '\x1b[Z'.codeUnits,
      'up': '\x1b[A'.codeUnits,
      'ctrl+up': '\x1b[1;5A'.codeUnits,
      'alt+left': '\x1bb'.codeUnits,
      'pgdown': '\x1b[6~'.codeUnits,
      'backspace': [0x7f],
      'space': [0x20],
      'a': [0x61],
    };
    for (final MapEntry(key: name, value: bytes) in cases.entries) {
      final decoder = TerminalInputDecoder();
      final real = [
        ...decoder.feed(bytes),
        ...decoder.takeLoneEscapeIfStillPending(),
      ].single as KeyPressMsg;
      final built = keyPressFor(name);
      expect(built.key, name);
      expect(built.keyEvent.code, real.keyEvent.code, reason: name);
      expect(built.keyEvent.text, real.keyEvent.text, reason: name);
      expect(built.keyEvent.modifiers, real.keyEvent.modifiers, reason: name);
    }
    for (final name in [
      'f1',
      'f5',
      'f12',
      'delete',
      'insert',
      'home',
      'ctrl+alt+right',
      'shift+f1',
      'alt+a',
      'ctrl+space',
      'ctrl+enter',
      '+',
    ]) {
      expect(keyPressFor(name).key, name);
    }
    expect(() => keyPressFor('nope+a'), throwsArgumentError);
    expect(() => keyPressFor('bogus'), throwsArgumentError);
    // CSI 1;2R is also a cursor position report, so the decoder cannot
    // read shift+f3.
    expect(() => keyPressFor('shift+f3'), throwsArgumentError);
  });

  test('waitFor returns the screen, or times out with it in the error',
      () async {
    final t = TuiTester(_Log());
    addTearDown(t.dispose);
    await t.type('q');
    expect(await t.waitFor((s) => s.contains('key:q')), contains('key:q'));
    await expectLater(
      t.waitFor((s) => s.contains('never'),
          timeout: const Duration(milliseconds: 50)),
      throwsA(isA<TuiTestFailure>()
          .having((e) => e.message, 'message', contains('timed out'))
          .having((e) => e.message, 'message', contains('key:q'))),
    );
  });

  test('waitFor follows a tick timer in real time', () async {
    final t = TuiTester(_Ticks(),
        options: [withTickInterval(const Duration(milliseconds: 5))]);
    addTearDown(t.dispose);
    await t.waitFor((s) => s == 'ticks: 3');
  });

  test('done returns an OutcomeModel result', () async {
    final t = TuiTester(_Pick());
    addTearDown(t.dispose);
    await t.press('enter');
    final r = await t.done();
    expect(r.outcome, 'picked');
    expect(r.screen, 'picked');
    expect(t.isRunning, isFalse);
    expect(() => t.press('enter'), throwsStateError);
  });

  test('quit returns the final model and screen', () async {
    final t = TuiTester(_Log());
    addTearDown(t.dispose);
    await t.type('z');
    final r = await t.quit();
    expect(r.model, isA<_Log>());
    expect(r.screen, 'size:80x24\nkey:z');
    expect(r.outcome, isNull);
  });

  group('Style statics', () {
    late ColorProfile profile;
    late bool dark;
    setUp(() {
      profile = Style.defaultProfile;
      dark = Style.hasDarkBackground;
      Style.defaultProfile = ColorProfile.ansi;
      Style.hasDarkBackground = false;
      addTearDown(() {
        Style.defaultProfile = profile;
        Style.hasDarkBackground = dark;
      });
    });

    test('are pinned while running and restored after a throwing model',
        () async {
      final t = TuiTester(_Boom(), profile: ColorProfile.trueColor);
      addTearDown(t.dispose);
      expect(Style.defaultProfile, ColorProfile.trueColor);
      expect(Style.hasDarkBackground, isTrue);
      await expectLater(t.press('x'), throwsStateError);
      expect(Style.defaultProfile, ColorProfile.ansi);
      expect(Style.hasDarkBackground, isFalse);
      await expectLater(t.done(), throwsStateError);
      await t.dispose();
    });

    test('are restored by dispose', () async {
      final t = TuiTester(_Log());
      await t.dispose();
      expect(Style.defaultProfile, ColorProfile.ansi);
      expect(Style.hasDarkBackground, isFalse);
    });

    test('two testers in sequence do not leak state', () async {
      final a = TuiTester(_Styled(), profile: ColorProfile.trueColor);
      expect(a.styledScreen, contains('\x1b['));
      expect(a.screen, 'red');
      await a.quit();
      final b = TuiTester(_Styled());
      expect(b.styledScreen, 'red   ');
      await b.type('x');
      await b.quit();
      expect(Style.defaultProfile, ColorProfile.ansi);
      expect(Style.hasDarkBackground, isFalse);
    });
  });

  group('expectScreen', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('dart_tui_golden');
      addTearDown(() => dir.deleteSync(recursive: true));
    });

    test('fails when missing, creates on update, then matches', () {
      final path = '${dir.path}/sub/screen.txt';
      expect(
        () => expectScreen('a\nb', path, update: false),
        throwsA(isA<TuiTestFailure>()
            .having((e) => e.message, 'message', contains('does not exist'))),
      );
      expectScreen('a\nb', path, update: true);
      expect(File(path).readAsStringSync(), 'a\nb\n');
      expectScreen('a\nb', path, update: false);
    });

    test('a mismatch names the first differing line; update accepts it', () {
      final path = '${dir.path}/screen.txt';
      File(path).writeAsStringSync('one\r\ntwo\r\nthree\r\n');
      expectScreen('one\ntwo\nthree', path, update: false);
      expect(
        () => expectScreen('one\nTWO\nthree', path, update: false),
        throwsA(isA<TuiTestFailure>().having(
          (e) => e.message,
          'message',
          allOf(contains('line 2'), contains('"two"'), contains('"TWO"')),
        )),
      );
      expect(
        () => expectScreen('one\ntwo', path, update: false),
        throwsA(isA<TuiTestFailure>()
            .having((e) => e.message, 'message', contains('(no line)'))),
      );
      expectScreen('one\nTWO\nthree', path, update: true);
      expectScreen('one\nTWO\nthree', path, update: false);
    });
  });

  test('CaptureSink keeps text and decodes bytes', () async {
    final sink = CaptureSink()
      ..write('a')
      ..writeln(1)
      ..writeAll(['x', 'y'], ',')
      ..writeCharCode(0x41)
      ..add('é'.codeUnits.isEmpty ? [] : [0xc3, 0xa9]);
    await sink.addStream(Stream.value([0x21]));
    expect(sink.text, 'a1\nx,yAé!');
    sink.clear();
    expect(sink.text, '');
  });
}
