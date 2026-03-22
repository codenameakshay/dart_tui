import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

void main() {
  group('TimerModel', () {
    test('does not advance when not running', () {
      final timer = TimerModel(duration: const Duration(seconds: 10));
      final (next, _) = timer.update(TickMsg(DateTime.now()));
      expect((next as TimerModel).elapsed, Duration.zero);
    });

    test('advances elapsed when running', () {
      final start = DateTime(2024, 1, 1, 0, 0, 0);
      final later = start.add(const Duration(seconds: 3));
      final timer = TimerModel(
        duration: const Duration(seconds: 10),
        running: true,
        lastTick: start,
      );
      final (next, _) = timer.update(TickMsg(later));
      expect((next as TimerModel).elapsed, const Duration(seconds: 3));
    });

    test('clamps elapsed at duration', () {
      final start = DateTime(2024, 1, 1);
      // ignore: non_constant_identifier_names
      final way_later = start.add(const Duration(seconds: 100));
      final timer = TimerModel(
        duration: const Duration(seconds: 5),
        running: true,
        lastTick: start,
      );
      final (next, _) = timer.update(TickMsg(way_later));
      expect((next as TimerModel).elapsed, const Duration(seconds: 5));
      expect((next).finished, isTrue);
    });

    test('ignores TickMsg with wrong id', () {
      final start = DateTime(2024, 1, 1);
      final later = start.add(const Duration(seconds: 2));
      final timer = TimerModel(
        duration: const Duration(seconds: 10),
        running: true,
        lastTick: start,
        id: 'timer-1',
      );
      final (next, _) = timer.update(TickMsg(later, id: 'timer-2'));
      expect((next as TimerModel).elapsed, Duration.zero);
    });

    test('remaining is correct', () {
      final timer = TimerModel(
        duration: const Duration(seconds: 10),
        elapsed: const Duration(seconds: 3),
      );
      expect(timer.remaining, const Duration(seconds: 7));
    });
  });

  group('StopwatchModel', () {
    test('advances when running', () {
      final start = DateTime(2024, 1, 1);
      final later = start.add(const Duration(milliseconds: 500));
      final sw = StopwatchModel(running: true, lastTick: start);
      final (next, _) = sw.update(TickMsg(later));
      expect(
          (next as StopwatchModel).elapsed, const Duration(milliseconds: 500));
    });

    test('does not advance when stopped', () {
      final sw = StopwatchModel();
      final (next, _) = sw.update(TickMsg(DateTime.now()));
      expect((next as StopwatchModel).elapsed, Duration.zero);
    });

    test('reset clears elapsed', () {
      final sw = StopwatchModel(
        elapsed: const Duration(seconds: 5),
        running: true,
      );
      final reset = sw.reset();
      expect(reset.elapsed, Duration.zero);
      expect(reset.running, isFalse);
    });
  });
}
