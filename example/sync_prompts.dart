// Sync prompts: the four one-shot prompts without async. For code that is
// already synchronous, such as helpers that wrap `prompts` or `interact`.
//   dart run example/sync_prompts.dart          (terminal UI)
//   dart run example/sync_prompts.dart | cat    (plain line questions)

import 'dart:io';

import 'package:dart_tui/dart_tui.dart';

void main() {
  final name = promptInputSync('Project name?', defaultValue: 'my_app');
  if (name == null) return; // Esc
  final template = promptSelectSync(
    const ['cli', 'server', 'package'],
    title: 'Template?',
  );
  if (template == null) return;
  final features = promptMultiSelectSync(
    const ['tests', 'lints', 'ci', 'docker'],
    title: 'Features?',
    initial: const {0, 1},
  );
  if (features == null) return;
  final token = promptInputSync('Publish token?', hidden: true);
  if (token == null) return;
  if (promptConfirmSync('Create $name?', defaultValue: true) != true) {
    stdout.writeln('Cancelled.');
    return;
  }
  stdout.writeln(
    'Created $name ($template) with ${features.join(', ')}; '
    'token has ${token.length} characters.',
  );
}
