// CursorModel bubble — blinking in-line cursor with three shapes.
// Tab to cycle shape, b to toggle blink, q to quit.
// Run: fvm dart run example/cursor_model.dart

import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  await Program(
    options: const ProgramOptions(
      altScreen: true,
      tickInterval: Duration(milliseconds: 500),
    ),
  ).run(_CursorModelDemoModel());
}

final class _CursorModelDemoModel extends TeaModel {
  _CursorModelDemoModel({
    CursorModel? block,
    CursorModel? underline,
    CursorModel? bar,
  })  : block = block ?? CursorModel(mode: CursorMode.block, blink: true),
        underline = underline ?? CursorModel(mode: CursorMode.underline, blink: true),
        bar = bar ?? CursorModel(mode: CursorMode.bar, blink: true);

  final CursorModel block;
  final CursorModel underline;
  final CursorModel bar;

  _CursorModelDemoModel _copyWith({
    CursorModel? block,
    CursorModel? underline,
    CursorModel? bar,
  }) =>
      _CursorModelDemoModel(
        block: block ?? this.block,
        underline: underline ?? this.underline,
        bar: bar ?? this.bar,
      );

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is KeyMsg) {
      switch (msg.key) {
        case 'q':
        case 'ctrl+c':
          return (this, () => quit());
        case 'b':
          // Toggle blink on all cursors
          return (
            _copyWith(
              block: CursorModel(mode: CursorMode.block, blink: !block.blink),
              underline: CursorModel(mode: CursorMode.underline, blink: !block.blink),
              bar: CursorModel(mode: CursorMode.bar, blink: !block.blink),
            ),
            null,
          );
      }
    }

    // Forward TickMsg to each cursor so they blink.
    if (msg is TickMsg) {
      final (b2, _) = block.update(msg);
      final (u2, _) = underline.update(msg);
      final (ba2, _) = bar.update(msg);
      return (
        _copyWith(
          block: b2 as CursorModel,
          underline: u2 as CursorModel,
          bar: ba2 as CursorModel,
        ),
        null,
      );
    }
    return (this, null);
  }

  @override
  View view() {
    final dim = const Style(
      foregroundRgb: RgbColor(88, 91, 112),
      isDim: true,
    );
    final label = const Style(
      foregroundRgb: RgbColor(205, 214, 244),
      isBold: true,
    );

    final b = StringBuffer();
    b.writeln(const Style(
      foregroundRgb: RgbColor(203, 166, 247),
      isBold: true,
    ).render('  CursorModel bubble'));
    b.writeln();

    b.write('  Block     ');
    b.write(label.render('hello'));
    b.write(block.view().content);
    b.write(label.render('world'));
    b.write(dim.render('  (block)'));
    b.writeln();

    b.write('  Underline ');
    b.write(label.render('hello'));
    b.write(underline.view().content);
    b.write(label.render('world'));
    b.write(dim.render('  (underline)'));
    b.writeln();

    b.write('  Bar       ');
    b.write(label.render('hello'));
    b.write(bar.view().content);
    b.write(label.render('world'));
    b.write(dim.render('  (bar)'));
    b.writeln();

    b.writeln();
    final blinkState = block.blink ? 'ON' : 'OFF';
    b.writeln(dim.render('  Blink: $blinkState'));
    b.writeln();
    b.write(dim.render('  b toggle blink · q quit'));
    return newView(b.toString());
  }
}
