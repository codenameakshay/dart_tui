// Ported from charmbracelet/bubbletea examples/exec
import 'dart:io';
import 'package:dart_tui/dart_tui.dart';

final class _EditedMsg extends Msg {
  _EditedMsg(this.content, this.exitCode);
  final String content;
  final int exitCode;
}

Future<void> main() async {
  await Program(
    options: const ProgramOptions(altScreen: true),
  ).run(ExecCmdModel());
}

final class ExecCmdModel extends TeaModel {
  ExecCmdModel({this.content = '', this.editing = false, this.exitCode});
  final String content;
  final bool editing;
  final int? exitCode;

  @override
  Cmd? init() => _launchEditor();

  Cmd _launchEditor() {
    final tmpFile = File(
      '${Directory.systemTemp.path}/dart_tui_edit_${DateTime.now().millisecondsSinceEpoch}.txt',
    );
    tmpFile.writeAsStringSync(content);
    final editor = Platform.environment['EDITOR'] ??
        Platform.environment['VISUAL'] ??
        'nano';
    return execProcess(
      editor,
      [tmpFile.path],
      inheritStdio: true,
      onExit: (exitCode) {
        final edited = tmpFile.existsSync() ? tmpFile.readAsStringSync() : '';
        try {
          tmpFile.deleteSync();
        } catch (_) {}
        return _EditedMsg(edited, exitCode);
      },
    );
  }

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is KeyMsg) {
      switch (msg.key) {
        case 'q':
        case 'ctrl+c':
          return (this, () => quit());
        case 'e':
          return (
            ExecCmdModel(
              content: content,
              editing: true,
              exitCode: exitCode,
            ),
            _launchEditor(),
          );
      }
    }
    if (msg is _EditedMsg) {
      return (
        ExecCmdModel(
          content: msg.content,
          editing: false,
          exitCode: msg.exitCode,
        ),
        null,
      );
    }
    return (this, null);
  }

  @override
  View view() {
    if (editing) {
      return newView('Launching editor...');
    }
    final header = const Style().bold().render('External Editor');
    final b = StringBuffer('$header\n\n');
    if (content.isEmpty) {
      b.writeln(const Style().dim().render('(no content yet)'));
    } else {
      b.writeln('Content from editor:');
      b.writeln(
        const Style()
            .withBorder(Border.rounded)
            .withPadding(const EdgeInsets.all(1))
            .render(content),
      );
    }
    if (exitCode != null) {
      b.writeln(
        const Style().dim().render('Editor exited with code: $exitCode'),
      );
    }
    b.write('\ne: open editor  •  q: quit');
    return newView(b.toString());
  }
}
