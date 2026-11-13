import 'dart:async';

import 'package:dart_tui/dart_tui.dart';
import 'package:dart_tui/src/program.dart'
    show ProgramTestHook, programTestHookKey;
import 'package:dart_tui/testing.dart' show CaptureSink;
import 'package:test/test.dart';

Program _program() => Program(options: [
      withInput(null),
      withOutput(CaptureSink()),
      withoutRenderer(),
      withoutSignalHandler(),
      withColorProfile(ColorProfile.noColor),
    ]);

final class _Value extends Model implements OutcomeModel<String> {
  _Value(this.label, {this.ready, this.fail = false});
  final String label;
  final Completer<void>? ready;
  final bool fail;
  @override
  String? get outcome => label == 'finished' ? label : null;
  @override
  Cmd? init() {
    if (fail) throw StateError('model failed');
    ready?.complete();
    return null;
  }

  @override
  (Model, Cmd?) update(Msg msg) =>
      msg is KeyPressMsg ? (_Value('finished'), null) : (this, null);
  @override
  View view() => newView(label);
}

final class _Hook implements ProgramTestHook {
  final sizes = <(int, int)>[];
  final events = <String>[];
  @override
  List<ProgramOption> get options => [
        withWindowSize(41, 12),
        withFilter((_, msg) {
          if (msg is WindowSizeMsg) sizes.add((msg.width, msg.height));
          return msg;
        }),
      ];
  @override
  Model attach(Program program, Model model) {
    events.add('attach');
    return model;
  }

  @override
  bool handleMessage(Msg msg) => false;
  @override
  Model unwrap(Model model) {
    events.add('unwrap');
    return model;
  }

  @override
  void detach(Program program) => events.add('detach');
}

void main() {
  late ColorProfile savedProfile;
  late bool savedDark;
  setUp(() {
    savedProfile = Style.defaultProfile;
    savedDark = Style.hasDarkBackground;
    Style.defaultProfile = ColorProfile.ansi256;
    Style.hasDarkBackground = false;
  });
  tearDown(() {
    Style.defaultProfile = savedProfile;
    Style.hasDarkBackground = savedDark;
  });

  test('unhooked run and runForResult can reuse a program', () async {
    final program = _program();
    final firstReady = Completer<void>();
    final first = program.run(_Value('first', ready: firstReady));
    await firstReady.future;
    program.send(KeyPressMsg(const TeaKey(code: KeyCode.rune, text: "x")));
    expect((await first as _Value).label, 'finished');
    final secondReady = Completer<void>();
    final second = program.runForResult(_Value('second', ready: secondReady));
    await secondReady.future;
    program.send(KeyPressMsg(const TeaKey(code: KeyCode.rune, text: "x")));
    expect(await second, 'finished');
    expect(Style.defaultProfile, ColorProfile.ansi256);
    expect(Style.hasDarkBackground, false);
  });

  test('unhooked kill returns the last model and permits another run',
      () async {
    final program = _program();
    final ready = Completer<void>();
    final initial = _Value('live', ready: ready);
    final run = program.run(initial);
    await ready.future;
    program.kill();
    expect(await run, same(initial));
    final nextReady = Completer<void>();
    final next = program.runForResult(_Value('again', ready: nextReady));
    await nextReady.future;
    program.send(KeyPressMsg(const TeaKey(code: KeyCode.rune, text: "x")));
    expect(await next, 'finished');
  });

  test('unhooked model errors restore defaults and permit another run',
      () async {
    final program = _program();
    await expectLater(
        program.run(_Value('bad', fail: true)), throwsA(isA<StateError>()));
    expect(Style.defaultProfile, ColorProfile.ansi256);
    expect(Style.hasDarkBackground, false);
    final ready = Completer<void>();
    final next = program.runForResult(_Value('good', ready: ready));
    await ready.future;
    program.send(KeyPressMsg(const TeaKey(code: KeyCode.rune, text: "x")));
    expect(await next, 'finished');
  });

  test('hook options override program options and detach on success or error',
      () async {
    final hook = _Hook();
    await runZoned(() async {
      final program = Program(options: [
        withInput(null),
        withOutput(CaptureSink()),
        withoutRenderer(),
        withoutSignalHandler(),
        withWindowSize(90, 50),
        withColorProfile(ColorProfile.noColor),
      ]);
      final ready = Completer<void>();
      final run = program.runForResult(_Value('hooked', ready: ready));
      await ready.future;
      program.send(KeyPressMsg(const TeaKey(code: KeyCode.rune, text: "x")));
      expect(await run, 'finished');
      expect(hook.sizes, [(41, 12)]);
      await expectLater(
          program.run(_Value('bad', fail: true)), throwsA(isA<StateError>()));
    }, zoneValues: {programTestHookKey: hook});
    expect(hook.events, ['attach', 'unwrap', 'detach', 'attach', 'detach']);
  });
}
