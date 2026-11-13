import 'dart:async';

import 'package:dart_tui/dart_tui.dart';
import 'package:dart_tui/testing.dart';
import 'package:test/test.dart';

final class _Text extends Model {
  _Text(this.text);
  final String text;
  @override
  (Model, Cmd?) update(Msg msg) =>
      msg is KeyPressMsg ? (_Text('$text${msg.key}'), null) : (this, null);
  @override
  View view() => newView(text);
}

void main() {
  late ColorProfile savedProfile;
  late bool savedDark;
  setUp(() {
    savedProfile = Style.defaultProfile;
    savedDark = Style.hasDarkBackground;
    Style.defaultProfile = ColorProfile.ansi;
    Style.hasDarkBackground = false;
  });
  tearDown(() {
    Style.defaultProfile = savedProfile;
    Style.hasDarkBackground = savedDark;
  });

  test('flush bypasses a filter which drops unknown messages', () async {
    final t = TuiTester(_Text(''), options: [
      withFilter((model, msg) => msg is KeyPressMsg ? msg : null),
    ]);
    addTearDown(t.dispose);
    await t.press('x').timeout(const Duration(milliseconds: 100));
    expect(t.screen, 'x');
  });

  test('pins profile before a body starts any program', () async {
    final ready = Completer<void>();
    final t = TuiTester.run(() async {
      await ready.future;
      return Style.defaultProfile;
    }, profile: ColorProfile.trueColor);
    expect(Style.defaultProfile, ColorProfile.trueColor);
    ready.complete();
    expect((await t.done()).value, ColorProfile.trueColor);
    expect(Style.defaultProfile, ColorProfile.ansi);
    expect(Style.hasDarkBackground, isFalse);
  });

  test('resized dimensions apply to later programs', () async {
    final sizes = <String>[];
    final t = TuiTester.run(() async {
      await Program().run(_Text('first'));
      return Program().run(_Text('second'));
    }, options: [
      withFilter((model, msg) {
        if (msg is WindowSizeMsg) sizes.add('${msg.width}x${msg.height}');
        return msg;
      })
    ]);
    addTearDown(t.dispose);
    await t.resize(42, 9);
    await t.send(QuitMsg());
    await t.waitFor((screen) => screen.startsWith('second'));
    expect(sizes, ['80x24', '42x9', '42x9']);
    await t.quit();
  });
  test('resized dimensions survive rerunning the same program', () async {
    final sizes = <String>[];
    final t = TuiTester.run(() async {
      final program = Program();
      await program.run(_Text('first'));
      return program.run(_Text('second'));
    }, options: [
      withFilter((model, msg) {
        if (msg is WindowSizeMsg) sizes.add('${msg.width}x${msg.height}');
        return msg;
      })
    ]);
    addTearDown(t.dispose);
    await t.resize(42, 9);
    await t.send(QuitMsg());
    await t.waitFor((s) => s == 'second');
    expect(sizes, ['80x24', '42x9', '42x9']);
    await t.quit();
  });

  test('concurrent sends retain invocation order', () async {
    final t = TuiTester(_Events());
    addTearDown(t.dispose);
    await Future.wait([
      t.press('a'),
      t.type('bc'),
      t.paste('de'),
      t.send(keyPressFor('f')),
    ]);
    expect(t.screen, 'a,b,c,start,de,end,f');
  });

  test('no-program body yields empty result and restores defaults', () async {
    final t = TuiTester.run(() async => 7);
    final result = await t.done();
    expect(result.value, 7);
    expect(result.model, isNull);
    expect(result.screen, '');
    await expectLater(t.send(QuitMsg()), throwsStateError);
    await expectLater(
        t.waitFor((s) => s == 'missing'), throwsA(isA<TuiTestFailure>()));
    await t.dispose();
    expect(Style.defaultProfile, ColorProfile.ansi);
    expect(Style.hasDarkBackground, isFalse);
  });

  test('dispose is repeatable mid-run and cannot change the next tester',
      () async {
    final a = TuiTester(_Text('a'), profile: ColorProfile.trueColor);
    await expectLater(
        a.done(timeout: Duration.zero), throwsA(isA<TuiTestFailure>()));
    await a.dispose();
    final b = TuiTester(_Text('b'), profile: ColorProfile.ansi256);
    addTearDown(b.dispose);
    await a.dispose();
    expect(Style.defaultProfile, ColorProfile.ansi256);
    expect(Style.hasDarkBackground, isTrue);
    await b.quit();
    expect(Style.defaultProfile, ColorProfile.ansi);
    expect(Style.hasDarkBackground, isFalse);
  });

  test('dispose also stops programs the body starts later', () async {
    final t = TuiTester.run(() async => [
          await promptSelect(['a', 'b']),
          await promptSelect(['c', 'd']),
        ]);
    await t.dispose();
    expect(t.isRunning, isFalse);
    expect((await t.done(timeout: Duration.zero)).value, [null, null]);
  });

  test('a rejected run does not detach the active program', () async {
    late Program program;
    final rejected = Completer<void>();
    final t = TuiTester.run(() async {
      program = Program();
      final running = program.run(_Text(''));
      await expectLater(program.run(_Text('unused')), throwsStateError);
      rejected.complete();
      return running;
    });
    addTearDown(() async {
      program.kill();
      await t.dispose();
    });
    await rejected.future;
    await t.press('x').timeout(const Duration(milliseconds: 100));
    expect(t.screen, 'x');
    await t.quit();
  });

  test('an earlier run detaching does not detach a rerun', () async {
    late Program program;
    late Future<Model> rerun;
    final ready = Completer<void>();
    final t = TuiTester.run(() async {
      program = Program();
      await program.run(_Command(() async {
        program.kill();
        rerun = program.run(_Text('rerun'));
        return null;
      }));
      ready.complete();
      return rerun;
    });
    addTearDown(() async {
      program.kill();
      await t.dispose();
    });
    await ready.future;
    await t.press('x').timeout(const Duration(milliseconds: 100));
    expect(t.screen, 'rerunx');
    await t.quit();
  });

  test('dispose from a command keeps its two-second bound', () async {
    final start = Completer<void>();
    final releaseBody = Completer<void>();
    final disposed = Completer<void>();
    late TuiTester t;
    t = TuiTester.run(() async {
      await Program().run(_Command(() async {
        await start.future;
        await t.dispose();
        disposed.complete();
        return null;
      }));
      await releaseBody.future;
      return null;
    });
    addTearDown(() async {
      if (!releaseBody.isCompleted) releaseBody.complete();
      await t.dispose();
    });
    start.complete();
    await disposed.future.timeout(const Duration(seconds: 3));
    expect(t.isRunning, isTrue);
    releaseBody.complete();
    await t.done();
  });

  test('dispose timeout does not claim the body has finished', () async {
    final release = Completer<void>();
    final t = TuiTester.run(() async {
      await release.future;
      return promptSelect(['late']);
    }, profile: ColorProfile.trueColor);
    addTearDown(() async {
      if (!release.isCompleted) release.complete();
      await t.dispose();
    });
    await t.dispose();
    expect(t.isRunning, isTrue);
    expect(Style.defaultProfile, ColorProfile.ansi);
    expect(Style.hasDarkBackground, isFalse);
    await expectLater(t.press('x'), throwsStateError);
    final next = TuiTester(_Text('next'), profile: ColorProfile.ansi256);
    addTearDown(next.dispose);
    release.complete();
    expect((await t.done()).value, isNull);
    expect(t.isRunning, isFalse);
    expect(Style.defaultProfile, ColorProfile.ansi256);
    expect(Style.hasDarkBackground, isTrue);
    await next.quit();
    expect(Style.defaultProfile, ColorProfile.ansi);
    expect(Style.hasDarkBackground, isFalse);
  });

  test('dispose stops a program started by a command', () async {
    final child = Completer<Object?>();
    final release = Completer<void>();
    final started = Completer<void>();
    final t = TuiTester.run(() async {
      await Program().run(_Command(() async {
        started.complete();
        await release.future;
        child.complete(await promptSelect(['child']));
        return null;
      }));
      release.complete();
      return child.future;
    });
    addTearDown(t.dispose);
    await started.future;
    await t.dispose();
    expect((await t.done()).value, isNull);
    expect(t.isRunning, isFalse);
  });

  for (final phase in ['init', 'view', 'update']) {
    test('model $phase errors reach done and waitFor and allow dispose',
        () async {
      final t = TuiTester(_Throws(phase), profile: ColorProfile.trueColor);
      if (phase == 'update') {
        await expectLater(t.press('x'), throwsStateError);
      }
      await expectLater(t.done(), throwsStateError);
      await expectLater(t.waitFor((s) => false), throwsStateError);
      await expectLater(t.quit(), throwsStateError);
      await t.dispose();
      expect(Style.defaultProfile, ColorProfile.ansi);
      expect(Style.hasDarkBackground, isFalse);
    });
  }

  test('flush completes when an outcome ends before the handshake', () async {
    final t = TuiTester(_Outcome());
    addTearDown(t.dispose);
    await t.press('x').timeout(const Duration(milliseconds: 100));
    expect((await t.done()).outcome, 'done');
  });

  test('darkBackground is the start; a background reply changes it', () async {
    final t = TuiTester(_Dark());
    addTearDown(t.dispose);
    expect(t.screen, 'dark');
    await t.send(BackgroundColorMsg(0xffffff));
    expect(t.screen, 'light');
    await t.quit();
    expect(Style.hasDarkBackground, isFalse); // the value before the tester
  });

  test('an explicit COLORFGBG wins over darkBackground', () async {
    final t = TuiTester(_Dark(), environment: {'COLORFGBG': '0;15'});
    addTearDown(t.dispose);
    expect(t.screen, 'light');
  });
}

