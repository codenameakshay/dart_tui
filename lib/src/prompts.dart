import 'package:dart_console/dart_console.dart';

import 'cmd.dart';
import 'model.dart';
import 'msg.dart';
import 'program.dart';

/// Prompt helpers built on [Program] + [OutcomeModel] (optional sugar).

/// Single-choice list; returns the selected string, or `null` if cancelled.
Future<String?> promptSelect(
  List<String> choices, {
  Console? console,
  ProgramOptions options = const ProgramOptions(),
  String title = 'Choose one',
}) async {
  if (choices.isEmpty) return null;
  final model = _SelectPromptModel(choices: choices, title: title);
  return Program(console: console, options: options).runForResult(model);
}

/// Yes / no; returns `null` on cancel.
Future<bool?> promptConfirm(
  String question, {
  Console? console,
  ProgramOptions options = const ProgramOptions(),
}) async {
  final model = _ConfirmPromptModel(question: question);
  return Program(console: console, options: options).runForResult(model);
}

/// Single-line text; returns `null` on cancel.
Future<String?> promptInput(
  String label, {
  Console? console,
  ProgramOptions options = const ProgramOptions(),
}) async {
  final model = _InputPromptModel(label: label);
  return Program(console: console, options: options).runForResult(model);
}

final class _SelectPromptModel extends TeaModel implements OutcomeModel<String> {
  _SelectPromptModel({
    required this.choices,
    required this.title,
    this.cursor = 0,
    this.result,
    this.finished = false,
  });

  final List<String> choices;
  final String title;
  final int cursor;
  final String? result;
  final bool finished;

  @override
  String? get outcome => result;

  @override
  bool get quit => finished;

  int get _c => cursor.clamp(0, choices.length - 1);

  @override
  (TeaModel, Cmd?) update(Msg msg) {
    if (msg is WindowSizeMsg || msg is TickMsg) return (this, null);
    if (msg is! KeyMsg) return (this, null);
    switch (msg.key) {
      case 'up':
      case 'k':
        return (
          _SelectPromptModel(
            choices: choices,
            title: title,
            cursor: _c > 0 ? _c - 1 : 0,
            result: result,
            finished: finished,
          ),
          null,
        );
      case 'down':
      case 'j':
        return (
          _SelectPromptModel(
            choices: choices,
            title: title,
            cursor: _c < choices.length - 1 ? _c + 1 : choices.length - 1,
            result: result,
            finished: finished,
          ),
          null,
        );
      case 'enter':
      // LF (0x0a) maps to ctrl+j; CR (0x0d) maps to enter — terminals differ.
      case 'ctrl+j':
        return (
          _SelectPromptModel(
            choices: choices,
            title: title,
            cursor: cursor,
            result: choices[_c],
            finished: true,
          ),
          null,
        );
      case 'esc':
      case 'ctrl+c':
        return (
          _SelectPromptModel(
            choices: choices,
            title: title,
            cursor: cursor,
            result: null,
            finished: true,
          ),
          null,
        );
      default:
        return (this, null);
    }
  }

  @override
  String view() {
    final b = StringBuffer(title)..writeln()..writeln();
    final cur = _c;
    for (var i = 0; i < choices.length; i++) {
      final mark = i == cur ? '>' : ' ';
      b.writeln('$mark ${choices[i]}');
    }
    b.writeln();
    b.write('↑/↓ navigate, Enter confirm, Esc cancel');
    return b.toString();
  }
}

final class _ConfirmPromptModel extends TeaModel implements OutcomeModel<bool> {
  _ConfirmPromptModel({
    required this.question,
    this.result,
    this.finished = false,
  });

  final String question;
  final bool? result;
  final bool finished;

  @override
  bool? get outcome => result;

  @override
  bool get quit => finished;

  @override
  (TeaModel, Cmd?) update(Msg msg) {
    if (msg is WindowSizeMsg || msg is TickMsg) return (this, null);
    if (msg is! KeyMsg) return (this, null);
    switch (msg.key) {
      case 'y':
      case 'Y':
        return (
          _ConfirmPromptModel(question: question, result: true, finished: true),
          null,
        );
      case 'n':
      case 'N':
        return (
          _ConfirmPromptModel(question: question, result: false, finished: true),
          null,
        );
      case 'enter':
      case 'ctrl+j':
        return (
          _ConfirmPromptModel(question: question, result: true, finished: true),
          null,
        );
      case 'esc':
      case 'ctrl+c':
        return (
          _ConfirmPromptModel(question: question, result: null, finished: true),
          null,
        );
      default:
        return (this, null);
    }
  }

  @override
  String view() =>
      '$question [y/N]\nY or Enter = yes, N = no, Esc = cancel';
}

final class _InputPromptModel extends TeaModel implements OutcomeModel<String> {
  _InputPromptModel({
    required this.label,
    this.value = '',
    this.result,
    this.finished = false,
  });

  final String label;
  final String value;
  final String? result;
  final bool finished;

  @override
  String? get outcome => result;

  @override
  bool get quit => finished;

  @override
  (TeaModel, Cmd?) update(Msg msg) {
    if (msg is WindowSizeMsg || msg is TickMsg) return (this, null);
    if (msg is! KeyMsg) return (this, null);
    switch (msg.key) {
      case 'enter':
      case 'ctrl+j':
        return (
          _InputPromptModel(
            label: label,
            value: value,
            result: value,
            finished: true,
          ),
          null,
        );
      case 'esc':
      case 'ctrl+c':
        return (
          _InputPromptModel(
            label: label,
            value: value,
            result: null,
            finished: true,
          ),
          null,
        );
      case 'backspace':
        if (value.isEmpty) return (this, null);
        return (
          _InputPromptModel(
            label: label,
            value: value.substring(0, value.length - 1),
            finished: false,
          ),
          null,
        );
      default:
        if (msg.key.length == 1) {
          return (
            _InputPromptModel(
              label: label,
              value: value + msg.key,
              finished: false,
            ),
            null,
          );
        }
        return (this, null);
    }
  }

  @override
  String view() => '$label $value█';
}
