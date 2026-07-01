import 'dart:io';

import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

void main() {
  test('FileLog appends timestamped lines', () async {
    final dir = Directory.systemTemp.createTempSync('log_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/app.log';

    final log = FileLog(path, clock: () => DateTime.utc(2020, 1, 2, 3, 4, 5));
    log('hello');
    log('world');
    await log.close();

    final content = File(path).readAsStringSync();
    expect(content, contains('hello'));
    expect(content, contains('world'));
    expect(content, contains('2020-01-02'));
    expect(content.trim().split('\n'), hasLength(2));
  });

  test('FileLog append mode preserves earlier content', () async {
    final dir = Directory.systemTemp.createTempSync('log_test2');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/app.log';

    var log = FileLog(path);
    log('first');
    await log.close();
    log = FileLog(path);
    log('second');
    await log.close();

    final content = File(path).readAsStringSync();
    expect(content, contains('first'));
    expect(content, contains('second'));
  });

  test('FileLog.none discards silently', () async {
    final log = FileLog.none();
    log('ignored');
    await log.close();
    expect(true, isTrue); // no throw, no file
  });
}
