part of 'cli.dart';

const _yellow = Style(foreground256: 3);

/// Failed tasks show this many output lines while the list still runs, and
/// all of them in the final frame.
const _failedTail = 5;

/// One step for [Logger.tasks].
final class Task {
  /// [run] does the work; [TaskContext] lets it log, retitle itself, skip
  /// and run nested steps. When [enabled] returns false, the task is
  /// skipped instead of run.
  const Task(this.title, this.run, {this.enabled});

  /// The text on the task's line.
  final String title;

  /// The work. A thrown error fails the task.
  final FutureOr<void> Function(TaskContext task) run;

  /// Called when the task would start; false skips it.
  final bool Function()? enabled;
}

/// What a running [Task] can do with its line.
final class TaskContext {
  TaskContext._(this._run, this._node, this._prefix);

  final _TaskRun _run;
  final TaskNode _node;
  final String _prefix;

  /// `Parent > Child` for a nested step, else the title.
  String get _path =>
      _prefix.isEmpty ? _node.title : '$_prefix > ${_node.title}';

  /// The text on the task's line.
  String get title => _node.title;
  set title(String value) => _node.title = _taskText(value);

  /// Adds [line] to the task's output. While it runs, the last line shows
  /// dim under the task; a failed task shows its output. In plain mode each
  /// line is printed at once, prefixed with the task's title.
  void log(String line) => _run._log(this, line);

  /// Ends the task as skipped, with an optional [reason]. It throws, so
  /// nothing after it runs.
  Never skip([String? reason]) => throw _Skip(reason);

  /// Runs [tasks] as nested steps under this one, indented. A succeeded
  /// task with steps collapses to one line.
  ///
  /// With the list's `exitOnError`, a failed step throws [TasksFailed],
  /// which fails this task too.
  Future<void> tasks(List<Task> tasks, {int concurrency = 1}) =>
      _run._runLevel(tasks, concurrency, _node, _path);
}

final class _Skip {
  const _Skip(this.reason);
  final String? reason;
}

/// Thrown by [Logger.tasks] (and [TaskContext.tasks]) with `exitOnError`
/// when tasks fail, after the list has drawn its final frame.
final class TasksFailed implements Exception {
  const TasksFailed(this.failures);

  /// Each failed task: its title (`Parent > Child` for a nested step), its
  /// error and its stack trace. A task that failed only because a nested
  /// step failed is not listed; the step is.
  final List<({String title, Object error, StackTrace stackTrace})> failures;

  @override
  String toString() {
    if (failures.length == 1) {
      final f = failures.single;
      return '${f.title} failed: ${_taskText(f.error)}';
    }
    final each = [
      for (final f in failures) '${f.title} (${_taskText(f.error)})',
    ];
    return '${failures.length} tasks failed: ${each.join('; ')}';
  }
}

/// A task's state in the list.
enum TaskStatus { pending, running, success, failed, skipped }

/// One task as [renderTasks] draws it. The task list keeps one per task;
/// tests build them by hand. Not exported from `package:dart_tui/cli.dart`.
final class TaskNode {
  TaskNode(
    String title, {
    this.status = TaskStatus.pending,
    this.elapsed,
    List<String>? output,
    this.error,
    this.skipReason,
    List<TaskNode>? children,
  })  : title = _singleLine(title),
        output = output ?? [],
        children = children ?? [];

  String title;
  TaskStatus status;

  /// Set when the task ends.
  Duration? elapsed;

  /// Logged lines, each one terminal row without control characters.
  final List<String> output;
  Object? error;
  bool _ownFailure = false;
  String? skipReason;
  final List<TaskNode> children;

  bool get _hasFailure =>
      status == TaskStatus.failed || children.any((c) => c._hasFailure);
}

