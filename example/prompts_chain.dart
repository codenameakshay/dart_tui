import 'dart:io';

import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  stdout.writeln('Prompts chain demo (detailed).');
  stdout.writeln(
    'This demo chains the prompts in one Program; null means user cancelled the prompt.\n',
  );

  final state = await Program(options: [withAltScreen()]).run(
    _PromptsChainModel(),
  );
  final model = state as _PromptsChainModel;

  stdout.writeln('Selected: ${model.selected}');
  stdout.writeln('Confirmed: ${model.confirmed}');
  stdout.writeln('Notes: ${model.note}');
  stdout.writeln('\nSummary:');
  stdout.writeln('  flavor = ${model.selected}');
  stdout.writeln('  confirmed = ${model.confirmed}');
  stdout.writeln('  notes = ${model.note}');
  stdout.writeln('\nDone.');
}

final class _PromptsChainModel extends Model {
  _PromptsChainModel({
    this.step = 0,
    this.cursor = 0,
    this.selected,
    this.confirmed,
    this.note = '',
  });

  static const _choices = ['Vanilla', 'Chocolate', 'Strawberry'];

  final int step;
  final int cursor;
  final String? selected;
  final bool? confirmed;
  final String note;

  int get _c => cursor.clamp(0, _choices.length - 1);

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is WindowSizeMsg || msg is TickMsg) return (this, null);
    if (msg is! KeyMsg) return (this, null);

    switch (step) {
      case 0:
        switch (msg.key) {
          case 'up':
          case 'k':
            return (
              _PromptsChainModel(
                step: step,
                cursor: _c > 0 ? _c - 1 : 0,
                selected: selected,
                confirmed: confirmed,
                note: note,
              ),
              null,
            );
          case 'down':
          case 'j':
            return (
              _PromptsChainModel(
                step: step,
                cursor: _c < _choices.length - 1 ? _c + 1 : _choices.length - 1,
                selected: selected,
                confirmed: confirmed,
                note: note,
              ),
              null,
            );
          case 'enter':
          case 'ctrl+j':
            return (
              _PromptsChainModel(
                step: 1,
                cursor: cursor,
                selected: _choices[_c],
                confirmed: confirmed,
                note: note,
              ),
              null,
            );
        }
      case 1:
        switch (msg.key) {
          case 'y':
          case 'Y':
          case 'enter':
          case 'ctrl+j':
            return (
              _PromptsChainModel(
                step: 2,
                cursor: cursor,
                selected: selected,
                confirmed: true,
                note: note,
              ),
              null,
            );
          case 'n':
          case 'N':
            return (
              _PromptsChainModel(
                step: 2,
                cursor: cursor,
                selected: selected,
                confirmed: false,
                note: note,
              ),
              null,
            );
        }
      case 2:
        switch (msg.key) {
          case 'enter':
          case 'ctrl+j':
            return (
              _PromptsChainModel(
                step: 3,
                cursor: cursor,
                selected: selected,
                confirmed: confirmed,
                note: note,
              ),
              () => QuitMsg(),
            );
          case 'backspace':
            if (note.isEmpty) return (this, null);
            return (
              _PromptsChainModel(
                step: step,
                cursor: cursor,
                selected: selected,
                confirmed: confirmed,
                note: note.substring(0, note.length - 1),
              ),
              null,
            );
          default:
            if (msg.key.length == 1) {
              return (
                _PromptsChainModel(
                  step: step,
                  cursor: cursor,
                  selected: selected,
                  confirmed: confirmed,
                  note: note + msg.key,
                ),
                null,
              );
            }
        }
    }
    return (this, null);
  }

  @override
  View view() {
    return switch (step) {
      0 => _renderSelect(),
      1 => _renderConfirm(),
      2 => _renderInput(),
      _ => _renderDone(),
    };
  }

  View _renderSelect() {
    final b = StringBuffer('Favorite ice cream')
      ..writeln()
      ..writeln();
    for (var i = 0; i < _choices.length; i++) {
      final mark = i == _c ? '>' : ' ';
      b.writeln('$mark ${_choices[i]}');
    }
    b.writeln();
    b.write('↑/↓ navigate, Enter confirm, Esc cancel');
    return newView(b.toString());
  }

  View _renderConfirm() => newView(
        'Ship to production? [y/N]\nY or Enter = yes, N = no, Esc = cancel',
      );

  View _renderInput() => newView('Notes: $note█');

  View _renderDone() => newView('Done.');
}
