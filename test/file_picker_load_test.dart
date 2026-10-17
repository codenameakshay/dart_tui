import 'dart:io';

import 'package:dart_tui/dart_tui.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('directory loading is asynchronous and stale results are ignored',
      () async {
    final firstDir = await Directory.systemTemp.createTemp('picker_first_');
    final secondDir = await Directory.systemTemp.createTemp('picker_second_');
    addTearDown(() => Future.wait([
          firstDir.delete(recursive: true),
          secondDir.delete(recursive: true),
        ]));

    final old = FilePickerModel(currentDir: firstDir.path);
    final oldCmd = old.init()!;
    final oldResultFuture = oldCmd();
    expect(oldResultFuture, isA<Future<Msg?>>());
    final newerResultFuture = old.init()!();

    final newerResult = await newerResultFuture;
    final (newerLoaded, _) = old.update(newerResult!);
    expect((newerLoaded as FilePickerModel).loading, isFalse);

    final current = old.copyWith(currentDir: secondDir.path);
    final oldResult = await oldResultFuture;
    final (unchangedOld, _) = newerLoaded.update(oldResult!);
    expect(identical(unchangedOld, newerLoaded), isTrue);
    final (unchanged, _) = current.update(oldResult);
    expect(identical(unchanged, current), isTrue);

    final currentResult = await current.init()!();
    final (loadedCurrent, _) = current.update(currentResult!);
    expect((loadedCurrent as FilePickerModel).loading, isFalse);
    expect(loadedCurrent.currentDir, secondDir.path);

    final other = FilePickerModel(currentDir: secondDir.path);
    final otherResult = await other.init()!();
    final (isolated, _) = current.update(otherResult!);
    expect(identical(isolated, current), isTrue);

    final cursorCopy = old.copyWith(cursor: 0);
    final cursorResult = await old.init()!();
    final (loaded, _) = cursorCopy.update(cursorResult!);
    expect((loaded as FilePickerModel).loading, isFalse);

    final filtered = old.copyWith(showHidden: true);
    final filteredCmd = filtered.init()!;
    final newerSameDirectory = filtered.copyWith(showHidden: false);
    final stale = await filteredCmd();
    final (stillNewer, _) = newerSameDirectory.update(stale!);
    expect(identical(stillNewer, newerSameDirectory), isTrue);
  });

  test('keys are ignored while a directory loads', () async {
    final root = await Directory.systemTemp.createTemp('picker_keys_');
    addTearDown(() => root.delete(recursive: true));
    final sub = await Directory(p.join(root.path, 'sub')).create();
    await File('${root.path}/zfile.txt').writeAsString('x');
    await File('${sub.path}/inner.txt').writeAsString('x');

    KeyMsg key(KeyCode c) => KeyPressMsg(TeaKey(code: c));
    var m = FilePickerModel(currentDir: root.path);
    m = m.update((await m.init()!())!).$1 as FilePickerModel;
    expect(m.entries.first, isA<Directory>());

    final (entered, cmd) = m.update(key(KeyCode.enter));
    var picker = entered as FilePickerModel;
    expect(picker.currentDir, sub.path);
    expect(picker.loading, isTrue);

    picker = picker.update(key(KeyCode.down)).$1 as FilePickerModel;
    picker = picker.update(key(KeyCode.enter)).$1 as FilePickerModel;
    expect(picker.selected, isNull);
    expect(picker.currentDir, sub.path);

    picker = picker.update((await cmd!())!).$1 as FilePickerModel;
    expect(picker.loading, isFalse);
    picker = picker.update(key(KeyCode.enter)).$1 as FilePickerModel;
    expect(picker.selected, p.join(sub.path, 'inner.txt'));
  });
}
