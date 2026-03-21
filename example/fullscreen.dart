// Run: fvm dart run example/fullscreen.dart
// Fullscreen alt-screen countdown. Exits after 5 seconds (or press q).

import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  await Program(
    options: const ProgramOptions(altScreen: true),
  ).run(FullscreenModel());
}

final class _TickMsg extends Msg {}

final class FullscreenModel extends TeaModel {
  FullscreenModel({this.seconds = 5});

  final int seconds;

  @override
  Cmd? init() => tick(const Duration(seconds: 1), (_) => _TickMsg());

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is _TickMsg) {
      final next = seconds - 1;
      if (next <= 0) {
        return (FullscreenModel(seconds: 0), () => quit());
      }
      return (
        FullscreenModel(seconds: next),
        tick(const Duration(seconds: 1), (_) => _TickMsg()),
      );
    }
    if (msg is KeyMsg) {
      switch (msg.key) {
        case 'q':
        case 'ctrl+c':
          return (this, () => quit());
      }
    }
    return (this, null);
  }

  @override
  View view() {
    final v = View(
      content: '\n\n    Exiting in $seconds second${seconds == 1 ? '' : 's'}...'
          '\n\n    Press q to quit early.',
      altScreen: true,
    );
    return v;
  }
}
