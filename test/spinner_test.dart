import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

KeyPressMsg _key(String ch) =>
    KeyPressMsg(TeaKey(code: KeyCode.rune, text: ch));

void main() {
  group('SpinnerModel', () {
    test('initial frame is first frame', () {
      final s = SpinnerModel();
      expect(s.index, 0);
    });

    test('update on TickMsg advances frame', () {
      final s = SpinnerModel();
      final (next, _) = s.update(TickMsg(DateTime.now()));
      final n = next as SpinnerModel;
      expect(n.index, 1);
    });

    test('frame wraps around after last frame', () {
      final frames = ['A', 'B', 'C'];
      var s = SpinnerModel(frames: frames, index: 2);
      final (next, _) = s.update(TickMsg(DateTime.now()));
      final n = next as SpinnerModel;
      expect(n.index, 0);
    });

    test('non-TickMsg does not change state', () {
      final s = SpinnerModel();
      final (next, _) = s.update(_key('q'));
      expect(identical(s, next), isTrue);
    });

    test('view renders current frame', () {
      final s = SpinnerModel(frames: ['X', 'Y'], index: 0);
      expect(s.view().content, contains('X'));
    });

    test('view renders prefix and suffix', () {
      final s = SpinnerModel(
        frames: ['*'],
        index: 0,
        prefix: 'PRE',
        suffix: 'SUF',
      );
      final content = s.view().content;
      expect(content, contains('PRE'));
      expect(content, contains('SUF'));
    });

    test('empty frames renders space between prefix and suffix', () {
      final s = SpinnerModel(frames: [], prefix: 'A', suffix: 'B');
      expect(s.view().content, contains('A'));
      expect(s.view().content, contains('B'));
    });

    test('update on TickMsg preserves prefix/suffix', () {
      final s = SpinnerModel(prefix: 'Loading', suffix: '...');
      final (next, _) = s.update(TickMsg(DateTime.now()));
      final n = next as SpinnerModel;
      expect(n.prefix, 'Loading');
      expect(n.suffix, '...');
    });

    test('update preserves spinner configuration and the previous state', () {
      final frames = ['A', 'B'];
      final spinner = Spinner(frames, Duration.zero);
      const styles = SpinnerStyles(frame: Style(isBold: true));
      final s = SpinnerModel(
        spinner: spinner,
        prefix: 'Loading',
        suffix: '...',
        styles: styles,
        id: 'loading',
      );
      final (next, _) = s.update(TickMsg(DateTime.now(), id: 'loading'));
      final n = next as SpinnerModel;
      expect(n.prefix, 'Loading');
      expect(n.suffix, '...');
      expect(n.spinner, same(spinner));
      expect(n.frames, same(frames));
      expect(n.styles, same(styles));
      expect(n.id, 'loading');
      expect(n.index, 1);
      expect(s.index, 0);
    });

    test('duplicate initial seeds leave only the newest chain live', () async {
      const spinner = Spinner(['A', 'B', 'C', 'D'], Duration.zero);
      final initial = SpinnerModel(id: 'a', spinner: spinner);
      final first = await initial.tick()();
      final second = await initial.tick()();
      final (running, staleCommand) = initial.update(first!);
      final (restarted, liveCommand) = running.update(second!);
      expect((restarted as SpinnerModel).index, 2);
      final (unchanged, ignored) = restarted.update((await staleCommand!())!);
      expect(unchanged, same(restarted));
      expect(ignored, isNull);
      final (advanced, successor) = restarted.update((await liveCommand!())!);
      expect((advanced as SpinnerModel).index, 3);
      expect(successor, isNotNull);
      final (wrapped, next) = advanced.update((await successor!())!);
      expect((wrapped as SpinnerModel).index, 0);
      expect(next, isNotNull);
    });

    test('duplicate tick seeds from a running model leave one live chain',
        () async {
      const spinner = Spinner(['A', 'B', 'C'], Duration.zero);
      final initial = SpinnerModel(id: 'a', spinner: spinner);
      final (running, pending) = initial.update((await initial.tick()())!);
      final seed1 = await (running as SpinnerModel).tick()();
      final seed2 = await running.tick()();
      final (restarted, live) = running.update(seed1!);
      final (unchanged, duplicate) = restarted.update(seed2!);
      expect(unchanged, same(restarted));
      expect(duplicate, isNull);
      final (stillRestarted, stale) = restarted.update((await pending!())!);
      expect(stillRestarted, same(restarted));
      expect(stale, isNull);
      final (advanced, successor) = restarted.update((await live!())!);
      expect((advanced as SpinnerModel).index, 0);
      expect(successor, isNotNull);
      expect(running.index, 1);
    });

    test('an untagged tick replaces a pending chain without killing it',
        () async {
      const spinner = Spinner(['A', 'B', 'C', 'D'], Duration.zero);
      final initial = SpinnerModel(id: 'a', spinner: spinner);
      final (running, pending) = initial.update((await initial.tick()())!);
      final (restarted, live) =
          running.update(TickMsg(DateTime.now(), id: 'a'));
      expect((restarted as SpinnerModel).index, 2);
      final (unchanged, stale) = restarted.update((await pending!())!);
      expect(unchanged, same(restarted));
      expect(stale, isNull);
      final (advanced, successor) = restarted.update((await live!())!);
      expect((advanced as SpinnerModel).index, 3);
      expect(successor, isNotNull);
      final (wrapped, next) = advanced.update((await successor!())!);
      expect((wrapped as SpinnerModel).index, 0);
      expect(next, isNotNull);
    });

    test('empty frames stop an active chain and reject new seeds', () async {
      final frames = ['A', 'B'];
      final initial = SpinnerModel(
        id: 'a',
        spinner: Spinner(frames, Duration.zero),
      );
      final (running, pending) = initial.update((await initial.tick()())!);
      frames.clear();
      final (stopped, successor) = running.update((await pending!())!);
      expect(stopped, same(running));
      expect(successor, isNull);
      final (stillStopped, restarted) =
          stopped.update((await (stopped as SpinnerModel).tick()())!);
      expect(stillStopped, same(stopped));
      expect(restarted, isNull);
    });

    test('changing the id rejects the old chain and starts the new one',
        () async {
      const spinner = Spinner(['A', 'B', 'C'], Duration.zero);
      final initial = SpinnerModel(id: 'a', spinner: spinner);
      final (running, oldTick) = initial.update((await initial.tick()())!);
      final replacement = SpinnerModel(
        id: 'b',
        spinner: spinner,
        index: (running as SpinnerModel).index,
      );
      final (unchanged, ignored) = replacement.update((await oldTick!())!);
      expect(unchanged, same(replacement));
      expect(ignored, isNull);
      final (advanced, successor) =
          replacement.update((await replacement.tick()())!);
      expect((advanced as SpinnerModel).index, 2);
      expect(advanced.id, 'b');
      final nextTick = await successor!() as TickMsg;
      expect(nextTick.id, 'b');
      final (wrapped, next) = advanced.update(nextTick);
      expect((wrapped as SpinnerModel).index, 0);
      expect(next, isNotNull);
    });
  });
}
