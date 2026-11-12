import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_tui/dart_tui.dart';
import 'package:dart_tui/src/color_detect.dart';
import 'package:test/test.dart';

const _noColor = ColorProfile.noColor;
const _ansi = ColorProfile.ansi;
const _ansi256 = ColorProfile.ansi256;
const _trueColor = ColorProfile.trueColor;

const _adaptive = Style(
  adaptiveForeground: AdaptiveColor(
    light: RgbColor(0, 0, 0),
    dark: RgbColor(255, 255, 255),
  ),
);
const _lightFg = '\x1b[38;2;0;0;0m';
const _darkFg = '\x1b[38;2;255;255;255m';

void main() {
  // Every test starts from true colour on a dark terminal, whatever the
  // shell's NO_COLOR or COLORFGBG, and leaves the defaults as it found them.
  setUp(() {
    final profile = Style.defaultProfile;
    final dark = Style.hasDarkBackground;
    Style.defaultProfile = ColorProfile.trueColor;
    Style.hasDarkBackground = true;
    addTearDown(() {
      Style.defaultProfile = profile;
      Style.hasDarkBackground = dark;
    });
  });

  group('detectColorProfile', () {
    final cases = <(String, Map<String, String>, bool, ColorProfile)>[
      // Terminal type.
      ('unset TERM', {}, true, _ansi),
      ('plain xterm', {'TERM': 'xterm'}, true, _ansi),
      ('256color TERM', {'TERM': 'xterm-256color'}, true, _ansi256),
      ('direct TERM', {'TERM': 'xterm-direct'}, true, _trueColor),
      (
        'COLORTERM truecolor',
        {'TERM': 'xterm', 'COLORTERM': 'truecolor'},
        true,
        _trueColor
      ),
      (
        'COLORTERM 24bit',
        {'TERM': 'xterm', 'COLORTERM': '24bit'},
        true,
        _trueColor
      ),
      (
        'COLORTERM is case-insensitive',
        {'COLORTERM': 'TrueColor'},
        true,
        _trueColor
      ),
      (
        'COLORTERM other value',
        {'TERM': 'xterm', 'COLORTERM': 'yes'},
        true,
        _ansi
      ),
      ('kitty', {'TERM': 'xterm-kitty'}, true, _trueColor),
      ('ghostty', {'TERM': 'xterm-ghostty'}, true, _trueColor),
      ('WezTerm TERM', {'TERM': 'wezterm'}, true, _trueColor),
      ('alacritty', {'TERM': 'alacritty'}, true, _trueColor),
      (
        'iTerm2',
        {'TERM': 'xterm-256color', 'TERM_PROGRAM': 'iTerm.app'},
        true,
        _trueColor
      ),
      (
        'WezTerm program',
        {'TERM': 'xterm', 'TERM_PROGRAM': 'WezTerm'},
        true,
        _trueColor
      ),
      (
        'ghostty program',
        {'TERM': 'xterm', 'TERM_PROGRAM': 'ghostty'},
        true,
        _trueColor
      ),
      (
        'VS Code',
        {'TERM': 'xterm-256color', 'TERM_PROGRAM': 'vscode'},
        true,
        _trueColor
      ),
      ('Windows Terminal', {'WT_SESSION': 'abc'}, true, _trueColor),
      (
        'Apple Terminal',
        {'TERM': 'xterm-256color', 'TERM_PROGRAM': 'Apple_Terminal'},
        true,
        _ansi256
      ),
      (
        'Apple Terminal with plain TERM',
        {'TERM': 'xterm', 'TERM_PROGRAM': 'Apple_Terminal'},
        true,
        _ansi256
      ),
      (
        'tmux',
        {'TERM': 'tmux-256color', 'TERM_PROGRAM': 'tmux'},
        true,
        _ansi256
      ),
      ('tmux without 256color', {'TERM': 'tmux'}, true, _ansi256),
      ('screen', {'TERM': 'screen'}, true, _ansi256),
      (
        'tmux with COLORTERM',
        {'TERM': 'tmux-256color', 'COLORTERM': 'truecolor'},
        true,
        _trueColor
      ),
      // Not a terminal, dumb.
      (
        'not a terminal',
        {'TERM': 'xterm-256color', 'COLORTERM': 'truecolor'},
        false,
        _noColor
      ),
      ('TERM=dumb', {'TERM': 'dumb', 'COLORTERM': 'truecolor'}, true, _noColor),
      // NO_COLOR.
      ('NO_COLOR', {'NO_COLOR': '1', 'COLORTERM': 'truecolor'}, true, _noColor),
      (
        'NO_COLOR any value',
        {'NO_COLOR': '0', 'TERM': 'xterm'},
        true,
        _noColor
      ),
      (
        'empty NO_COLOR is unset',
        {'NO_COLOR': '', 'TERM': 'xterm'},
        true,
        _ansi
      ),
      (
        'NO_COLOR beats CLICOLOR_FORCE',
        {'NO_COLOR': '1', 'CLICOLOR_FORCE': '3'},
        false,
        _noColor
      ),
      (
        'FORCE_COLOR beats NO_COLOR',
        {'NO_COLOR': '1', 'FORCE_COLOR': '1'},
        true,
        _ansi
      ),
      // FORCE_COLOR levels, when not a terminal.
      ('FORCE_COLOR=1', {'FORCE_COLOR': '1'}, false, _ansi),
      ('FORCE_COLOR=2', {'FORCE_COLOR': '2'}, false, _ansi256),
      ('FORCE_COLOR=3', {'FORCE_COLOR': '3'}, false, _trueColor),
      ('FORCE_COLOR=true', {'FORCE_COLOR': 'true'}, false, _ansi),
      ('FORCE_COLOR other non-zero', {'FORCE_COLOR': '7'}, false, _ansi),
      ('FORCE_COLOR=0 does not force', {'FORCE_COLOR': '0'}, false, _noColor),
      (
        'FORCE_COLOR=false does not force',
        {'FORCE_COLOR': 'false'},
        false,
        _noColor
      ),
      (
        'empty FORCE_COLOR does not force',
        {'FORCE_COLOR': ''},
        false,
        _noColor
      ),
      (
        'FORCE_COLOR beats TERM=dumb',
        {'FORCE_COLOR': '1', 'TERM': 'dumb'},
        false,
        _ansi
      ),
      (
        'FORCE_COLOR is a floor',
        {'FORCE_COLOR': '1', 'TERM': 'xterm-256color'},
        false,
        _ansi256
      ),
      // CLICOLOR_FORCE levels.
      ('CLICOLOR_FORCE=1', {'CLICOLOR_FORCE': '1'}, false, _ansi),
      ('CLICOLOR_FORCE=2', {'CLICOLOR_FORCE': '2'}, false, _ansi256),
      ('CLICOLOR_FORCE=3', {'CLICOLOR_FORCE': '3'}, false, _trueColor),
      (
        'CLICOLOR_FORCE=0 does not force',
        {'CLICOLOR_FORCE': '0'},
        false,
        _noColor
      ),
      (
        'CLICOLOR_FORCE beats TERM=dumb',
        {'CLICOLOR_FORCE': '1', 'TERM': 'dumb'},
        true,
        _ansi
      ),
      (
        'CLICOLOR_FORCE keeps a truecolor terminal',
        {'CLICOLOR_FORCE': '1', 'COLORTERM': 'truecolor'},
        false,
        _trueColor
      ),
    ];
    for (final (name, env, isTerminal, expected) in cases) {
      test(name, () {
        expect(
          detectColorProfile(environment: env, isTerminal: isTerminal),
          expected,
        );
      });
    }
  });

  group('environment defaults', () {
    test('profile is true colour unless NO_COLOR asks for none', () {
      expect(environmentDefaultProfile({}), _trueColor);
      expect(environmentDefaultProfile({'TERM': 'dumb'}), _trueColor);
      expect(environmentDefaultProfile({'NO_COLOR': '1'}), _noColor);
      expect(environmentDefaultProfile({'NO_COLOR': ''}), _trueColor);
      expect(
        environmentDefaultProfile({'NO_COLOR': '1', 'FORCE_COLOR': '1'}),
        _trueColor,
      );
    });

    test('COLORFGBG picks dark or light', () {
      expect(darkBackgroundFromColorFgBg('15;0'), isTrue);
      expect(darkBackgroundFromColorFgBg('15;8'), isTrue);
      expect(darkBackgroundFromColorFgBg('15;default;0'), isTrue);
      expect(darkBackgroundFromColorFgBg('0;15'), isFalse);
      expect(darkBackgroundFromColorFgBg('0;7'), isFalse);
      expect(darkBackgroundFromColorFgBg(null), isNull);
      expect(darkBackgroundFromColorFgBg(''), isNull);
      expect(darkBackgroundFromColorFgBg('0;default'), isNull);
      expect(darkBackgroundFromColorFgBg('0;16'), isNull);
      expect(environmentHasDarkBackground({}), isTrue);
      expect(environmentHasDarkBackground({'COLORFGBG': '0;15'}), isFalse);
    });
  });

  group('additional environment cases', () {
    for (final term in ['foot', 'foot-extra', 'contour']) {
      test('$term supports true colour', () {
        expect(
          detectColorProfile(environment: {'TERM': term}, isTerminal: true),
          _trueColor,
        );
      });
    }
    for (final term in ['tmux-custom', 'screen-custom']) {
      test('$term supports 256 colours', () {
        expect(
          detectColorProfile(environment: {'TERM': term}, isTerminal: true),
          _ansi256,
        );
      });
    }
    for (var background = 0; background < 16; background++) {
      test('COLORFGBG palette index $background', () {
        expect(darkBackgroundFromColorFgBg('15;$background'),
            background <= 6 || background == 8);
      });
    }
    test('COLORFGBG whitespace and malformed values', () {
      expect(darkBackgroundFromColorFgBg('15; 7 '), isFalse);
      for (final value in ['15;', '15;-1', '15;16', '15;unknown']) {
        expect(darkBackgroundFromColorFgBg(value), isNull);
      }
    });
  });

  group('Style defaults', () {
    test('Style.defaultProfile applies only to styles without a profile', () {
      Style.defaultProfile = _noColor;
      final red = const Style().bold().foregroundColorRgb(255, 0, 0);
      expect(red.render('x'), isNot(contains('38;')));
      expect(red.render('x'), contains('\x1b[1m'));
      expect(
        red.withProfile(_trueColor).render('x'),
        contains('\x1b[38;2;255;0;0m'),
      );
      Style.defaultProfile = _ansi256;
      expect(red.render('x'), contains('\x1b[38;5;'));
    });

    test('AdaptiveColor follows Style.hasDarkBackground', () {
      Style.hasDarkBackground = true;
      expect(_adaptive.render('x'), contains(_darkFg));
      Style.hasDarkBackground = false;
      expect(_adaptive.render('x'), contains(_lightFg));
    });

    test('an explicit Style background wins over the default', () {
      Style.hasDarkBackground = false;
      final onDark = _adaptive.copyWith(backgroundRgb: const RgbColor(0, 0, 0));
      expect(onDark.render('x'), contains(_darkFg));
      Style.hasDarkBackground = true;
      final onLight =
          _adaptive.copyWith(backgroundRgb: const RgbColor(255, 255, 255));
      expect(onLight.render('x'), contains(_lightFg));
    });
  });

  group('CompleteColor adaptive contrast', () {
    for (final (profile, foreground) in [
      (_trueColor, _darkFg),
      (_ansi256, '\x1b[38;5;15m'),
      (_ansi, '\x1b[37m'),
    ]) {
      for (final rawBackground in [null, const RgbColor(255, 255, 255)]) {
        test('$profile complete background wins with raw $rawBackground', () {
          Style.hasDarkBackground = false;
          final style = _adaptive.copyWith(
            profile: profile,
            backgroundRgb: rawBackground,
            backgroundComplete: const CompleteColor(
              trueColor: RgbColor(0, 0, 0),
              ansi256: 0,
              ansi: 0,
            ),
          );
          expect(style.render('x'), contains(foreground));
        });
      }
    }
  });

  group('Program', () {
    test('a synthetic background reply preserves light COLORFGBG', () async {
      Style.hasDarkBackground = true;
      final (sink, text) = _sink();
      final model = _BackgroundRequestModel();
      await Program(options: [
        withInput(null),
        withOutput(sink),
        withoutSignalHandler(),
        withEnvironment({'COLORFGBG': '0;15'}),
      ]).run(model);
      expect(model.reply, 0x000000);
      expect(model.darkInUpdate, isFalse);
      expect(await text(), contains('\x1b]11;?\x07'));
      expect(Style.hasDarkBackground, isTrue);
    });

    for (final reuse in [false, true]) {
      test(
          'kill then immediate ${reuse ? 'reuse' : 'next Program'} '
          'restores defaults', () async {
        Style.defaultProfile = _ansi256;
        Style.hasDarkBackground = true;
        final (sink, text) = _sink();
        Program makeProgram() => Program(options: [
              withInput(null),
              withOutput(sink),
              withoutSignalHandler(),
              withColorProfile(_ansi),
              withEnvironment({'COLORFGBG': '0;15'}),
            ]);
        final first = makeProgram();
        final firstModel = _WaitingProfileModel();
        final firstRun = first.run(firstModel);
        await firstModel.ready.future;
        first.kill();
        final second = reuse ? first : makeProgram();
        final secondModel = _WaitingProfileModel();
        final secondRun = second.run(secondModel);
        try {
          await secondModel.ready.future;
          await firstRun;
          expect(Style.defaultProfile, _ansi);
          expect(Style.hasDarkBackground, isFalse);
        } finally {
          second.quit();
          await secondRun;
          await text();
        }
        expect(Style.defaultProfile, _ansi256);
        expect(Style.hasDarkBackground, isTrue);
      });
    }

    test('a Program can run twice after normal completion', () async {
      Style.defaultProfile = _ansi;
      Style.hasDarkBackground = true;
      final (sink, text) = _sink();
      final program = Program(options: [
        withInput(null),
        withOutput(sink),
        withoutSignalHandler(),
        withColorProfile(_ansi256),
        withEnvironment({'COLORFGBG': '0;15'}),
      ]);
      for (var run = 0; run < 2; run++) {
        final model = _ProbeModel(_adaptive);
        await program.run(model);
        expect(model.profiles, [_ansi256]);
        expect(model.darkDuringView, everyElement(isFalse));
        expect(Style.defaultProfile, _ansi);
        expect(Style.hasDarkBackground, isTrue);
      }
      await text();
    });

    test('defaults are restored when init throws', () async {
      Style.defaultProfile = _ansi;
      Style.hasDarkBackground = true;
      final (sink, text) = _sink();
      await expectLater(
        Program(options: [
          withInput(null),
          withOutput(sink),
          withoutSignalHandler(),
          withColorProfile(_noColor),
          withEnvironment({'COLORFGBG': '0;15'}),
        ]).run(_ThrowingInitModel()),
        throwsA(isA<StateError>()),
      );
      expect(Style.defaultProfile, _ansi);
      expect(Style.hasDarkBackground, isTrue);
      await text();
    });

    test('detects NO_COLOR on stdout: no colour, bold and underline stay',
        () async {
      final fake = _FakeStdout();
      final model = _ProbeModel(
        const Style().bold().underline().foregroundColorRgb(255, 0, 0),
      );
      await IOOverrides.runZoned(
        () => Program(options: [
          withInput(null),
          withoutSignalHandler(),
          withEnvironment({'NO_COLOR': '1', 'COLORTERM': 'truecolor'}),
        ]).run(model),
        stdout: () => fake,
      );
      final out = fake.text;
      expect(model.profiles, [_noColor]);
      expect(out, contains('hello'));
      expect(out, isNot(contains('38;')));
      expect(out, contains('\x1b[1m'));
      expect(out, contains('4m'));
    });

    test('detects the profile from the injected environment on stdout',
        () async {
      final fake = _FakeStdout();
      final model = _ProbeModel(const Style().foregroundColorRgb(255, 0, 0));
      await IOOverrides.runZoned(
        () => Program(options: [
          withInput(null),
          withoutSignalHandler(),
          withEnvironment({'FORCE_COLOR': '2'}),
        ]).run(model),
        stdout: () => fake,
      );
      expect(model.profiles, [_ansi256]);
      expect(fake.text, contains('\x1b[38;5;'));
    });

    test('a custom sink keeps true colour, even with NO_COLOR', () async {
      final (sink, text) = _sink();
      final model = _ProbeModel(const Style().foregroundColorRgb(255, 0, 0));
      await Program(options: [
        withInput(null),
        withOutput(sink),
        withoutSignalHandler(),
        withEnvironment({'NO_COLOR': '1'}),
      ]).run(model);
      expect(model.profiles, [_trueColor]);
      expect(await text(), contains('\x1b[38;2;255;0;0m'));
    });

    test('withColorProfile pins the profile for the run and is restored',
        () async {
      Style.defaultProfile = _ansi256;
      Style.hasDarkBackground = false;
      final (sink, text) = _sink();
      final model =
          _ProbeModel(const Style().bold().foregroundColorRgb(255, 0, 0));
      await Program(options: [
        withInput(null),
        withOutput(sink),
        withoutSignalHandler(),
        withColorProfile(_noColor),
        withEnvironment({'COLORFGBG': '15;0'}),
      ]).run(model);
      expect(model.profiles, [_noColor]);
      expect(model.darkDuringView, contains(true));
      expect(await text(), isNot(contains('38;')));
      expect(Style.defaultProfile, _ansi256);
      expect(Style.hasDarkBackground, isFalse);
    });

    test('defaults are restored when update throws', () async {
      Style.defaultProfile = _ansi;
      Style.hasDarkBackground = true;
      final (sink, _) = _sink();
      final run = Program(options: [
        withInput(null),
        withOutput(sink),
        withoutSignalHandler(),
        withColorProfile(_trueColor),
      ]).run(_ThrowingModel());
      await expectLater(run, throwsA(isA<StateError>()));
      expect(Style.defaultProfile, _ansi);
      expect(Style.hasDarkBackground, isTrue);
    });

    test('BackgroundColorMsg switches AdaptiveColor on the next frame',
        () async {
      Style.hasDarkBackground = true;
      final (sink, _) = _sink();
      final model = _BackgroundModel(0xFFFFFF);
      await Program(options: [
        withInput(null),
        withOutput(sink),
        withoutSignalHandler(),
        withEnvironment(const {}),
      ]).run(model);
      expect(model.darkInUpdate, isFalse);
      expect(model.frames.first, contains(_darkFg));
      expect(model.frames.last, contains(_lightFg));
      expect(Style.hasDarkBackground, isTrue);
    });

    test('COLORFGBG from withEnvironment picks the light variant', () async {
      Style.hasDarkBackground = true;
      final (sink, _) = _sink();
      final model = _ProbeModel(_adaptive);
      await Program(options: [
        withInput(null),
        withOutput(sink),
        withoutSignalHandler(),
        withEnvironment({'COLORFGBG': '0;15'}),
      ]).run(model);
      expect(model.frames.first, contains(_lightFg));
      expect(Style.hasDarkBackground, isTrue);
    });
  });
}