/// The rows of a task list: one line per task in declaration order, with a
/// spinner [frame], the title and the time once finished.
///
/// A running task shows its last output line under it, and its steps. A
/// task whose steps all succeeded collapses to one line. A failure stays
/// expanded with the tail of its output ([height] set) or all of it (the
/// final frame, [height] null).
///
/// With [height], the list keeps to `height - 1` rows: finished tasks fold
/// into one `… n done` line first. Every row is cut to `width - 1` columns,
/// so none wraps. [paint] colours the marks; the default adds no escapes.
List<String> renderTasks(
  List<TaskNode> roots, {
  required int width,
  int? height,
  int frame = 0,
  Spinner spinner = _defaultAnimation,
  String Function(Style style, String text) paint = _noPaint,
}) {
  final whole = height == null;
  // Each row, and whether it is a finished task that can fold.
  final rows = <(String, bool)>[];
  String dim(String text) => paint(_darkGray, text);

  void add(TaskNode node, String indent) {
    final frames = spinner.frames;
    final (mark, suffix) = switch (node.status) {
      TaskStatus.pending => (dim('·'), ''),
      TaskStatus.running => (
          paint(
            _lightGreen,
            frames.isEmpty ? '•' : _taskText(frames[frame % frames.length]),
          ),
          '',
        ),
      TaskStatus.success => (paint(_lightGreen, '✓'), ''),
      TaskStatus.failed => (paint(_red, '✗'), ''),
      TaskStatus.skipped => (
          paint(_yellow, '↓'),
          ' ${dim(node.skipReason == null ? 'skipped' : 'skipped: ${_taskText(node.skipReason!)}')}',
        ),
    };
    final time = node.elapsed == null ||
            node.status == TaskStatus.skipped ||
            node.status == TaskStatus.pending
        ? ''
        : ' ${dim('(${_formatElapsed(node.elapsed!)})')}';
    final title = node.status == TaskStatus.pending
        ? dim(_taskText(node.title))
        : _taskText(node.title);
    final hasFailure = node._hasFailure;
    final done =
        node.status == TaskStatus.success || node.status == TaskStatus.skipped;
    rows.add(('$indent$mark $title$suffix$time', done && !hasFailure));

    final inner = '$indent  ';
    if (node.status == TaskStatus.running && node.output.isNotEmpty) {
      rows.add(('$inner${dim('› ${_taskText(node.output.last)}')}', false));
    }
    if (node.status == TaskStatus.failed) {
      final output = node.output;
      final shown = whole ? output.length : min(output.length, _failedTail);
      if (shown < output.length) {
        rows.add((
          '$inner${dim('… ${output.length - shown} earlier lines')}',
          false,
        ));
      }
      for (final line in output.skip(output.length - shown)) {
        rows.add(('$inner${dim(_taskText(line))}', false));
      }
      final error = node.error;
      // A failure from nested steps is shown on the step itself.
      if (error != null &&
          !(error is TasksFailed &&
              node.children.isNotEmpty &&
              !node._ownFailure)) {
        rows.add(('$inner${paint(_red, _taskText(error))}', false));
      }
    }
    if (node.status == TaskStatus.running || hasFailure) {
      for (final child in node.children) {
        add(child, inner);
      }
    }
  }

  for (final root in roots) {
    add(root, '');
  }
  if (!whole && height <= 1) return [];
  final fitted = whole ? rows : _fold(rows, height - 1, dim);
  return [for (final (text, _) in fitted) truncate(text, max(width - 1, 0))];
}

/// Folds finished rows, first to last, into one `… n done` row until
/// [rows] fits in [maxRows]; then cuts what is still too tall.
List<(String, bool)> _fold(
  List<(String, bool)> rows,
  int maxRows,
  String Function(String) dim,
) {
  if (rows.length <= maxRows) return rows;
  final foldable = rows.where((row) => row.$2).length;
  final folded = min(rows.length - maxRows + 1, foldable);
  var skipped = 0;
  final kept = [
    if (folded > 0) (dim('… $folded done'), false),
    for (final row in rows)
      if (!row.$2 || skipped++ >= folded) row,
  ];
  // ponytail: cuts the bottom rows when running tasks alone overflow;
  // scroll to the newest if that ever matters.
  return kept.length > maxRows ? kept.sublist(0, maxRows) : kept;
}

