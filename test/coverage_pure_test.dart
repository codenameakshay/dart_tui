import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

void main() {
  group('TimerModel', () {
    final t0 = DateTime(2020);
    test('start/stop/reset toggle running and elapsed', () {
      final t = TimerModel(duration: const Duration(seconds: 10));
      expect(t.start().running, isTrue);
      expect(t.start().stop().running, isFalse);
      final r = t
          .copyWith(elapsed: const Duration(seconds: 3), running: true)
          .reset();
      expect(r.elapsed, Duration.zero);
      expect(r.running, isFalse);
    });

    test('tick advances elapsed only while running and unfinished', () {
      final t =
          TimerModel(duration: const Duration(seconds: 10), running: true);
      final (m1, _) = t.update(TickMsg(t0));
      final t1 = m1 as TimerModel;
      final (m2, _) = t1.update(TickMsg(t0.add(const Duration(seconds: 2))));
      expect((m2 as TimerModel).elapsed, const Duration(seconds: 2));

      // stopped timer ignores ticks
      final stopped = TimerModel(duration: const Duration(seconds: 10));
      expect(stopped.update(TickMsg(t0)).$1, same(stopped));
    });

    test('id-filtered ticks are ignored when id mismatches', () {
      final t = TimerModel(
          duration: const Duration(seconds: 5), running: true, id: 'a');
      expect(t.update(TickMsg(t0, id: 'b')).$1, same(t));
    });

    test('finished clamps and view renders mm:ss with a check', () {
      final t = TimerModel(
          duration: const Duration(seconds: 5),
          elapsed: const Duration(seconds: 5));
      expect(t.finished, isTrue);
      expect(t.remaining, Duration.zero);
      expect(t.view().content, contains('✓'));
    });
  });

  group('StopwatchModel', () {
    final t0 = DateTime(2020);
    test('start/stop/reset and tick accumulation', () {
      var s = StopwatchModel().start();
      expect(s.running, isTrue);
      final (m1, _) = s.update(TickMsg(t0));
      final (m2, _) = (m1 as StopwatchModel)
          .update(TickMsg(t0.add(const Duration(seconds: 1))));
      expect((m2 as StopwatchModel).elapsed, const Duration(seconds: 1));
      s = StopwatchModel(elapsed: const Duration(seconds: 9), running: true)
          .reset();
      expect(s.elapsed, Duration.zero);
    });

    test('stopped and id-mismatch ticks are ignored; view is mm:ss.cc', () {
      final s = StopwatchModel(id: 'x', running: true);
      expect(s.update(TickMsg(t0, id: 'y')).$1, same(s));
      final stopped = StopwatchModel();
      expect(stopped.update(TickMsg(t0)).$1, same(stopped));
      expect(
          StopwatchModel(elapsed: const Duration(milliseconds: 1230))
              .view()
              .content,
          matches(RegExp(r'\d\d:\d\d\.\d\d')));
    });
  });

  group('cmd helpers', () {
    test('batch/sequence compaction', () {
      expect(batch(const []), isNull);
      expect(batch([null, null]), isNull);
      Msg? noop() => null;
      expect(batch([noop]), isNotNull); // single passthrough
      final b = batch([noop, noop]);
      expect(b, isNotNull);
      expect(b!(), isA<BatchMsg>());
      final s = sequence([noop, noop]);
      expect(s!(), isA<SequenceMsg>());
    });

    test('tick and every produce TickMsg; tickWithId carries the id', () async {
      final tickMsg = await tick(Duration.zero, (t) => TickMsg(t))();
      expect(tickMsg, isA<TickMsg>());
      final everyMsg =
          await every(const Duration(milliseconds: 1), (t) => TickMsg(t))();
      expect(everyMsg, isA<TickMsg>());
      final withId = await tickWithId(Duration.zero, 'z')();
      expect((withId as TickMsg).id, 'z');
    });

    test('control commands return the right message types', () async {
      expect(quit(), isA<QuitMsg>());
      expect(interrupt(), isA<InterruptMsg>());
      expect(suspend(), isA<SuspendMsg>());
      expect(clearScreen(), isA<ClearScreenMsg>());
      expect(enterAltScreen(), isA<EnterAltScreenMsg>());
      expect(exitAltScreen(), isA<ExitAltScreenMsg>());
      expect(hideCursor(), isA<HideCursorMsg>());
      expect(showCursor(), isA<ShowCursorMsg>());
      expect(clearScrollArea(), isA<ClearScrollAreaMsg>());
      expect(requestWindowSize(), isA<RequestWindowSizeMsg>());
      expect(requestTerminalVersion(), isA<RequestTerminalVersionMsg>());
      expect(requestForegroundColor(), isA<RequestForegroundColorMsg>());
      expect(requestBackgroundColor(), isA<RequestBackgroundColorMsg>());
      expect(requestCursorColor(), isA<RequestCursorColorMsg>());
      expect(requestCursorPosition(), isA<RequestCursorPositionMsg>());
      expect(readClipboard(), isA<ReadClipboardMsg>());
      expect(readPrimaryClipboard(), isA<ReadPrimaryClipboardMsg>());
      expect(await setWindowTitle('t')(), isA<SetWindowTitleMsg>());
      expect(await scrollUp(2)(), isA<ScrollMsg>());
      expect(await scrollDown()(), isA<ScrollMsg>());
      expect(await setClipboard('x')(), isA<SetClipboardMsg>());
      expect(await setPrimaryClipboard('x')(), isA<SetPrimaryClipboardMsg>());
      expect(await requestCapability('Smulx')(), isA<RequestCapabilityMsg>());
      expect(await raw('hi')(), isA<RawMsg>());
      expect(await println('hi')(), isA<PrintLineMsg>());
      expect(
          (await printf('a %s', ['b'])() as PrintLineMsg).messageBody, 'a b');
      expect(execProcess('echo', const ['x'])(), isA<ExecMsg>());
    });
  });

  group('msg keystroke/codeName/toString', () {
    test('keystroke joins all modifiers', () {
      const key = TeaKey(code: KeyCode.rune, text: 'a', modifiers: {
        KeyMod.ctrl,
        KeyMod.alt,
        KeyMod.shift,
        KeyMod.meta,
        KeyMod.hyper,
        KeyMod.superKey,
      });
      expect(key.keystroke(), 'ctrl+alt+shift+meta+hyper+super+a');
    });

    test('every KeyCode has a stable name', () {
      for (final c in KeyCode.values) {
        final key = c == KeyCode.rune
            ? const TeaKey(code: KeyCode.rune, text: 'a')
            : TeaKey(code: c);
        expect(key.keystroke(), isNotEmpty);
      }
      expect(const TeaKey(code: KeyCode.rune, text: ' ').toString(), 'space');
      expect(const TeaKey(code: KeyCode.rune, text: 'x').toString(), 'x');
    });

    test('KeyPress/Release toString and Mouse toString', () {
      expect(
          KeyPressMsg(const TeaKey(code: KeyCode.enter)).toString(), 'enter');
      expect(
          KeyReleaseMsg(const TeaKey(code: KeyCode.escape)).toString(), 'esc');
      expect(const Mouse(x: 3, y: 4, button: MouseButton.left).toString(),
          contains('3,4'));
    });

    test('KeyboardEnhancementsMsg flag getters', () {
      final m = KeyboardEnhancementsMsg(kittyReportEventTypes);
      expect(m.supportsKeyDisambiguation, isTrue);
      expect(m.supportsEventTypes, isTrue);
      expect(KeyboardEnhancementsMsg(0).supportsKeyDisambiguation, isFalse);
    });
  });
}