(IOSink, Future<String> Function()) _sink() {
  final chunks = <int>[];
  final controller = StreamController<List<int>>();
  final done = controller.stream.forEach(chunks.addAll);
  final sink = IOSink(controller.sink);
  return (
    sink,
    () async {
      await sink.close();
      await done;
      return utf8.decode(chunks);
    }
  );
}

/// Renders [style] over "hello" and quits after the first message.
final class _ProbeModel extends Model {
  _ProbeModel(this.style);
  final Style style;
  final profiles = <ColorProfile>[];
  final frames = <String>[];
  final darkDuringView = <bool>[];

  @override
  Cmd? init() => () => QuitMsg();

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is ColorProfileMsg) profiles.add(msg.profile);
    if (msg is QuitMsg) return (this, () => QuitMsg());
    return (this, null);
  }

  @override
  View view() {
    darkDuringView.add(Style.hasDarkBackground);
    final frame = style.render('hello');
    frames.add(frame);
    return newView(frame);
  }
}

final class _ThrowingModel extends Model {
  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is ColorProfileMsg) throw StateError('boom');
    return (this, null);
  }

  @override
  View view() => newView('x');
}

final class _BackgroundModel extends Model {
  _BackgroundModel(this.rgb);
  final int rgb;
  final frames = <String>[];
  bool? darkInUpdate;

