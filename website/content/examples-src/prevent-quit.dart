// Ported from charmbracelet/bubbletea examples/prevent-quit
import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  await Program(
    programOptions: [
      withFilter((model, msg) {
        // Intercept quit signals when there are unsaved changes
        if (msg is QuitMsg || msg is InterruptMsg) {
          final m = model as PreventQuitModel;
          if (m.textarea.value.isNotEmpty && !m.confirming) {
            return _ConfirmQuitMsg();
          }
        }
        return msg;
      }),
    ],
  ).run(PreventQuitModel());
}

final class _ConfirmQuitMsg extends Msg {}

final class PreventQuitModel extends TeaModel {
  PreventQuitModel({
    TextAreaModel? textarea,
    this.confirming = false,
  }) : textarea = textarea ??
            TextAreaModel(
              placeholder: 'Type something here to enable the quit guard...',
              maxHeight: 5,
              width: 60,
              focused: true,
            );

  final TextAreaModel textarea;
  final bool confirming;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is _ConfirmQuitMsg) {
      return (PreventQuitModel(textarea: textarea, confirming: true), null);
    }
    if (confirming) {
      if (msg is KeyMsg) {
        switch (msg.key) {
          case 'y':
            return (this, () => quit());
          case 'n':
          case 'esc':
            return (
              PreventQuitModel(textarea: textarea, confirming: false),
              null,
            );
        }
      }
      return (this, null);
    }
    if (msg is KeyMsg) {
      if (msg.key == 'ctrl+c') return (this, () => quit());
      if (msg.key == 'esc' && textarea.value.isEmpty) {
        return (this, () => quit());
      }
    }
    final (next, cmd) = textarea.update(msg);
    return (
      PreventQuitModel(
        textarea: next as TextAreaModel,
        confirming: confirming,
      ),
      cmd,
    );
  }

  @override
  View view() {
    if (confirming) {
      final title = const Style()
          .bold()
          .foregroundColor256(196)
          .render('Unsaved Changes');
      final yKey = const Style().bold().render('[y]');
      final nKey = const Style().bold().render('[n]');
      return newView(
        '$title\n\nYou have unsaved changes. Are you sure you want to quit?\n\n'
        '$yKey yes  $nKey no',
      );
    }
    final editorTitle = const Style().bold().render('Editor');
    final hint = const Style().dim().render('ctrl+c or esc (when empty): quit');
    return newView(
      '$editorTitle\n\n${textarea.view().content}\n\n$hint',
    );
  }
}
