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
Future<String?> filter(
  List<String> choices, {
  List<ProgramOption> options = const [],
  String title = '',
}) async {
  if (choices.isEmpty) return null;
  final model = _FilterModel(
    ListModel(
      items: choices.map((o) => ListItem(title: o)).toList(),
      title: title,
      filterMode: true,
    ),
  );
  return Program(options: options).runForResult(model);
}

/// Render an animated spinner labelled [label] while awaiting [task], returning
/// its result (or rethrowing its error). The spinner is torn down as soon as
/// [task] settles.
Future<T> spin<T>(
  Future<T> task, {
  String label = 'Loading…',
  List<ProgramOption> options = const [],
}) async {
  final program = Program(
    options: [
      withTickInterval(const Duration(milliseconds: 80)),
      ...options,
    ],
  );
  final run = program.run(_SpinModel(SpinnerModel(), label));

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
Future<void> pager(
  String content, {
  int width = 80,
  int height = 20,
  List<ProgramOption> options = const [],
}) async {
  final model = _PagerModel(
    ViewportModel(content: content, width: width, height: height),
  );
  await Program(options: options).run(model);
}

// ── Models ───────────────────────────────────────────────────────────────────

final class _FilterModel extends Model implements OutcomeModel<String> {
  _FilterModel(this.list, {this.result, this.done = false});

  final ListModel list;
  final String? result;
  final bool done;

  @override
  String? get outcome => result;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is KeyMsg) {
      switch (msg.key) {
        case 'enter':
        case 'ctrl+j':
          return (
            _FilterModel(list, result: list.selected?.title, done: true),
            () => QuitMsg(),
          );
        case 'esc':
        case 'ctrl+c':
          return (
            _FilterModel(list, result: null, done: true),
            () => QuitMsg()
          );
      }
    }
    final (next, cmd) = list.update(msg);
    return (_FilterModel(next as ListModel, result: result, done: done), cmd);
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
