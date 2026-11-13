import 'dart:async';

import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

const _presets = {
  'line': Spinner.line,
  'dot': Spinner.dot,
  'miniDot': Spinner.miniDot,
  'jump': Spinner.jump,
  'pulse': Spinner.pulse,
  'points': Spinner.points,
  'globe': Spinner.globe,
  'moon': Spinner.moon,
  'monkey': Spinner.monkey,
  'meter': Spinner.meter,
  'hamburger': Spinner.hamburger,
  'ellipsis': Spinner.ellipsis,
};

/// Many frames, so `index` counts the frames advanced.
Spinner _counter(int ms) =>
    Spinner(List.generate(10000, (i) => '$i'), Duration(milliseconds: ms));

/// Two id'd spinners that forward every tick and return the next tick.
final class _Pair extends Model {
  _Pair(this.a, this.b, {this.startTwice = false});

  final SpinnerModel a;
  final SpinnerModel b;
  final bool startTwice;

  @override
  Cmd? init() => batch([a.tick(), b.tick(), if (startTwice) a.tick()]);

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is! TickMsg) return (this, null);
    final (na, ca) = a.update(msg);
    final (nb, cb) = b.update(msg);
    return (
      _Pair(na as SpinnerModel, nb as SpinnerModel, startTwice: startTwice),
      batch([ca, cb]),
    );
  }

  @override
  View view() => newView('');
}

Future<_Pair> _run(_Pair initial, Duration runFor) async {
  final program = Program(options: [withoutRenderer(), withInput(null)]);
  Timer(runFor, program.quit);
  return await program.run(initial) as _Pair;
}

void main() {
  group('Spinner presets', () {
    test('there are 12, as in Bubble Tea', () {
      expect(_presets, hasLength(12));
    });

    for (final MapEntry(key: name, value: s) in _presets.entries) {
      test('$name has frames, a positive interval and one width', () {
        expect(s.frames, isNotEmpty);
        expect(s.interval, greaterThan(Duration.zero));
        final widths = s.frames.map(getWidth).toSet();
        expect(widths, hasLength(1), reason: '$name widths: $widths');
        expect(widths.single, greaterThan(0));
      });
    }

    test('default SpinnerModel is miniDot', () {
      expect(SpinnerModel().spinner, same(Spinner.miniDot));
      expect(SpinnerModel(spinner: Spinner.moon).frames, Spinner.moon.frames);
    });

    test('frames override the preset frames and keep its interval', () {
      final s = SpinnerModel(frames: ['a', 'b'], spinner: Spinner.globe);
      expect(s.frames, ['a', 'b']);
      expect(s.spinner.interval, Spinner.globe.interval);
    });
  });

  group('SpinnerModel ids', () {
    test('a timer tickWithId does not move an id-less spinner', () async {
      final s = SpinnerModel();
      final msg = await tickWithId(Duration.zero, 'timer')();
      final (next, cmd) = s.update(msg!);
      expect((next as SpinnerModel).index, 0);
      expect(cmd, isNull);
    });

    test('the global tick still moves an id-less spinner', () {
      final (next, cmd) = SpinnerModel().update(TickMsg(DateTime.now()));
      expect((next as SpinnerModel).index, 1);
      expect(cmd, isNull);
    });

    test('an id spinner ignores the global tick and other ids', () {
      final s = SpinnerModel(id: 'a');
      expect((s.update(TickMsg(DateTime.now())).$1 as SpinnerModel).index, 0);
      expect(
        (s.update(TickMsg(DateTime.now(), id: 'b')).$1 as SpinnerModel).index,
        0,
      );
    });

    test('an id spinner returns its next tick after its interval', () async {
      final s = SpinnerModel(id: 'a', spinner: _counter(30));
      final first = await s.tick()();
      final (next, cmd) = s.update(first!);
      expect((next as SpinnerModel).index, 1);
      final sw = Stopwatch()..start();
      final msg = await cmd!() as TickMsg;
      expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(25));
      expect(msg.id, 'a');
      expect((next.update(msg).$1 as SpinnerModel).index, 2);
    });

    test('calling tick() twice does not double the speed', () async {
      final s = SpinnerModel(id: 'a', spinner: _counter(1));
      final m1 = await s.tick()();
      final m2 = await s.tick()();
      final (s1, c1) = s.update(m1!);
      final (s2, c2) = s1.update(m2!);
      // Only the newest chain survives: the first chain's next tick is stale.
      final stale = await c1!();
      final (s3, c3) = s2.update(stale!);
      expect(identical(s3, s2), isTrue);
      expect(c3, isNull);
      final live = await c2!();
      expect((s2.update(live!).$1 as SpinnerModel).index, 3);
    });

    test('two ids advance independently at their own intervals', () async {
      final end = await _run(
        _Pair(
          SpinnerModel(id: 'fast', spinner: _counter(20)),
          SpinnerModel(id: 'slow', spinner: _counter(80)),
        ),
        const Duration(milliseconds: 800),
      );
      final fast = end.a.index;
      final slow = end.b.index;
      // About 40 vs 10 frames; allow for a slow machine.
      expect(slow, inInclusiveRange(4, 12));
      expect(fast, lessThanOrEqualTo(42));
      expect(fast, greaterThan(slow * 2));
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('a second tick() in a running program does not speed it up', () async {
      final end = await _run(
        _Pair(
          SpinnerModel(id: 'a', spinner: _counter(50)),
          SpinnerModel(id: 'b', spinner: _counter(50)),
          startTwice: true,
        ),
        const Duration(milliseconds: 600),
      );
      // One chain gives about 12 frames; two would give about 24.
      expect(end.a.index, lessThanOrEqualTo(end.b.index + 2));
    }, timeout: const Timeout(Duration(seconds: 10)));
  });
}
