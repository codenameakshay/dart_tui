// Run: fvm dart run example/paginator.dart
// PaginatorModel with dot indicator. Left/right to navigate, q to quit.

import 'package:dart_tui/dart_tui.dart';

const _pages = [
  'Page 1: Welcome to dart_tui!\n\n  This is a terminal UI framework for Dart.',
  'Page 2: Models\n\n  Implement init(), update(), and view().',
  'Page 3: Commands\n\n  Return Cmd? from update() to trigger side effects.',
  'Page 4: Messages\n\n  Every event is a Msg — keys, ticks, window size...',
  'Page 5: Bubbles\n\n  Reusable widgets: spinner, progress, list, table...',
];

String _dotLabel(int page, int total) {
  final buf = StringBuffer();
  for (var i = 0; i < total; i++) {
    buf.write(i == page ? '● ' : '○ ');
  }
  return buf.toString().trimRight();
}

Future<void> main() async {
  await Program().run(PaginatorExampleModel());
}

final class PaginatorExampleModel extends TeaModel {
  PaginatorExampleModel({PaginatorModel? paginator})
      : paginator = paginator ??
            PaginatorModel(
              page: 0,
              totalPages: _pages.length,
              labelBuilder: _dotLabel,
            );

  final PaginatorModel paginator;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is KeyMsg) {
      switch (msg.key) {
        case 'q':
        case 'ctrl+c':
          return (this, () => quit());
      }
      final (updated, cmd) = paginator.update(msg);
      return (
        PaginatorExampleModel(paginator: updated as PaginatorModel),
        cmd,
      );
    }
    return (this, null);
  }

  @override
  View view() {
    final p = paginator.safePage;
    final b = StringBuffer();
    b.writeln(_pages[p]);
    b.writeln();
    b.writeln(paginator.view().content);
    b.writeln('\nLeft/right to navigate, q to quit.');
    return newView(b.toString());
  }
}
