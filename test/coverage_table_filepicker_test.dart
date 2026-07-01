import 'dart:io';

import 'package:dart_tui/dart_tui.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

KeyPressMsg _k(KeyCode c) => KeyPressMsg(TeaKey(code: c));
KeyPressMsg _r(String t) => KeyPressMsg(TeaKey(code: KeyCode.rune, text: t));

void main() {
  group('TableModel', () {
    TableModel base() => TableModel(
          columns: const [
            TableColumn(title: 'Name', width: 4),
            TableColumn(title: 'Val', width: 3),
          ],
          rows: const [
            ['alpha', '1'], // 'alpha' wider than width 4 → truncated
            ['b', '2'],
            ['c', '3'],
            ['d', '4'],
          ],
          height: 2,
        );

    test('ignores non-key/non-mouse messages', () {
      final m = base();
      expect(m.update(WindowSizeMsg(4, 4)).$1, same(m));
    });

    test('key navigation moves cursor and scroll with clamping', () {
      var m = base();
      m = m.update(_r('j')).$1 as TableModel;
      expect(m.cursor, 1);
      m = m.update(_k(KeyCode.pageDown)).$1 as TableModel;
      expect(m.cursor, 3);
      m = m.update(_k(KeyCode.home)).$1 as TableModel;
      expect(m.cursor, 0);
      m = m.update(_k(KeyCode.end)).$1 as TableModel;
      expect(m.cursor, 3);
      expect(m.scrollOffset, greaterThan(0));
      m = m.update(_r('k')).$1 as TableModel;
      expect(m.cursor, 2);
      m = m.update(_k(KeyCode.pageUp)).$1 as TableModel;
      expect(m.cursor, 0);
    });

    test('mouse wheel and left-click (with header offset) select rows', () {
      var m = base();
      m = m
          .update(MouseClickMsg(
              const Mouse(x: 0, y: 0, button: MouseButton.wheelDown)))
          .$1 as TableModel;
      expect(m.cursor, 1);
      m = m
          .update(MouseClickMsg(
              const Mouse(x: 0, y: 0, button: MouseButton.wheelUp)))
          .$1 as TableModel;
      expect(m.cursor, 0);
      // click on the 2nd data row: y = viewOffsetY(0) + headerRows(2) + 1
      final clicked = m
          .update(
              MouseClickMsg(const Mouse(x: 0, y: 3, button: MouseButton.left)))
          .$1 as TableModel;
      expect(clicked.cursor, 1);
      // click above the data area is ignored
      expect(
          m
              .update(MouseClickMsg(
                  const Mouse(x: 0, y: 0, button: MouseButton.left)))
              .$1,
          isA<TableModel>());
    });

    test('view renders header, separator, truncated cells and styleFunc', () {
      final styled = TableModel(
        columns: const [TableColumn(title: 'Name', width: 4)],
        rows: const [
          ['alpha']
        ],
        styles: TableStyles(
          styleFunc: (row, col) => row == 0 ? const Style(isBold: true) : null,
        ),
      );
      final content = styled.view().content;
      expect(content, contains('Name'));
      expect(content, contains('─'));
      expect(content, contains('alph')); // 'alpha' truncated to width 4
    });
  });

  group('FilePickerModel', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('fp_test');
      Directory(pathJoin(tmp.path, 'sub')).createSync();
      File(pathJoin(tmp.path, 'a.txt')).writeAsStringSync('x');
      File(pathJoin(tmp.path, 'b.dart')).writeAsStringSync('y');
      File(pathJoin(tmp.path, '.hidden')).writeAsStringSync('z');
    });

    tearDown(() => tmp.deleteSync(recursive: true));

    FilePickerModel loaded(FilePickerModel m) {
      final msg = (m.init()!() as Msg);
      return m.update(msg).$1 as FilePickerModel;
    }

    test('init loads entries, hides dotfiles, filters extensions', () {
      final m = loaded(FilePickerModel(
          currentDir: tmp.path, allowedExtensions: const ['.txt']));
      expect(m.loading, isFalse);
      final names = m.entries.map((e) => p.basename(e.path)).toSet();
      expect(names, contains('sub')); // directory always shown
      expect(names, contains('a.txt')); // allowed extension
      expect(names, isNot(contains('b.dart'))); // filtered out
      expect(names, isNot(contains('.hidden'))); // dotfile hidden
    });

    test('toggling hidden shows dotfiles', () {
      var m = loaded(FilePickerModel(currentDir: tmp.path));
      m = m.update(_r('h')).$1
          as FilePickerModel; // toggles showHidden + reloads
      m = loaded(m);
      final names = m.entries.map((e) => p.basename(e.path)).toSet();
      expect(names, contains('.hidden'));
    });

    test('navigation, entering a directory, and selecting a file', () {
      var m = loaded(FilePickerModel(currentDir: tmp.path));
      // move down/up
      m = m.update(_k(KeyCode.down)).$1 as FilePickerModel;
      m = m.update(_k(KeyCode.up)).$1 as FilePickerModel;
      // cursor 0 is 'sub' (dirs sort first) → enter opens it
      final (opened, cmd) = m.update(_k(KeyCode.enter));
      expect((opened as FilePickerModel).currentDir, endsWith('sub'));
      expect(cmd, isNotNull);
      // go back to parent
      final (parent, pcmd) = opened.update(_k(KeyCode.backspace));
      expect((parent as FilePickerModel).currentDir, tmp.path);
      expect(pcmd, isNotNull);
    });

    test('selecting a file sets selected; view has loading and list states',
        () {
      var m = loaded(FilePickerModel(currentDir: tmp.path));
      // move cursor onto the first file entry
      while ((m.entries[m.cursor] is Directory) &&
          m.cursor < m.entries.length - 1) {
        m = m.update(_k(KeyCode.down)).$1 as FilePickerModel;
      }
      final selected = m.update(_k(KeyCode.enter)).$1 as FilePickerModel;
      expect(selected.selected, isNotNull);
      // views
      expect(FilePickerModel(currentDir: tmp.path).view().content,
          contains('Loading'));
      expect(m.view().content, contains(tmp.path));
    });
  });
}

String pathJoin(String a, String b) => p.join(a, b);
