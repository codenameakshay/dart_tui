import 'dart:async';

import 'bubbles/list.dart';
import 'bubbles/spinner.dart';
import 'bubbles/viewport.dart';
import 'cmd.dart';
import 'model.dart';
import 'msg.dart';
import 'program.dart';
import 'view.dart';

/// One-shot convenience helpers inspired by [gum](https://github.com/charmbracelet/gum),
/// built on [Program]. Each accepts an [options] list so it can be driven
/// headlessly in tests (e.g. `withInput`, `withoutRenderer`).

/// Interactive fuzzy filter over [choices]. Type to narrow, `Enter` to pick the
/// highlighted entry, `Esc`/`Ctrl+C` to cancel. Returns the chosen string, or
/// `null` if cancelled or [choices] is empty.
///
/// In plain mode (see [withPlainMode]) it writes [title] and the numbered
/// choices, then accepts a number, or text that matches exactly one choice.
Future<String?> filter(
  List<String> choices, {
  List<ProgramOption> options = const [],
  String title = '',
}) async {
  if (choices.isEmpty) return null;
  final program = Program(options: options);
  final plain = PlainSession.open(program);
  if (plain != null) {
    return plain.run((io) async {
      final i = await io.askChoice([title], choices, matchText: true);
      return i == null ? null : choices[i];
    });
  }
  final model = _FilterModel(
    ListModel(
      items: choices.map((o) => ListItem(title: o)).toList(),
      title: title,
      filterMode: true,
    ),
  );
  return program.runForResult(model);
}

/// Render an animated spinner labelled [label] while awaiting [task], returning
/// its result (or rethrowing its error). The spinner is torn down as soon as
/// [task] settles.
///
/// Pass a preset such as [Spinner.moon] as [spinner] to change the frames and
/// speed. The default is the [Spinner.miniDot] frames every 80 ms.
///
/// In plain mode (see [withPlainMode]) it writes `label…` when it starts,
/// then `✓ label` or `✗ label: error` when [task] settles.
Future<T> spin<T>(
  Future<T> task, {
  String label = 'Loading…',
  Spinner? spinner,
  List<ProgramOption> options = const [],
}) async {
  final program = Program(
    options: [
      withTickInterval(
        spinner?.interval ?? const Duration(milliseconds: 80),
      ),
      ...options,
    ],
  );
  final plain = PlainSession.open(program);
  if (plain != null) {
    final name = label.replaceFirst(RegExp(r'(…|\.\.\.)$'), '');
    plain.writeln('$name…');
    try {
      final value = await task;
      plain.writeln('✓ $name');
      return value;
    } catch (error) {
      plain.writeln('✗ $name: $error');
      rethrow;
    }
  }
  final run = program.run(_SpinModel(SpinnerModel(spinner: spinner), label));

  T? value;
  Object? error;
  StackTrace? stack;
  unawaited(() async {
    try {
      value = await task;
    } catch (e, s) {
      error = e;
      stack = s;
    } finally {
      program.quit();
    }
  }());

  await run;
  if (error != null) {
    Error.throwWithStackTrace(error!, stack ?? StackTrace.current);
  }
  return value as T;
}

/// Show [content] in a scrollable pager. Scroll with the usual viewport keys;
/// press `q`/`Esc` to exit. Completes when the user quits.
///
/// In plain mode (see [withPlainMode]) it writes [content] as it is.
Future<void> pager(
  String content, {
  int width = 80,
  int height = 20,
  List<ProgramOption> options = const [],
}) async {
  final program = Program(options: options);
  final plain = PlainSession.open(program);
  if (plain != null) {
    plain.write(content.endsWith('\n') ? content : '$content\n');
    return;
  }
  final model = _PagerModel(
    ViewportModel(content: content, width: width, height: height),
  );
  await program.run(model);
}

// ── Models ───────────────────────────────────────────────────────────────────

final class _FilterModel extends Model implements OutcomeModel<String> {
  _FilterModel(this.list, {this.result});

  final ListModel list;
  final String? result;

  @override
  String? get outcome => result;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is KeyMsg) {
      switch (msg.key) {
        case 'enter':
        case 'ctrl+j':
          return (
            _FilterModel(list, result: list.selected?.title),
            () => QuitMsg(),
          );
        case 'esc':
        case 'ctrl+c':
          return (_FilterModel(list, result: null), () => QuitMsg());
      }
    }
    final (next, cmd) = list.update(msg);
    return (_FilterModel(next as ListModel, result: result), cmd);
  }

  @override
  View view() => list.view();
}

final class _SpinModel extends Model {
  _SpinModel(this.spinner, this.label);

  final SpinnerModel spinner;
  final String label;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is TickMsg) {
      return (_SpinModel(spinner.update(msg).$1 as SpinnerModel, label), null);
    }
    return (this, null);
  }

  @override
  View view() => newView('${spinner.view().content} $label');
}

final class _PagerModel extends Model {
  _PagerModel(this.vp);

  final ViewportModel vp;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is KeyMsg &&
        (msg.key == 'q' || msg.key == 'esc' || msg.key == 'ctrl+c')) {
      return (this, () => QuitMsg());
    }
    final (next, cmd) = vp.update(msg);
    return (_PagerModel(next as ViewportModel), cmd);
  }

  @override
  View view() => vp.view();
}
