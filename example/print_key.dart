// Show info about each key press.
// Run: fvm dart run example/print_key.dart

import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  await Program(
    options: const ProgramOptions(altScreen: true),
  ).run(PrintKeyModel());
}

final class PrintKeyModel extends TeaModel {
  PrintKeyModel({this.log = const []});

  final List<String> log;

  @override
  Cmd? init() => null;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is KeyMsg) {
      if (msg.key == 'esc' || msg.key == 'ctrl+c') {
        return (this, () => quit());
      }
      final event = msg.keyEvent;
      final code = event.code.name;
      final text = event.text.isEmpty ? '(none)' : event.text;
      final mods = event.modifiers.isEmpty
          ? '(none)'
          : event.modifiers.map((m) => m.name).join(', ');
      final entry = 'key=${msg.key}  code=$code  text=$text  mods=$mods';
      final next = [...log, entry];
      final trimmed = next.length > 10 ? next.sublist(next.length - 10) : next;
      return (PrintKeyModel(log: trimmed), null);
    }
    return (this, null);
  }

  @override
  View view() {
    final b = StringBuffer();
    b.writeln('Key press inspector — press any key · Esc or ctrl+c to quit');
    b.writeln();
    b.writeln('Last 10 events:');
    b.writeln('─' * 60);
    for (final entry in log) {
      b.writeln('  $entry');
    }
    if (log.isEmpty) {
      b.writeln('  (waiting for input...)');
    }
    return newView(b.toString());
  }
}
