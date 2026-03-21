// Runs promptSelect → promptConfirm → promptInput in sequence (each run uses Program).
//   dart run example/prompts_chain.dart

import 'dart:io';

import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  stdout.writeln('Prompts chain demo (detailed).');
  stdout.writeln(
    'Each prompt opens its own Program; null means user cancelled the prompt.\n',
  );

  final flavor = await promptSelect(
    const ['Vanilla', 'Chocolate', 'Strawberry'],
    title: 'Favorite ice cream',
    options: const ProgramOptions(altScreen: true),
  );
  stdout.writeln('Selected: $flavor');

  final ok = await promptConfirm(
    'Ship to production?',
    options: const ProgramOptions(altScreen: true),
  );
  stdout.writeln('Confirmed: $ok');

  final note = await promptInput(
    'Notes: ',
    options: const ProgramOptions(altScreen: true),
  );
  stdout.writeln('Notes: $note');

  stdout.writeln('\nSummary:');
  stdout.writeln('  flavor = $flavor');
  stdout.writeln('  confirmed = $ok');
  stdout.writeln('  notes = $note');
  stdout.writeln('\nDone.');
}
