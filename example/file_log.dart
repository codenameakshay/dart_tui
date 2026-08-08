// FileLog: write diagnostics to a file while the TUI runs (print() would
// corrupt the rendered screen). `tail -f dart_tui_example.log` in another shell.
//   dart run example/file_log.dart

import 'dart:io';

import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  const path = 'dart_tui_example.log';
  final log = FileLog(path);
  await Program(
    options: const ProgramOptions(altScreen: true),
  ).run(LogDemo(log, path));
  await log.close();
  stdout.writeln('Key log written to $path');
}

final class LogDemo extends TeaModel {
  LogDemo(this.log, this.path, {this.count = 0});

  final FileLog log;
  final String path;
  final int count;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is KeyMsg) {
      if (msg.key == 'q' || msg.key == 'ctrl+c') return (this, () => quit());
      final n = count + 1;
      final key = msg.key;
      // Log from a command (a side effect that yields no message).
      return (
        LogDemo(log, path, count: n),
        () {
          log('key #$n: $key');
          return null;
        },
      );
    }
    return (this, null);
  }

  @override
  View view() {
    const mauve = Style(foregroundRgb: RgbColor(203, 166, 247), isBold: true);
    const dim = Style(foregroundRgb: RgbColor(108, 112, 134));
    const text = Style(foregroundRgb: RgbColor(205, 214, 244));

    final b = StringBuffer()
      ..writeln(mauve.render('FileLog'))
      ..writeln()
      ..writeln(text.render('Keys logged: $count'))
      ..writeln(dim.render('Writing to $path — tail -f it in another terminal'))
      ..writeln()
      ..write(dim.render('press any key to log it · q quit'));
    return newView(b.toString());
  }
}
