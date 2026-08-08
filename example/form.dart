// A huh-style form: input + select + confirm, with a dynamic wizard page that
// only appears when "Deploy now?" is Yes.
//   dart run example/form.dart

import 'dart:io';

import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  final form = Form([
    Group([
      Field.input(
          key: 'name',
          title: 'Service name',
          validate: (v) => v.contains(' ') ? 'no spaces allowed' : null),
      Field.select(
          key: 'runtime',
          title: 'Runtime',
          options: ['Dart', 'Go', 'Node'],
          initial: 'Dart'),
      Field.confirm(key: 'deploy', title: 'Deploy now?', initial: true),
    ], title: 'Basics'),
    Group([
      Field.multiSelect(
          key: 'regions', title: 'Regions', options: ['iad', 'fra', 'sfo']),
      Field.note(title: 'Review', description: 'Press enter to submit.'),
    ], title: 'Deploy', hidden: (v) => v.get<bool>('deploy') != true),
  ]);

  final values = await form.run(options: [withAltScreen()]);

  if (values == null) {
    stdout.writeln('Cancelled.');
    return;
  }
  stdout.writeln('name    = ${values.get<String>('name')}');
  stdout.writeln('runtime = ${values.get<String>('runtime')}');
  stdout.writeln('deploy  = ${values.get<bool>('deploy')}');
  stdout.writeln('regions = ${values.get<List<String>>('regions')}');
}
