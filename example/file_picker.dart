// Ported from charmbracelet/bubbletea examples/file-picker
import 'dart:io';
import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  await Program(
    options: const ProgramOptions(altScreen: true),
  ).run(FilePickerExampleModel());
}

final class FilePickerExampleModel extends TeaModel {
  FilePickerExampleModel({FilePickerModel? picker, this.selected})
      : picker = picker ??
            FilePickerModel(
              currentDir: Directory.current.path,
              allowedExtensions: ['.dart', '.yaml', '.md', '.txt'],
              height: 15,
            );

  final FilePickerModel picker;
  final String? selected;

  @override
  Cmd? init() => picker.init();

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is KeyMsg) {
      if (msg.key == 'ctrl+c') return (this, () => quit());
      if (msg.key == 'esc') {
        if (selected != null) {
          return (
            FilePickerExampleModel(picker: picker, selected: null),
            null,
          );
        }
        return (this, () => quit());
      }
    }
    final (next, cmd) = picker.update(msg);
    final nextPicker = next as FilePickerModel;
    if (nextPicker.selected != null && nextPicker.selected != selected) {
      return (
        FilePickerExampleModel(
          picker: nextPicker,
          selected: nextPicker.selected,
        ),
        null,
      );
    }
    return (
      FilePickerExampleModel(picker: nextPicker, selected: selected),
      cmd,
    );
  }

  @override
  View view() {
    final header = const Style().bold().render('File Picker');
    final b = StringBuffer('$header\n\n');
    if (selected != null) {
      b.writeln(
        const Style().foregroundColor256(82).render('✓ Selected: $selected'),
      );
      b.write('\nesc: clear selection  •  ctrl+c: quit');
    } else {
      b.write(picker.view().content);
    }
    return newView(b.toString());
  }
}
