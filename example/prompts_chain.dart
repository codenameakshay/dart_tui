// Runs promptSelect → promptConfirm → promptInput in sequence (each run uses Program).
//   dart run example/prompts_chain.dart

import 'dart:io';

import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  stdout.writeln('Prompts chain demo (each opens its own Program).\n');

  final flavor = await promptSelect(
    const ['Vanilla', 'Chocolate', 'Strawberry'],
    title: 'Favorite ice cream',
  );
  stdout.writeln('Selected: $flavor');

  final ok = await promptConfirm('Ship to production?');
  stdout.writeln('Confirmed: $ok');

  final note = await promptInput('Notes: ');
  stdout.writeln('Notes: $note');

  stdout.writeln('\nDone.');
}
