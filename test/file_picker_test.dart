import 'dart:io';

import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

/// Helper: create a [KeyPressMsg] for a single printable character.
KeyPressMsg _char(String ch) =>
    KeyPressMsg(TeaKey(code: KeyCode.rune, text: ch));

/// Helper: create a [KeyPressMsg] for a special key.
KeyPressMsg _special(KeyCode code) =>
    KeyPressMsg(TeaKey(code: code));

void main() {
  group('FilePickerModel', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('file_picker_test_');
      File('${tempDir.path}/file_a.txt').createSync();
      File('${tempDir.path}/file_b.dart').createSync();
      Directory('${tempDir.path}/subdir').createSync();
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('init loads directory entries', () async {
      final picker = FilePickerModel(currentDir: tempDir.path);
      final cmd = picker.init();
      expect(cmd, isNotNull);
      final msg = await cmd!();
      expect(msg, isNotNull);
      // Apply the loaded message
      final (next, _) = picker.update(msg!);
      final nextPicker = next as FilePickerModel;
      expect(nextPicker.entries, isNotEmpty);
      expect(nextPicker.loading, isFalse);
    });

    test('filters by extension', () async {
      final picker = FilePickerModel(
        currentDir: tempDir.path,
        allowedExtensions: ['.dart'],
      );
      final cmd = picker.init();
      final msg = await cmd!();
      final (next, _) = picker.update(msg!);
      final nextPicker = next as FilePickerModel;
      // Should only contain .dart files and directories
      for (final entry in nextPicker.entries) {
        if (entry is File) {
          expect(entry.path, endsWith('.dart'));
        }
      }
    });

    test('navigates up to parent', () async {
      final picker = FilePickerModel(currentDir: tempDir.path);
      // First load
      final cmd = picker.init()!;
      final loadMsg = await cmd();
      final (loaded, _) = picker.update(loadMsg!);

      // Navigate to parent using backspace key
      final (afterBack, _) = (loaded as FilePickerModel).update(
          _special(KeyCode.backspace));
      expect((afterBack as FilePickerModel).currentDir,
          isNot(equals(tempDir.path)));
    });
  });
}
