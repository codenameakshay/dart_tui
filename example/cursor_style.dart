// Demonstrate cursor shape and blink settings as text description.
// Run: fvm dart run example/cursor_style.dart

import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  await Program(
    options: const ProgramOptions(altScreen: true),
  ).run(CursorStyleModel());
}

final class CursorStyleModel extends TeaModel {
  CursorStyleModel({
    this.shapeIndex = 0,
    this.blink = true,
  });

  final int shapeIndex;
  final bool blink;

  static const _shapes = [
    CursorShape.block,
    CursorShape.underline,
    CursorShape.bar,
  ];

  CursorShape get shape => _shapes[shapeIndex];

  @override
  Cmd? init() => null;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is! KeyMsg) return (this, null);
    switch (msg.key) {
      case 'left':
        final next = (shapeIndex - 1 + _shapes.length) % _shapes.length;
        return (CursorStyleModel(shapeIndex: next, blink: blink), null);
      case 'right':
        final next = (shapeIndex + 1) % _shapes.length;
        return (CursorStyleModel(shapeIndex: next, blink: blink), null);
      case 'space':
        return (CursorStyleModel(shapeIndex: shapeIndex, blink: !blink), null);
      case 'q':
      case 'ctrl+c':
        return (this, () => quit());
    }
    return (this, null);
  }

  @override
  View view() {
    final shapeName = shape.name;
    final blinkStatus = blink ? 'ON' : 'OFF';
    final b = StringBuffer();
    b.writeln('Cursor style demo');
    b.writeln();
    b.writeln('  Shape : $shapeName');
    b.writeln('  Blink : $blinkStatus');
    b.writeln();
    b.writeln('  Available shapes:');
    for (var i = 0; i < _shapes.length; i++) {
      final marker = i == shapeIndex ? '>' : ' ';
      b.writeln('    $marker ${_shapes[i].name}');
    }
    b.writeln();
    b.write('Left/Right to cycle shape · Space to toggle blink · q to quit');
    return newView(b.toString());
  }
}
