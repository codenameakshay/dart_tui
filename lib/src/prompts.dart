import 'dart:async';

import 'package:characters/characters.dart';

import 'bubbles/multi_select.dart';
import 'bubbles/style.dart';
import 'cmd.dart';
import 'model.dart';
import 'msg.dart';
import 'program.dart';
import 'view.dart';

/// Prompt helpers built on [Program] + [OutcomeModel] (optional sugar).
///
/// Each one works without a terminal too: in plain mode (see [withPlainMode])
/// it asks a plain line question and writes no escape codes. The end of input
/// cancels, like Esc.

/// Internal: while this zone key is `true`, an answered prompt leaves one
/// line (`title answer`) instead of its full last frame, as `Logger` does.
final Object promptSummaryKey = Object();

bool get _summary => Zone.current[promptSummaryKey] == true;

String _answered(String title, String answer) {
  final shown = const Style(foreground256: 14, isDim: true).render(answer);
  return title.isEmpty ? shown : '$title $shown';
}

/// Single-choice list; returns the selected string, or `null` if cancelled.
///
/// The cursor starts on [initial] (default the first choice).
///
/// In plain mode it writes [title] and the numbered choices, then reads a
/// number from 1 to N, asking again until the answer is valid. With
/// [initial], empty input picks it.
Future<String?> promptSelect(
  List<String> choices, {
  List<ProgramOption> options = const [],
  String title = 'Choose one',
  int? initial,
}) async {
  if (choices.isEmpty) return null;
  final start = initial?.clamp(0, choices.length - 1);
  final program = Program(options: options);
  final plain = PlainSession.open(program);
  if (plain != null) {
    return plain.run((io) async {
      final i = await io.askChoice([title], choices, defaultIndex: start);
      return i == null ? null : choices[i];
    });
  }
  final model = _SelectPromptModel(
    choices: choices,
    title: title,
    cursor: start ?? 0,
    summary: _summary,
  );
  return program.runForResult(model);
}

/// Several choices; returns the checked ones in list order, or `null` if
/// cancelled. Empty [choices] returns an empty list.
///
/// `Space` (or `x`) toggles, `a` toggles all, `Enter` confirms. The
/// indexes in [initial] start checked.
///
/// In plain mode it writes [title] and the numbered choices, then reads
/// comma-separated numbers; empty input keeps [initial].
Future<List<String>?> promptMultiSelect(
  List<String> choices, {
  List<ProgramOption> options = const [],
  String title = 'Choose any',
  Set<int> initial = const {},
}) async {
  if (choices.isEmpty) return const [];
  List<String> pick(Iterable<int> picks) =>
      [for (final i in picks.toList()..sort()) choices[i]];
  final program = Program(options: options);
  final plain = PlainSession.open(program);
  if (plain != null) {
    return plain.run((io) async {
      final picks = await io.askMany([title], choices,
          defaults: {
            for (final i in initial)
              if (i >= 0 && i < choices.length) i
          });
      return picks == null ? null : pick(picks);
    });
  }
  final model = _MultiPromptModel(
    MultiSelectModel(
      title: title,
      items: [
        for (final (i, c) in choices.indexed)
          MultiSelectItem(label: c, selected: initial.contains(i)),
      ],
    ),
    summary: _summary,
  );
  final picks = await program.runForResult(model);
  return picks == null ? null : pick(picks);
}

/// Yes / no; returns `null` on cancel. Enter returns [defaultValue] (no,
/// unless set).
///
/// In plain mode it asks `question (y/N)`, or `(Y/n)` when [defaultValue] is
/// true; empty input takes the default.
Future<bool?> promptConfirm(
  String question, {
  List<ProgramOption> options = const [],
  bool defaultValue = false,
}) async {
  final program = Program(options: options);
  final plain = PlainSession.open(program);
  if (plain != null) {
    return plain.run((io) => io.askConfirm(question, defaultValue));
  }
  final model = _ConfirmPromptModel(
    question: question,
    defaultValue: defaultValue,
    summary: _summary,
  );
  return program.runForResult(model);
}

/// Single-line text; returns `null` on cancel. Empty input returns
/// [defaultValue].
///
/// With [hidden], the answer is shown as `•` while typing (like a password
/// text input) and is not echoed in plain mode.
///
/// In plain mode it writes [label] and reads one line.
Future<String?> promptInput(
  String label, {
  List<ProgramOption> options = const [],
  bool hidden = false,
  String defaultValue = '',
}) async {
  final program = Program(options: options);
  final plain = PlainSession.open(program);
  if (plain != null) {
    final prompt = label.isEmpty || label.endsWith(' ') ? label : '$label ';
    return plain.run(
      (io) => io.askText(prompt, initial: defaultValue, secret: hidden),
    );
  }
  final model = _InputPromptModel(
    label: label,
    hidden: hidden,
    defaultValue: defaultValue,
    summary: _summary,
  );
  return program.runForResult(model);
}

final class _SelectPromptModel extends Model implements OutcomeModel<String> {
  _SelectPromptModel({
    required this.choices,
    required this.title,
    this.cursor = 0,
    this.result,
    this.summary = false,
  });

  final List<String> choices;
  final String title;
  final int cursor;
  final String? result;
  final bool summary;

  @override
  String? get outcome => result;

  int get _c => cursor.clamp(0, choices.length - 1);

