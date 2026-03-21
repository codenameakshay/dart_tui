// Mouse event logger with allMotion mode.
// Run: fvm dart run example/mouse.dart

import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  await Program(
    options: const ProgramOptions(altScreen: true),
  ).run(MouseModel());
}

final class MouseModel extends TeaModel {
  MouseModel({this.events = const []});

  final List<String> events;

  @override
  Cmd? init() => null;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is KeyMsg && (msg.key == 'q' || msg.key == 'ctrl+c')) {
      return (this, () => quit());
    }
    if (msg is MouseMsg) {
      final m = msg.mouse;
      final type = switch (msg) {
        MouseClickMsg() => 'click',
        MouseReleaseMsg() => 'release',
        MouseWheelMsg() => 'wheel',
        MouseMotionMsg() => 'motion',
        _ => 'unknown',
      };
      final entry = '$type  btn=${m.button.name}  x=${m.x}  y=${m.y}';
      final next = [...events, entry];
      final trimmed = next.length > 5 ? next.sublist(next.length - 5) : next;
      return (MouseModel(events: trimmed), null);
    }
    return (this, null);
  }

  @override
  View view() {
    final v = View(
      mouseMode: MouseMode.allMotion,
      content: _buildContent(),
    );
    return v;
  }

  String _buildContent() {
    final b = StringBuffer();
    b.writeln('Mouse event logger — move mouse or click · q to quit');
    b.writeln();
    b.writeln('Last 5 events:');
    b.writeln('─' * 50);
    for (final entry in events) {
      b.writeln('  $entry');
    }
    if (events.isEmpty) {
      b.writeln('  (move mouse to see events...)');
    }
    return b.toString();
  }
}
