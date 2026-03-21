import '../cmd.dart';
import '../model.dart';
import '../msg.dart';
import '../view.dart';

/// Elapsed-time stopwatch bubble. Driven by [TickMsg].
final class StopwatchModel extends TeaModel {
  StopwatchModel({
    this.elapsed = Duration.zero,
    this.running = false,
    this.lastTick,
    this.id,
  });

  final Duration elapsed;
  final bool running;
  final DateTime? lastTick;
  final Object? id;

  StopwatchModel copyWith({
    Duration? elapsed,
    bool? running,
    DateTime? lastTick,
    Object? id,
    bool clearLastTick = false,
  }) =>
      StopwatchModel(
        elapsed: elapsed ?? this.elapsed,
        running: running ?? this.running,
        lastTick: clearLastTick ? null : (lastTick ?? this.lastTick),
        id: id ?? this.id,
      );

  StopwatchModel start() => copyWith(running: true);
  StopwatchModel stop() => copyWith(running: false);
  StopwatchModel reset() => copyWith(elapsed: Duration.zero, clearLastTick: true, running: false);

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is TickMsg) {
      if (id != null && msg.id != id) return (this, null);
      if (!running) return (this, null);
      final last = lastTick ?? msg.when;
      final delta = msg.when.difference(last);
      return (copyWith(elapsed: elapsed + delta, lastTick: msg.when), null);
    }
    return (this, null);
  }

  @override
  View view() {
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    final millis = (elapsed.inMilliseconds.remainder(1000) ~/ 10)
        .toString()
        .padLeft(2, '0');
    return newView('$minutes:$seconds.$millis');
  }
}
