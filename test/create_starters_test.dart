// Makes each `dart_tui create` starter against this checkout, then runs its
// `dart pub get`, `dart analyze --fatal-infos` and `dart test`.
//
// Slow (pub get and a test run per starter), so it is skipped by default.
// Run it with:  dart test -P starters
@Tags(['starters'])
library;

import 'dart:io';

import 'package:dart_tui/cli.dart';
import 'package:dart_tui/src/create/create.dart';
import 'package:dart_tui/testing.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  for (final starter in starters.keys) {
    test('the $starter starter gets, analyzes and tests clean', () async {
      final tmp = Directory.systemTemp.createTempSync('dart_tui_$starter');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final root = p.join(tmp.path, 'starter_$starter');
      final out = CaptureSink();
      final created = await DartTuiRunner(
          logger: Logger(stdout: out, stderr: out, environment: const {})).run([
        'create', root, '-t', starter, '--no-git', '--no-pub-get', //
      ]);
      expect(created, 0, reason: out.text);

      // Use this checkout instead of the published dart_tui.
      File(p.join(root, 'pubspec.yaml')).writeAsStringSync(
        'dependency_overrides:\n'
        '  dart_tui:\n'
        '    path: ${p.current.replaceAll(r'\', '/')}\n',
        mode: FileMode.append,
      );
      for (final args in [
        ['pub', 'get'],
        ['analyze', '--fatal-infos'],
        ['test'],
      ]) {
        final r = await Process.run(Platform.resolvedExecutable, args,
            workingDirectory: root);
        expect(r.exitCode, 0,
            reason: 'dart ${args.join(' ')} in $starter:\n'
                '${r.stdout}\n${r.stderr}');
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
}