  _SelectPromptModel _copy({required int cursor, String? result}) =>
      _SelectPromptModel(
        choices: choices,
        title: title,
        cursor: cursor,
        result: result,
        summary: summary,
      );

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is WindowSizeMsg || msg is TickMsg) return (this, null);
    if (msg is! KeyMsg) return (this, null);
    switch (msg.key) {
      case 'up':
      case 'k':
        return (_copy(cursor: _c > 0 ? _c - 1 : 0, result: result), null);
      case 'down':
      case 'j':
        return (
          _copy(
            cursor: _c < choices.length - 1 ? _c + 1 : choices.length - 1,
            result: result,
          ),
          null,
        );
      case 'enter':
      // LF (0x0a) maps to ctrl+j; CR (0x0d) maps to enter — terminals differ.
      case 'ctrl+j':
        return (_copy(cursor: cursor, result: choices[_c]), null);
      case 'esc':
      case 'ctrl+c':
        return (_copy(cursor: cursor), () => QuitMsg());
      default:
        return (this, null);
    }
  }

  @override
  View view() {
    if (summary && result != null) return newView(_answered(title, result!));
    final b = StringBuffer(title)
      ..writeln()
      ..writeln();
    final cur = _c;
    for (var i = 0; i < choices.length; i++) {
      final mark = i == cur ? '>' : ' ';
      b.writeln('$mark ${choices[i]}');
    }
    b.writeln();
    b.write('↑/↓ navigate, Enter confirm, Esc cancel');
    return newView(b.toString());
  }
}

final class _MultiPromptModel extends Model implements OutcomeModel<List<int>> {
  _MultiPromptModel(this.list, {this.result, this.summary = false});

  final MultiSelectModel list;
  final List<int>? result;
  final bool summary;

  @override
  List<int>? get outcome => result;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is KeyMsg) {
      switch (msg.key) {
        case 'enter':
        case 'ctrl+j':
          final picks = [
            for (final (i, item) in list.items.indexed)
              if (item.selected) i,
          ];
          return (
            _MultiPromptModel(list, result: picks, summary: summary),
            null
          );
        case 'esc':
        case 'ctrl+c':
          return (this, () => QuitMsg());
      }
    }
    final (next, cmd) = list.update(msg);
    return (_MultiPromptModel(next as MultiSelectModel, summary: summary), cmd);
  }

  @override
  View view() {
    final picks = result;
    if (summary && picks != null) {
      final labels = [for (final i in picks) list.items[i].label];
      return newView(_answered(list.title, '$labels'));
    }
    return newView('${list.view().content}\n\n'
        '↑/↓ navigate, Space toggle, Enter confirm, Esc cancel');
  }
}

final class _ConfirmPromptModel extends Model implements OutcomeModel<bool> {
  _ConfirmPromptModel({
    required this.question,
    this.defaultValue = false,
    this.result,
    this.summary = false,
  });

  final String question;
  final bool defaultValue;
  final bool? result;
  final bool summary;

  @override
  bool? get outcome => result;

  _ConfirmPromptModel _with(bool? result) => _ConfirmPromptModel(
        question: question,
        defaultValue: defaultValue,
        result: result,
        summary: summary,
      );

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is WindowSizeMsg || msg is TickMsg) return (this, null);
    if (msg is! KeyMsg) return (this, null);
    switch (msg.key) {
      case 'y':
      case 'Y':
        return (_with(true), null);
      case 'n':
      case 'N':
        return (_with(false), null);
      case 'enter':
      case 'ctrl+j':
        return (_with(defaultValue), null);
      case 'esc':
      case 'ctrl+c':
        return (_with(null), () => QuitMsg());
      default:
        return (this, null);
    }
  }

  @override
  View view() {
    if (summary && result != null) {
      return newView(_answered(question, result! ? 'Yes' : 'No'));
    }
    return newView(defaultValue
        ? '$question [Y/n]\nY or Enter = yes, N = no, Esc = cancel'
        : '$question [y/N]\nY = yes, N or Enter = no, Esc = cancel');
  }
}

final class _InputPromptModel extends Model implements OutcomeModel<String> {
  _InputPromptModel({
    required this.label,
    this.value = '',
    this.result,
    this.hidden = false,
    this.defaultValue = '',
    this.summary = false,
  });

  final String label;
  final String value;
  final String? result;
  final bool hidden;
  final String defaultValue;
  final bool summary;

  @override
  String? get outcome => result;

  _InputPromptModel _with(String value, {String? result}) => _InputPromptModel(
        label: label,
        value: value,
        result: result,
        hidden: hidden,
        defaultValue: defaultValue,
        summary: summary,
      );

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is WindowSizeMsg || msg is TickMsg) return (this, null);
    if (msg is PasteMsg) {
      final text = msg.content
          .replaceAll(RegExp(r'\r\n|[\r\n\t]'), ' ')
          .replaceAll(RegExp(r'[\x00-\x1f\x7f-\x9f]'), '');
      return text.isEmpty ? (this, null) : (_with(value + text), null);
    }
    if (msg is! KeyMsg) return (this, null);
    switch (msg.key) {
      case 'enter':
      case 'ctrl+j':
        return (
          _with(value, result: value.isEmpty ? defaultValue : value),
          null
        );
      case 'esc':
      case 'ctrl+c':
        return (_with(value), () => QuitMsg());
      case 'backspace':
        if (value.isEmpty) return (this, null);
        return (_with(value.characters.skipLast(1).toString()), null);
      default:
        // Insert the rune text: msg.key is 'space' for the space key.
        final ke = msg.keyEvent;
        if (ke.code == KeyCode.rune &&
            ke.text.isNotEmpty &&
            ke.modifiers.isEmpty) {
          return (_with(value + ke.text), null);
        }
        return (this, null);
    }
  }

  @override
  View view() {
    if (summary && result != null) {
      return newView(_answered(label, hidden ? '******' : result!));
    }
    final shown = hidden ? '•' * value.characters.length : value;
    return newView('$label $shown█');
  }
}
