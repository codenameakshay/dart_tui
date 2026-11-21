import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_tui/src/dev/dev.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('watches source directories created or moved in while dev runs',
      () async {
    final root = Directory.systemTemp.createTempSync('dart_tui_dev_watch');
    addTearDown(() => root.deleteSync(recursive: true));
    final ready = p.join(root.path, 'ready');
    final result = p.join(root.path, 'result');
    final status = p.join(root.path, 'status');
    final registerStatus = p.join(root.path, 'register_status');
    final stop = p.join(root.path, 'stop');
    final app = File(p.join(root.path, 'main.dart'));

    void writeApp(String version) {
      app.writeAsStringSync('''
import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
String version() => '$version';
Future<void> main() async {
  var count = 0;
  developer.registerExtension('ext.dart_tui.reassemble', (method, params) async {
    File(${jsonEncode(result)}).writeAsStringSync('\${++count}:\${version()}');
    return developer.ServiceExtensionResponse.result('{}');
  });
  var statusRegistered = false;
  File(${jsonEncode(ready)}).writeAsStringSync('ready');
  while (!File(${jsonEncode(stop)}).existsSync()) {
    if (!statusRegistered && File(${jsonEncode(registerStatus)}).existsSync()) {
      developer.registerExtension('ext.dart_tui.devStatus', (method, params) async {
        File(${jsonEncode(status)}).writeAsStringSync(params['text'] as String);
        return developer.ServiceExtensionResponse.result('{}');
      });
      statusRegistered = true;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
''');
    }

    Future<void> waitForResult(String expected) async {
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (DateTime.now().isBefore(deadline)) {
        if (File(result).existsSync() &&
            File(result).readAsStringSync() == expected) {
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      fail(
          'Expected $expected, got ${File(result).existsSync() ? File(result).readAsStringSync() : "no result"}');
    }

    writeApp('one');
    final session = DevSession(
      root: root.path,
      file: app.path,
      debounce: const Duration(milliseconds: 20),
    );
    final running = session.run();
    addTearDown(() async {
      File(stop).writeAsStringSync('stop');
      await running;
    });
    final readyDeadline = DateTime.now().add(const Duration(seconds: 10));
    while (
        !File(ready).existsSync() && DateTime.now().isBefore(readyDeadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(File(ready).existsSync(), isTrue);

    final lib = Directory(p.join(root.path, 'lib'));
    lib.createSync();
    Directory(p.join(lib.path, 'created')).createSync();
    File(p.join(lib.path, 'created', 'source.dart'))
        .writeAsStringSync('String value = "one";');
    await waitForResult('1:one');

    Directory(p.join(lib.path, '.ignored')).createSync();
    File(p.join(lib.path, '.ignored', 'source.dart'))
        .writeAsStringSync('String value = "hidden";');
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(File(result).readAsStringSync(), '1:one');
    final hiddenIncoming = Directory(p.join(root.path, 'hidden_incoming'))
      ..createSync();
    File(p.join(hiddenIncoming.path, 'source.dart'))
        .writeAsStringSync('String value = "hidden move";');
    hiddenIncoming.renameSync(p.join(lib.path, '.moved_hidden'));
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(File(result).readAsStringSync(), '1:one');

    final recreated = Directory(p.join(lib.path, 'recreated'))..createSync();
    File(p.join(recreated.path, 'source.dart'))
        .writeAsStringSync('String value = "before deletion";');
    await waitForResult('2:one');
    recreated.deleteSync(recursive: true);
    final replacement = Directory(recreated.path)..createSync();
    File(p.join(replacement.path, 'source.dart'))
        .writeAsStringSync('String value = "after deletion";');
    await waitForResult('3:one');

    final incoming = Directory(p.join(root.path, 'incoming'))..createSync();
    File(p.join(incoming.path, 'source.dart'))
        .writeAsStringSync('String value = "two";');
    final moved = p.join(lib.path, 'moved');
    incoming.renameSync(moved);
    await waitForResult('4:one');

    File(p.join(moved, 'source.dart'))
        .writeAsStringSync('String value = "three";');
    await waitForResult('5:one');

    lib.renameSync(p.join(root.path, 'old_lib'));
    final incomingLib = Directory(p.join(root.path, 'new_lib'))..createSync();
    File(p.join(incomingLib.path, 'source.dart'))
        .writeAsStringSync('String value = "replacement";');
    incomingLib.renameSync(lib.path);
    await waitForResult('6:one');
    File(p.join(lib.path, 'source.dart'))
        .writeAsStringSync('String value = "replacement edited";');
    await waitForResult('7:one');

    final replacementApp = File(p.join(root.path, 'replacement.dart'))
      ..writeAsStringSync(app.readAsStringSync().replaceFirst(
          "String version() => 'one';", "String version() => 'two';"));
    replacementApp.renameSync(app.path);
    await waitForResult('8:two');

    final log = File(p.join(root.path, '.dart_tool', 'dart_tui', 'dev.log'));
    app.writeAsStringSync(app.readAsStringSync().replaceFirst(
        "String version() => 'two';", "String version() => + 'two';"));
    final compileDeadline = DateTime.now().add(const Duration(seconds: 10));
    while (!log.existsSync() && DateTime.now().isBefore(compileDeadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(log.existsSync(), isTrue);
    app.writeAsStringSync(app.readAsStringSync().replaceFirst(
        "String version() => + 'two';", "String version() => 'two';"));
    await waitForResult('9:two');
    File(registerStatus).writeAsStringSync('register');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(File(status).existsSync(), isFalse);

    File(stop).writeAsStringSync('stop');
    expect(await running, 0);
  });
}
