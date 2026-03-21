import '../cmd.dart';
import '../model.dart';
import '../msg.dart';
import '../view.dart';

/// Countdown timer bubble. Driven by [TickMsg] (optionally filtered by [id]).
final class TimerModel extends TeaModel {
  TimerModel({
    required this.duration,
    this.elapsed = Duration.zero,
    this.running = false,
    this.lastTick,
    this.id,
  });

  final Duration duration;
  final Duration elapsed;
  final bool running;
  final DateTime? lastTick;

  /// Optional discriminator — only [TickMsg]s with a matching [id] advance
  /// this timer. Set to `null` to respond to all tick messages.
  final Object? id;

  Duration get remaining => duration - elapsed;
  bool get finished => elapsed >= duration;

  TimerModel copyWith({
    Duration? duration,
    Duration? elapsed,
    bool? running,
    DateTime? lastTick,
    Object? id,
    bool clearLastTick = false,
  }) =>
      TimerModel(
        duration: duration ?? this.duration,
        elapsed: elapsed ?? this.elapsed,
        running: running ?? this.running,
        lastTick: clearLastTick ? null : (lastTick ?? this.lastTick),
        id: id ?? this.id,
      );

  TimerModel start() => copyWith(running: true);
  TimerModel stop() => copyWith(running: false);
  TimerModel reset() =>
      copyWith(elapsed: Duration.zero, clearLastTick: true, running: false);

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is TickMsg) {
      if (id != null && msg.id != id) return (this, null);
      if (!running || finished) return (this, null);
      final last = lastTick ?? msg.when;
      final delta = msg.when.difference(last);
      final newElapsed = elapsed + delta;
      return (
        copyWith(
          elapsed: newElapsed > duration ? duration : newElapsed,
          lastTick: msg.when,
        ),
        null,
      );
    }
    return (this, null);
  }

  @override
  View view() {
    final rem = remaining;
    final minutes = rem.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = rem.inSeconds.remainder(60).toString().padLeft(2, '0');
    return newView('$minutes:$seconds${finished ? ' ✓' : ''}');
  }
}
