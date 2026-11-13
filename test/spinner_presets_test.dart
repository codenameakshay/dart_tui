import 'dart:async';

import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

// charmbracelet/bubbles spinner/spinner.go, with Ellipsis padded to three cells.
const _presets = {
  'line': (Spinner.line, ['|', '/', '-', r'\'], 10),
  'dot': (Spinner.dot, ['⣾ ', '⣽ ', '⣻ ', '⢿ ', '⡿ ', '⣟ ', '⣯ ', '⣷ '], 10),
  'miniDot': (
    Spinner.miniDot,
    ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'],
    12,
  ),
  'jump': (Spinner.jump, ['⢄', '⢂', '⢁', '⡁', '⡈', '⡐', '⡠'], 10),
  'pulse': (Spinner.pulse, ['█', '▓', '▒', '░'], 8),
  'points': (Spinner.points, ['∙∙∙', '●∙∙', '∙●∙', '∙∙●'], 7),
  'globe': (Spinner.globe, ['🌍', '🌎', '🌏'], 4),
  'moon': (Spinner.moon, ['🌑', '🌒', '🌓', '🌔', '🌕', '🌖', '🌗', '🌘'], 8),
  'monkey': (Spinner.monkey, ['🙈', '🙉', '🙊'], 3),
  'meter': (
    Spinner.meter,
    ['▱▱▱', '▰▱▱', '▰▰▱', '▰▰▰', '▰▰▱', '▰▱▱', '▱▱▱'],
    7
  ),
  'hamburger': (Spinner.hamburger, ['☱', '☲', '☴', '☲'], 3),
  'ellipsis': (Spinner.ellipsis, ['   ', '.  ', '.. ', '...'], 3),
};

final class _ManualTimer implements Timer {
  _ManualTimer(this.callback);

  final void Function() callback;
  bool _active = true;
  int _tick = 0;

  void fire() {
    if (!_active) return;
    _active = false;
    _tick++;
    callback();
  }

  @override
  bool get isActive => _active;

  @override
  int get tick => _tick;

  @override
  void cancel() => _active = false;
}

Future<TickMsg> _runTick(Cmd command, Duration interval) async {
  late _ManualTimer timer;
  Duration? scheduled;
  final result = runZoned(
    () async => await command() as TickMsg,
    zoneSpecification: ZoneSpecification(
      createTimer: (self, parent, zone, duration, callback) {
        expect(scheduled, isNull);
        scheduled = duration;
        return timer = _ManualTimer(callback);
      },
    ),
  );
  expect(scheduled, interval);
  timer.fire();
  return result;
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

  group('Spinner presets', () {
    test('there are 12, as in Bubble Tea', () {
      expect(_presets, hasLength(12));
    });

    for (final MapEntry(key: name, value: (s, frames, fps))
        in _presets.entries) {
      test('$name matches Bubble Tea frames and interval with one width', () {
        expect(s.frames, frames);
        expect(s.interval, Duration(microseconds: 1000000 ~/ fps));
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

  group('spin helper', () {
    for (final (name, spinner, interval, frame) in [
      ('default', null, const Duration(milliseconds: 80), '⠋'),
      (
        'custom',
        const Spinner(['X', 'Y'], Duration(milliseconds: 41)),
        const Duration(milliseconds: 41),
        'X'
      ),
    ]) {
      test('$name uses its frames and interval', () async {
        Duration? scheduled;
        final views = <String>[];
        final result = await runZoned(
          () => spin(
            Future.value(42),
            spinner: spinner,
            options: [
              withoutRenderer(),
              withoutSignalHandler(),
              withInput(null),
              withColorProfile(ColorProfile.noColor),
              withFilter((model, msg) {
                views.add(stripAnsi(model.view().content));
                return msg;
              }),
            ],
          ),
          zoneSpecification: ZoneSpecification(
            createPeriodicTimer: (self, parent, zone, duration, callback) {
              expect(scheduled, isNull);
              scheduled = duration;
              late _ManualTimer timer;
              return timer = _ManualTimer(() => callback(timer));
            },
          ),
        );
        expect(result, 42);
        expect(scheduled, interval);
        expect(views, contains('$frame Loading…'));
      });
    }
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

    test('an id spinner schedules its interval and keeps advancing', () async {
      var s = SpinnerModel(id: 'a', spinner: Spinner.moon);
      var msg = await s.tick()() as TickMsg;
      for (var index = 1; index <= 4; index++) {
        final (next, command) = s.update(msg);
        s = next as SpinnerModel;
        expect(s.index, index);
        msg = await _runTick(command!, const Duration(milliseconds: 125));
        expect(msg.id, 'a');
      }
    });

    test('two ids schedule independently and ignore each other', () async {
      var fast = SpinnerModel(id: 'fast', spinner: Spinner.line);
      var slow = SpinnerModel(id: 'slow', spinner: Spinner.globe);
      var fastTick = await fast.tick()() as TickMsg;
      var slowTick = await slow.tick()() as TickMsg;
      for (var i = 0; i < 3; i++) {
        expect(slow.update(fastTick).$1, same(slow));
        expect(fast.update(slowTick).$1, same(fast));
        final (nextFast, fastCommand) = fast.update(fastTick);
        final (nextSlow, slowCommand) = slow.update(slowTick);
        fast = nextFast as SpinnerModel;
        slow = nextSlow as SpinnerModel;
        expect(fast.index, (i + 1) % 4);
        expect(slow.index, (i + 1) % 3);
        fastTick = await _runTick(
          fastCommand!,
          const Duration(milliseconds: 100),
        );
        slowTick = await _runTick(
          slowCommand!,
          const Duration(milliseconds: 250),
        );
      }
    });
  });
}