  @override
  Cmd? init() => () => BackgroundColorMsg(rgb);

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is BackgroundColorMsg) {
      darkInUpdate = Style.hasDarkBackground;
      return (this, () => QuitMsg());
    }
    return (this, null);
  }

  @override
  View view() {
    final frame = _adaptive.render('x');
    frames.add(frame);
    return newView(frame);
  }
}

/// Stands in for the process stdout, so Program takes its detection path.
final class _FakeStdout implements Stdout {
  final _buffer = StringBuffer();
  String get text => _buffer.toString();

  @override
  bool get hasTerminal => false;
  @override
  bool get supportsAnsiEscapes => true;
  @override
  Encoding encoding = utf8;
  @override
  void write(Object? object) => _buffer.write(object);
  @override
  void writeln([Object? object = '']) => _buffer.writeln(object);
  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      _buffer.writeAll(objects, separator);
  @override
  void writeCharCode(int charCode) => _buffer.writeCharCode(charCode);
  @override
  void add(List<int> data) => _buffer.write(utf8.decode(data));
  @override
  Future<void> flush() async {}
  @override
  Future<void> close() async {}
  @override
  Future<void> get done async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _BackgroundRequestModel extends Model {
  int? reply;
  bool? darkInUpdate;

  @override
  Cmd? init() => requestBackgroundColor;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is BackgroundColorMsg) {
      reply = msg.rgb;
      darkInUpdate = Style.hasDarkBackground;
      return (this, () => QuitMsg());
    }
    return (this, null);
  }

  @override
  View view() => newView(_adaptive.render('x'));
}

final class _WaitingProfileModel extends Model {
  final ready = Completer<void>();

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is ColorProfileMsg) ready.complete();
    return (this, null);
  }

  @override
  View view() => newView(_adaptive.render('x'));
}

final class _ThrowingInitModel extends Model {
  @override
  Cmd? init() => throw StateError('init failed');

  @override
  (Model, Cmd?) update(Msg msg) => (this, null);

  @override
  View view() => newView('x');
}