/// One [Logger.tasks] call: the task tree, the live region and the plain
/// lines.
final class _TaskRun implements _Live {
  _TaskRun(this._logger, this._exitOnError);

  final Logger _logger;
  final bool _exitOnError;
  final _roots = <TaskNode>[];
  final _failures =
      <TaskNode, ({String title, Object error, StackTrace stackTrace})>{};
  final _nestedFailures = <TaskNode, Set<TasksFailed>>{};
  final _clock = Stopwatch();
  late final bool _plain = _logger._plain;

  /// Above [Level.info]: only failures and the summary, on stderr.
  late final bool _silent = _logger.level.index > Level.info.index;
  late final _Paint _paint = _logger._painter(_logger._out);
  bool _stopped = false;
  bool _final = false;
  Timer? _timer;
  int _tick = 0;
  int _count = 0;

  bool get _live => !_plain && !_silent;

  Future<void> run(List<Task> tasks, int concurrency) async {
    _checkConcurrency(concurrency);
    if (tasks.isEmpty) return;
    if (_live) {
      if (_logger._active is _TaskRun) {
        throw StateError(
          'A task list is already running. '
          'Use TaskContext.tasks for nested steps.',
        );
      }
      _logger._active?._stop();
      _logger._active = this;
    }
    _clock.start();
    try {
      if (_live) {
        _timer = Timer.periodic(_logger.progressOptions.animation.interval, (
          _,
        ) {
          _tick++;
          _logger._drawRegion();
        });
      }
      await _runLevel(tasks, concurrency, null, '');
    } finally {
      _clock.stop();
      if (_live) _release();
    }
    _summary();
    if (_exitOnError && _failures.isNotEmpty) {
      throw TasksFailed(List.unmodifiable(_failures.values));
    }
  }

  /// Draws the final frame, in full, and leaves it above the cursor.
  void _release() {
    _timer?.cancel();
    _final = true;
    final logger = _logger;
    if (logger._hasOpenLine) {
      logger
        .._out.write('\n')
        .._hasOpenLine = false;
    }
    logger
      .._drawRegion()
      .._out.write('\n')
      .._rows = 0;
    if (identical(logger._active, this)) logger._active = null;
  }

  @override
  List<String> _frame(int columns, int rows) => renderTasks(
        _roots,
        width: columns,
        height: _final ? null : rows,
        frame: _tick,
        spinner: _logger.progressOptions.animation,
        paint: _paint,
      );

  /// A task list is never taken over: a [Progress] started while it runs
  /// writes plain lines above it.
  @override
  bool _stop() => false;

  void _checkConcurrency(int concurrency) {
    if (concurrency < 1) {
      throw ArgumentError.value(
        concurrency,
        'concurrency',
        'must be at least 1',
      );
    }
  }

  Future<void> _runLevel(
    List<Task> tasks,
    int concurrency,
    TaskNode? parent,
    String prefix,
  ) async {
    _checkConcurrency(concurrency);
    final nodes = [for (final task in tasks) TaskNode(_taskText(task.title))];
    (parent?.children ?? _roots).addAll(nodes);
    _count += nodes.length;
    if (_live) _logger._drawRegion();
    var next = 0;
    Future<void> worker() async {
      while (next < nodes.length) {
        final i = next++;
        await _runOne(tasks[i], nodes[i], prefix);
      }
    }

    await Future.wait([
      for (var i = 0; i < min(concurrency, nodes.length); i++) worker(),
    ]);
    if (parent == null || !_exitOnError) return;
    final descendants = <TaskNode>{};
    void collect(List<TaskNode> nodes) {
      for (final node in nodes) {
        descendants.add(node);
        collect(node.children);
      }
    }

    collect(nodes);
    final mine = [
      for (final entry in _failures.entries)
        if (descendants.contains(entry.key)) entry.value,
    ];
    if (mine.isNotEmpty) {
      final error = TasksFailed(mine);
      (_nestedFailures[parent] ??= {}).add(error);
      throw error;
    }
  }