final class _Dark extends Model {
  @override
  (Model, Cmd?) update(Msg msg) => (this, null);
  @override
  View view() => newView(Style.hasDarkBackground ? 'dark' : 'light');
}

final class _Events extends Model {
  _Events([this.events = const []]);
  final List<String> events;
  @override
  (Model, Cmd?) update(Msg msg) {
    final value = switch (msg) {
      KeyPressMsg() => msg.key,
      PasteStartMsg() => 'start',
      PasteMsg() => msg.content,
      PasteEndMsg() => 'end',
      _ => null,
    };
    return (value == null ? this : _Events([...events, value]), null);
  }

  @override
  View view() => newView(events.join(','));
}

final class _Throws extends Model {
  _Throws(this.phase);
  final String phase;
  @override
  Cmd? init() {
    if (phase == 'init') throw StateError('init');
    return null;
  }

  @override
  (Model, Cmd?) update(Msg msg) {
    if (phase == 'update' && msg is KeyPressMsg) throw StateError('update');
    return (this, null);
  }

  @override
  View view() {
    if (phase == 'view') throw StateError('view');
    return newView('ok');
  }
}

final class _Outcome extends Model implements OutcomeModel<String> {
  _Outcome([this.outcome]);
  @override
  final String? outcome;
  @override
  (Model, Cmd?) update(Msg msg) =>
      (msg is KeyPressMsg ? _Outcome('done') : this, null);
  @override
  View view() => newView(outcome ?? '');
}

final class _Command extends Model {
  _Command(this.command);
  final Cmd command;
  @override
  Cmd? init() => command;
  @override
  (Model, Cmd?) update(Msg msg) => (this, null);
  @override
  View view() => newView('parent');
}
