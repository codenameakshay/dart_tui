// Read-only Gmail TUI client backed by the `gws` CLI.
// Requires `gws` to be installed and authenticated.
// Run: dart run example/gmail/main.dart
//
// Keys:
//   j/k or ↑/↓    move selection
//   h/l           switch tabs (Inbox/Unread/Starred/Important/Sent)
//   1-5           jump to tab by number
//   /             focus search (Gmail query syntax)
//   esc           cancel search / return to Inbox from a search view
//   ] / [         next / previous page
//   tab           toggle focus list ↔ message
//   enter         focus message pane
//   g / G         scroll body top / bottom (when message focused)
//   r             retry last failed op
//   q, ctrl+c     quit
//
// Mouse:
//   click tab     switch tab
//   click row     select message
//   wheel         scroll list or message (hover-routed)

import 'package:dart_tui/dart_tui.dart';

import 'app/model.dart';

Future<void> main() async {
  await Program(
    options: const ProgramOptions(
      altScreen: true,
      tickInterval: Duration(milliseconds: 100),
    ),
  ).run(AppModel());
}