  Future<void> _runOne(Task task, TaskNode node, String prefix) async {
    final context = TaskContext._(this, node, prefix);
    final clock = Stopwatch()..start();
    try {
      if (_stopped || !(task.enabled?.call() ?? true)) {
        node.status = TaskStatus.skipped;
      } else {
        node.status = TaskStatus.running;
        await task.run(context);
        node.status = TaskStatus.success;
      }
    } on _Skip catch (skip) {
      node
        ..status = TaskStatus.skipped
        ..skipReason = skip.reason;
    } catch (error, stack) {
      node
        ..status = TaskStatus.failed
        ..error = error;
      if (!(error is TasksFailed &&
          (_nestedFailures[node]?.contains(error) ?? false))) {
        node._ownFailure = true;
        _failures[node] =
            (title: context._path, error: error, stackTrace: stack);
      }
      if (_exitOnError) _stopped = true;
    }
    node.elapsed = clock.elapsed;
    _report(node, context._path);
  }

  /// Plain and silent modes: one line for the finished task.
  void _report(TaskNode node, String path) {
    if (_live) return;
    final failed = node.status == TaskStatus.failed;
    if (_silent && !failed) return;
    final sink = _silent ? _logger._err : _logger._out;
    final paint = _logger._painter(sink);
    if (_silent) {
      for (final line in node.output) {
        _logger._emit(sink, '$path | $line\n');
      }
    }
    final time = paint(_darkGray, '(${_formatElapsed(node.elapsed!)})');
    final error = node.error;
    final line = switch (node.status) {
      TaskStatus.success => '${paint(_lightGreen, '✓')} $path $time',
      TaskStatus.failed
          when error is TasksFailed &&
              node.children.isNotEmpty &&
              !node._ownFailure =>
        '${paint(_red, '✗')} $path',
      TaskStatus.failed => '${paint(_red, '✗')} $path: ${_taskText(error!)}',
      _ => node.skipReason == null
          ? '- $path skipped'
          : '- $path skipped: ${_taskText(node.skipReason!)}',
    };
    _logger._emit(sink, '$line\n');
  }

  void _log(TaskContext context, String text) {
    final lines = _cleanLines(text);
    context._node.output.addAll(lines);
    if (_silent) return;
    final verbose = _logger.level == Level.verbose;
    if (!_plain && !verbose) return;
    for (final line in lines) {
      final path = context._path;
      _logger._emit(
        _logger._out,
        '${_plain ? '$path |' : _paint(_darkGray, '$path |')} $line\n',
      );
    }
  }

  void _summary() {
    final sink = _silent ? _logger._err : _logger._out;
    final paint = _logger._painter(sink);
    var skipped = 0;
    void count(List<TaskNode> nodes) {
      for (final node in nodes) {
        if (node.status == TaskStatus.skipped) skipped++;
        count(node.children);
      }
    }

    count(_roots);
    final time = paint(_darkGray, '(${_formatElapsed(_clock.elapsed)})');
    final line = _failures.isEmpty
        ? '${paint(_lightGreen, '✓')} $_count ${_count == 1 ? 'task' : 'tasks'}'
            '${skipped > 0 ? ', $skipped skipped' : ''} $time'
        : '${paint(_red, '✗')} ${_failures.length} of $_count failed $time';
    _logger._emit(sink, '$line\n');
  }
}

/// Splits logged text into terminal rows: text after a `\r` replaces the
/// row, as a terminal shows it; escapes and control characters are dropped
/// and tabs become spaces, so each row's width is exact.
List<String> _cleanLines(String text) {
  final lines = text.split('\n');
  if (lines.length > 1 && lines.last.isEmpty) lines.removeLast();
  return [
    for (final line in lines)
      stripAnsiSequences(line.split('\r').last)
          .replaceAll('\t', '    ')
          .replaceAll(RegExp(r'[\x00-\x1f\x7f-\x9f]'), ''),
  ];
}

String _taskText(Object value) {
  String text;
  try {
    text = '$value';
  } catch (_) {
    return '<unprintable error>';
  }
  return _cleanLines(text).join(' ');
}
