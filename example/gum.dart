// gum-style one-shot helpers: filter → spin → pager, each its own Program.
//   fvm dart run example/gum.dart

import 'dart:io';

import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  stdout.writeln('gum helpers demo — type to filter, Enter to pick.\n');

  // 1) filter: interactive fuzzy picker.
  final choice = await filter(
    const ['Cloudflare', 'Fastly', 'Vercel', 'Netlify', 'Render'],
    title: 'Deploy target',
    programSettings: const ProgramOptions(altScreen: true),
  );
  if (choice == null) {
    stdout.writeln('Cancelled.');
    return;
  }
  stdout.writeln('Picked: $choice');

  // 2) spin: run a spinner while awaiting a Future, return its result.
  final status = await spin(
    Future<String>.delayed(
      const Duration(seconds: 2),
      () => 'deployed to $choice',
    ),
    label: 'Deploying to $choice…',
    programSettings: const ProgramOptions(altScreen: true),
  );
  stdout.writeln('Result: $status');

  // 3) pager: scrollable viewer (q/Esc to exit).
  final log = List.generate(60, (i) => 'build step ${i + 1} … ok').join('\n');
  await pager(
    'Deploy log for $choice\n\n$log',
    programSettings: const ProgramOptions(altScreen: true),
  );

  stdout.writeln('\nDone.');
}
