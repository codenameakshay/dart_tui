import 'dart:async';

import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

Program _program() => Program(options: [
      withInput(null),
      withoutRenderer(),
      withoutSignalHandler(),
      withoutCatchPanics(),
    ]);

final class _CommandModel extends OutcomeModel<int> {
  _CommandModel(this.ready, [this.command]);

  final Completer<void> ready;
  final Cmd? command;

  @override
  int? get outcome => null;

  @override
  Cmd init() => () {
        ready.complete();
        return command?.call();
      };

  @override
  (Model, Cmd?) update(Msg msg) => (this, null);

  @override
  View view() => newView('command timers');
}

final class _ObservedTimer implements Timer {
  _ObservedTimer(this.inner);

  final Timer inner;
  int cancellations = 0;

  @override
  void cancel() {
    cancellations++;
    inner.cancel();
  }

  @override
  bool get isActive => inner.isActive;

  @override
  int get tick => inner.tick;
}

void main() {
  test('a microtask cannot start a command timer after its run ends', () async {
    final ready = Completer<void>();
    final resume = Completer<void>();
    final created = Completer<Timer>();
    final program = _program();
    final run = program.run(_CommandModel(ready, () {
      unawaited(resume.future.then((_) {
        scheduleMicrotask(() {
          final timer = Timer(const Duration(seconds: 10), () {});
          created.complete(timer);
        });
      }));
      return null;
    }));
    addTearDown(program.kill);
    await ready.future;
    program.quit();
    await run;

    resume.complete();
    final timer = await created.future.timeout(const Duration(seconds: 1));
    addTearDown(timer.cancel);
    expect(timer.isActive, isFalse);
  });

  test('a stale command cannot start a periodic timer in a replacement run',
      () async {
    final firstReady = Completer<void>();
    final resume = Completer<void>();
    final staleCreated = Completer<Timer>();
    final secondReady = Completer<void>();
    final program = _program();
    final firstRun = program.run(_CommandModel(firstReady, () async {
      await resume.future;
      final timer = Timer.periodic(const Duration(seconds: 10), (_) {});
      staleCreated.complete(timer);
      return null;
    }));
    addTearDown(program.kill);
    await firstReady.future;
    program.quit();
    await firstRun;

    late Timer currentTimer;
    final secondRun = program.run(_CommandModel(secondReady, () {
      currentTimer = Timer.periodic(const Duration(seconds: 10), (_) {});
      return null;
    }));
    addTearDown(() async {
      program.kill();
      await secondRun;
    });
    await secondReady.future;
    resume.complete();
    final staleTimer =
        await staleCreated.future.timeout(const Duration(seconds: 1));
    addTearDown(staleTimer.cancel);

    expect((staleTimer.isActive, currentTimer.isActive), (false, true));
    program.quit();
    await secondRun;
    expect(currentTimer.isActive, isFalse);
  });

  for (final forResult in [false, true]) {
    test(
        'a command-started ${forResult ? 'runForResult' : 'run'} owns timers '
        'and preserves caller zone values', () async {
      final firstReady = Completer<void>();
      final secondReady = Completer<void>();
      final contextKey = Object();
      Object? contextValue;
      late Timer timer;
      late Future<Object?> secondRun;
      final program = _program();
      final firstRun = program.run(_CommandModel(firstReady, () {
        program.kill();
        secondRun = runZoned(() {
          final model = _CommandModel(secondReady, () {
            contextValue = Zone.current[contextKey];
            timer = Timer.periodic(const Duration(seconds: 10), (_) {});
            return null;
          });
          return forResult ? program.runForResult(model) : program.run(model);
        }, zoneValues: {contextKey: 42});
        return null;
      }));
      addTearDown(() async {
        program.kill();
        await firstRun;
        await secondRun;
        timer.cancel();
      });
      await firstReady.future;
      await secondReady.future.timeout(const Duration(seconds: 1));
      await firstRun;
      expect((timer.isActive, contextValue), (true, 42));
      program.quit();
      await secondRun;
      expect(timer.isActive, isFalse);
    });
  }

  test('a periodic command timer ticks while running and stops at quit',
      () async {
    final ready = Completer<void>();
    final ticked = Completer<void>();
    var ticks = 0;
    late Timer timer;
    final program = _program();
    final run = program.run(_CommandModel(ready, () {
      timer = Timer.periodic(const Duration(milliseconds: 1), (_) {
        ticks++;
        if (!ticked.isCompleted) ticked.complete();
      });
      return null;
    }));
    addTearDown(() {
      timer.cancel();
      program.kill();
    });
    await ready.future;
    await ticked.future.timeout(const Duration(seconds: 1));
    expect(timer.isActive, isTrue);
    program.quit();
    await run;
    final ticksAtQuit = ticks;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect((timer.isActive, ticks), (false, ticksAtQuit));
  });

  test('registering another timer releases explicitly canceled command timers',
      () async {
    late Timer canceled;
    late Timer active;
    await runZoned(() async {
      final ready = Completer<void>();
      final program = _program();
      final run = program.run(_CommandModel(ready, () {
        canceled = Timer(const Duration(seconds: 10), () {})..cancel();
        active = Timer(const Duration(seconds: 10), () {});
        return null;
      }));
      addTearDown(program.kill);
      await ready.future;
      program.quit();
      await run;
    }, zoneSpecification: ZoneSpecification(
      createTimer: (self, parent, zone, duration, callback) {
        return _ObservedTimer(parent.createTimer(zone, duration, callback));
      },
    ));
    expect([
      (canceled as _ObservedTimer).cancellations,
      (active as _ObservedTimer).cancellations,
    ], [
      1,
      1
    ]);
  });

  test('an awaited timer error interrupts the run and cancels peer timers',
      () async {
    final ready = Completer<void>();
    final peerCreated = Completer<void>();
    final fail = Completer<void>();
    late Timer peer;
    final program = _program();
    final run = program.run(_CommandModel(
        ready,
        batch([
          () {
            peer = Timer.periodic(const Duration(seconds: 10), (_) {});
            peerCreated.complete();
            return null;
          },
          () async {
            await fail.future;
            await Future<void>.delayed(Duration.zero);
            throw StateError('command timer failed');
          },
        ])));
    addTearDown(program.kill);
    await ready.future;
    await peerCreated.future.timeout(const Duration(seconds: 1));
    expect(peer.isActive, isTrue);
    fail.complete();
    await run.timeout(const Duration(seconds: 1));
    expect(peer.isActive, isFalse);
  });

  test('a command-started run preserves the caller error zone', () async {
    final observed = <String>[];
    final errorsReceived = Completer<void>();
    final finished = Completer<void>();
    final parentFinished = Completer<void>();
    void receive(String owner, Object error) {
      observed.add('$owner:${(error as StateError).message}');
      if (observed.length == 2) errorsReceived.complete();
    }

    unawaited(runZonedGuarded(() async {
      final parent = _program();
      final parentRun = parent.run(_CommandModel(Completer<void>(), () {
        unawaited(runZonedGuarded(() async {
          final ready = Completer<void>();
          final program = _program();
          final run = program.run(_CommandModel(ready, () {
            scheduleMicrotask(() => throw StateError('microtask'));
            Timer(Duration.zero, () => throw StateError('timer'));
            return null;
          }));
          try {
            await ready.future;
            await errorsReceived.future;
            program.quit();
            await run;
            finished.complete();
          } catch (error, stack) {
            finished.completeError(error, stack);
          } finally {
            program.kill();
          }
        }, (error, stack) => receive('inner', error)));
        return null;
      }));
      try {
        await finished.future;
        parent.quit();
        await parentRun;
      } finally {
        parent.kill();
        parentFinished.complete();
      }
    }, (error, stack) => receive('outer', error)));
    await finished.future.timeout(const Duration(seconds: 1));
    await parentFinished.future.timeout(const Duration(seconds: 1));
    expect(observed, ['inner:microtask', 'inner:timer']);
  });
}
