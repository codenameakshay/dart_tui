// Spring-eased marker: press ←/→ (or h/l) to move the target; the dot springs
// toward it with a bouncy, under-damped motion.
//   dart run example/spring.dart

import 'dart:math' as math;

import 'package:dart_tui/dart_tui.dart';

const _width = 44;

Future<void> main() async {
  await Program(
    options: [
      withAltScreen(),
      withTickInterval(const Duration(milliseconds: 16)),
    ],
  ).run(SpringDemo());
}

final class SpringDemo extends Model {
  SpringDemo({Spring? spring, this.target = 0, this.pos = 0, this.vel = 0})
      : spring = spring ?? Spring(fps: 60, frequency: 4, damping: 0.5);

  final Spring spring;
  final double target;
  final double pos;
  final double vel;

  SpringDemo _copy({double? target, double? pos, double? vel}) => SpringDemo(
        spring: spring,
        target: target ?? this.target,
        pos: pos ?? this.pos,
        vel: vel ?? this.vel,
      );

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is TickMsg) {
      final (p, v) = spring.update(pos, vel, target);
      return (_copy(pos: p, vel: v), null);
    }
    if (msg is KeyMsg) {
      switch (msg.key) {
        case 'left':
        case 'h':
          return (_copy(target: math.max(0, target - 8)), null);
        case 'right':
        case 'l':
          return (_copy(target: math.min(_width.toDouble(), target + 8)), null);
        case 'q':
        case 'ctrl+c':
          return (this, () => quit());
      }
    }
    return (this, null);
  }

  @override
  View view() {
    const mauve = Style(foregroundRgb: RgbColor(203, 166, 247), isBold: true);
    const dim = Style(foregroundRgb: RgbColor(108, 112, 134));
    const green = Style(foregroundRgb: RgbColor(166, 227, 161));

    final markerAt = pos.round().clamp(0, _width);
    final targetAt = target.round().clamp(0, _width);
    final cells = List<String>.filled(_width + 1, dim.render('·'));
    cells[targetAt] = dim.render('┆');
    cells[markerAt] = green.render('●');

    final b = StringBuffer()
      ..writeln(mauve.render('Spring animation'))
      ..writeln()
      ..writeln(cells.join())
      ..writeln()
      ..writeln(dim.render('pos ${pos.toStringAsFixed(1)}   '
          'vel ${vel.toStringAsFixed(1)}   target ${target.toStringAsFixed(0)}'))
      ..writeln()
      ..write(dim.render('←/→ or h/l move target · q quit'));
    return newView(b.toString());
  }
}
