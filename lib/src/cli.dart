import 'dart:async';
import 'dart:collection' show SplayTreeMap;
import 'dart:io' as io;
import 'dart:math' show max, min;

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import 'ansi_state.dart' show stripAnsiSequences;
import 'bubbles/spinner.dart';
import 'bubbles/style.dart';
import 'color_detect.dart';
import 'grapheme_width.dart' show textWidth;
import 'msg.dart' show ColorProfile;
import 'program.dart';
import 'prompts.dart';

part 'cli_completion.dart';
part 'cli_runner.dart';
part 'cli_tasks.dart';

/// How much a [Logger] writes. Each level includes the ones after it.
enum Level {
  /// The most verbose level: everything is logged.
  verbose,

  /// [Logger.detail] and up.
  debug,

  /// The default: [Logger.info], [Logger.success], progress and up.
  info,

  /// [Logger.warn] and up.
  warning,

  /// [Logger.err] and up.
  error,

  /// Only [Logger.alert].
  critical,

  /// Nothing is logged.
  quiet,
}

/// How a [Progress] looks.
final class ProgressOptions {
  const ProgressOptions({
    this.animation = _defaultAnimation,
    this.trailing = '...',
  });

  /// The spinner frames and the time each one shows. Any [Spinner] preset
  /// works, for example [Spinner.dot].
  final Spinner animation;

  /// Text after the message while it runs.
  final String trailing;
}

/// mason_logger's default: the [Spinner.miniDot] frames every 80 ms.
const _defaultAnimation = Spinner(
  ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'],
  Duration(milliseconds: 80),
);

const _darkGray = Style(foreground256: 8);
const _lightGreen = Style(foreground256: 10);
const _red = Style(foreground256: 1);

String _singleLine(String text) => text.replaceAll(RegExp(r'[\r\n]+'), ' ');

/// `42ms` under 100 ms, else `1.2s`.
String _formatElapsed(Duration elapsed) {
  final ms = elapsed.inMilliseconds;
  return ms < 100 ? '${ms}ms' : '${(ms / 1000).toStringAsFixed(1)}s';
}

/// What draws the live region at the bottom of stdout: a [Progress] or a
/// task list.
abstract interface class _Live {
  /// The rows to draw, each already cut to fit [columns] - 1.
  List<String> _frame(int columns, int rows);

  /// Stops the timer when another region takes over.
  bool _stop();
}

/// A logger for command-line tools, shaped like `mason_logger`'s `Logger`.
///
/// [info], [detail] and [success] write to stdout; [warn], [err] and
/// [alert] write to stderr. Prompts use dart_tui's prompt helpers
/// ([promptInput], [promptConfirm], [promptSelect], [promptMultiSelect]): a
/// TUI on a terminal, and plain line questions in pipes, CI and with
/// `ACCESSIBLE=1` (see [withPlainMode]). Colours follow
/// [detectColorProfile], so `NO_COLOR` and pipes turn them off.
///
/// Unlike `mason_logger`, prompts return a [Future]. Each one has a blocking
/// twin ([promptSync], [promptAnySync], [confirmSync], [chooseOneSync],
/// [chooseAnySync]) for code that is already synchronous.
///
/// Sync prompts work in any isolate, but their stdin guard only checks the
/// calling isolate. Do not let another isolate read stdin or change terminal
/// mode at the same time (see [promptSelectSync]).
///
/// Cancelling a prompt (Esc or Ctrl+C in the TUI) exits the process with
/// code 130, as `mason_logger` does on Ctrl+C. When input ends in plain
/// mode, the prompt returns its default instead.
///
/// [stdout], [stderr], [stdin] and [environment] replace the real ones, for
/// tests. A custom [stdin] is listened to once per prompt, so pass a
/// broadcast stream to answer several prompts. [exit] replaces `dart:io`'s
/// `exit` for the cancel case.
final class Logger {
  Logger({
    this.level = Level.info,
    this.progressOptions = const ProgressOptions(),
    io.IOSink? stdout,
    io.IOSink? stderr,
    Stream<List<int>>? stdin,
    Map<String, String>? environment,
    Never Function(int code)? exit,
  })  : _out = stdout ?? io.stdout,
        _err = stderr ?? io.stderr,
        _in = stdin,
        _env = environment ?? io.Platform.environment,
        _exit = exit ?? io.exit;

  /// The lowest level that is written.
  Level level;

  /// The options [progress] uses when it gets none.
  ProgressOptions progressOptions;

  final io.IOSink _out;
  final io.IOSink _err;
  final Stream<List<int>>? _in;
  final Map<String, String> _env;
  final Never Function(int code) _exit;
  final _queue = <String?>[];

  /// The live region, drawn below everything else on stdout.
  _Live? _active;

  /// How many rows the live region has on screen. The cursor stays at the
  /// end of the last one.
  int _rows = 0;
  bool _hasOpenLine = false;

  /// Set by [CliRunner]'s `--[no-]color` and `--plain` while a command runs.
  ColorProfile? _profile;
  bool _forcePlain = false;

  List<ProgramOption> get _options => [
        if (_in case final input?) withInput(input),
        if (!identical(_out, io.stdout)) withOutput(_out),
        withEnvironment(_env),
        if (_forcePlain) withPlainMode(),
        if (_profile case final profile?) withColorProfile(profile),
      ];

  /// The prompt helpers' plain-mode rule, for the same input and output.
  bool get _plain => PlainSession.open(Program(options: _options)) != null;

  String _paint(io.IOSink sink, Style style, String text) =>
      _painter(sink)(style, text);

  /// Paints text for [sink], deciding plain mode and colour once.
  _Paint _painter(io.IOSink sink) {
    if (_plain) return _noPaint;
    final terminal = identical(sink, io.stdout)
        ? stdoutIsTerminal()
        : identical(sink, io.stderr) && io.stderr.hasTerminal;
    final profile =
        _profile ?? detectColorProfile(environment: _env, isTerminal: terminal);
    // No colour means no escapes at all, not even bold, when the profile is
    // forced or the output is not a terminal.
    if (profile == ColorProfile.noColor && (_profile != null || !terminal)) {
      return _noPaint;
    }
    return (style, text) => style.copyWith(profile: profile).render(text);
  }

  /// Writes [text] to [sink]. The live region is cleared first and drawn
  /// again after it, when [text] ends a line.
  void _emit(io.IOSink sink, String text) {
    if (_plain) text = stripAnsiSequences(text).replaceAll('\x1b', '');
    if (_active == null) {
      sink.write(text);
      if (text.isNotEmpty) _hasOpenLine = !text.endsWith('\n');
      return;
    }
    if (!_hasOpenLine) _clearRegion();
    sink.write(text);
    if (text.isNotEmpty) _hasOpenLine = !text.endsWith('\n');
    _drawRegion();
  }

  /// The terminal's columns and rows, or 80x24 without one.
  (int, int) get _size {
    final out = _out;
    return out is io.Stdout && out.hasTerminal
        ? (out.terminalColumns, out.terminalLines)
        : (80, 24);
  }

  /// Erases the live region and leaves the cursor where it started.
  void _clearRegion() {
    if (_rows > 1) {
      _out.write('\r\x1b[${_rows - 1}A\x1b[J');
    } else {
      _out.write('\r\x1b[K');
    }
    _rows = 0;
  }

  /// Draws the live region over the old one: cursor up, then each row
  /// followed by clear-line. Nothing is drawn after a partial line.
  void _drawRegion() {
    final live = _active;
    if (live == null || _hasOpenLine) return;
    final (columns, rows) = _size;
    final lines = live._frame(columns, rows);
    final out = StringBuffer('\r');
    if (_rows > 1) out.write('\x1b[${_rows - 1}A');
    out
      ..write(lines.join('\x1b[K\n'))
      ..write('\x1b[K');
    if (lines.length < _rows) out.write('\x1b[J');
    _out.write(out);
    _rows = max(lines.length, 1);
  }

  void _log(
    Level at,
    io.IOSink sink,
    String? message,
    Style base,
    String? Function(String?)? style,
  ) {
    if (level.index > at.index) return;
    final text =
        style == null ? _paint(sink, base, '$message') : style(message);
    _emit(sink, '${text ?? message}\n');
  }

  /// Writes [message] to stdout as it is, with no newline.
  void write(String? message) => _emit(_out, '$message');

  /// Writes [message] to stdout.
  void info(String? message, {String? Function(String? message)? style}) =>
      _log(Level.info, _out, message, const Style(), style);

  /// Writes [message] to stdout in dark grey, at [Level.debug].
  void detail(String? message, {String? Function(String? message)? style}) =>
      _log(Level.debug, _out, message, _darkGray, style);

  /// Writes [message] to stdout in green.
  void success(String? message, {String? Function(String? message)? style}) =>
      _log(Level.info, _out, message, _lightGreen, style);

  /// Writes `[tag] message` to stderr in bold yellow. An empty [tag] writes
  /// the message alone.
  void warn(
    String? message, {
    String tag = 'WARN',
    String? Function(String? message)? style,
  }) =>
      _log(
        Level.warning,
        _err,
        tag.isEmpty ? '$message' : '[$tag] $message',
        const Style(foreground256: 3, isBold: true),
        style,
      );

  /// Writes [message] to stderr in red.
  void err(String? message, {String? Function(String? message)? style}) =>
      _log(Level.error, _err, message, const Style(foreground256: 9), style);

  /// Writes [message] to stderr in bold white on red.
  void alert(String? message, {String? Function(String? message)? style}) =>
      _log(
        Level.critical,
        _err,
        message,
        const Style(foreground256: 15, background256: 1, isBold: true),
        style,
      );

  /// Keeps [message] until [flush].
  void delayed(String? message) => _queue.add(message);

  /// Writes the [delayed] messages with [print] (default [info]).
  void flush([void Function(String?)? print]) {
    final writeln = print ?? info;
    for (final message in _queue) {
      writeln(message);
    }
    _queue.clear();
  }

  /// Starts a spinner line with [message]; end it with [Progress.complete],
  /// [Progress.fail] or [Progress.cancel].
  ///
  /// It runs on a timer and never reads stdin, enters raw mode or catches
  /// signals, so Ctrl+C stops the process as in any CLI.
  Progress progress(String message, {ProgressOptions? options}) =>
      Progress._(this, message, options ?? progressOptions);

  /// Runs [tasks] as a live list: a spinner line per task, the last line of
  /// each running task's output under it, and logs above it. Nested steps
  /// come from [TaskContext.tasks]. At the end it prints one summary line.
  ///
  /// [concurrency] tasks run at once; they always show in the order given.
  /// With [exitOnError], a failure starts no new tasks (they are marked
  /// skipped), waits for the running ones, and then throws [TasksFailed]
  /// with every failure. Without it, every task runs and failures are only
  /// reported.
  ///
  /// In plain mode (pipes, CI) it writes one line per finished task, and
  /// each logged line prefixed with its task's title. Above [Level.info] it
  /// writes only failures and the summary, to stderr. At [Level.verbose]
  /// every logged line is also printed above the list.
  ///
  /// Like [progress], it never reads stdin, enters raw mode, hides the
  /// cursor or catches signals.
  Future<void> tasks(
    List<Task> tasks, {
    int concurrency = 1,
    bool exitOnError = true,
  }) =>
      _TaskRun(this, exitOnError).run(tasks, concurrency);

  Future<T?> _ask<T>(
    Future<T?> Function() prompt, {
    void Function(List<int>)? onSelection,
  }) async {
    final plain = _plain;
    final value = await runZoned(prompt,
        zoneValues: {promptSummaryKey: onSelection ?? true});
    // In plain mode null means the input ended; the caller takes the default.
    if (value == null && !plain) {
      try {
        await _out.flush();
      } catch (_) {}
      _exit(130);
    }
    return value;
  }

  /// Asks for a line of text. Empty input returns [defaultValue] (or an
  /// empty string). With [hidden], the answer is not shown.
  Future<String> prompt(
    String? message, {
    Object? defaultValue,
    bool hidden = false,
  }) async {
    final fallback = defaultValue == null ? '' : '$defaultValue';
    final label = fallback.isEmpty
        ? '$message'
        : '$message ${_paint(_out, _darkGray, '($fallback)')}';
    final answer = await _ask(() => promptInput(label,
        hidden: hidden, defaultValue: fallback, options: _options));
    final value = hidden ? answer : answer?.trim();
    return value == null || value.isEmpty ? fallback : value;
  }

  /// Asks for a line of text and splits it on [separator]. Items are
  /// trimmed, and empty ones dropped.
  Future<List<String>> promptAny(
    String? message, {
    String separator = ',',
  }) async {
    final answer = await _ask(() => promptInput('$message', options: _options));
    return [
      for (final part in (answer ?? '').split(separator))
        if (part.trim().isNotEmpty) part.trim(),
    ];
  }

  /// Asks a yes / no question. Enter returns [defaultValue].
  Future<bool> confirm(String? message, {bool defaultValue = false}) async =>
      await _ask(() => promptConfirm('$message',
          defaultValue: defaultValue, options: _options)) ??
      defaultValue;

  /// Asks for one of [choices], shown with [display] (default `toString`).
  /// The cursor starts on [defaultValue], or the first choice.
  Future<T> chooseOne<T extends Object?>(
    String? message, {
    required List<T> choices,
    T? defaultValue,
    String Function(T choice)? display,
  }) async {
    if (choices.isEmpty) {
      throw ArgumentError.value(choices, 'choices', 'must not be empty');
    }
    final labels = [for (final c in choices) display?.call(c) ?? '$c'];
    final start =
        defaultValue == null ? 0 : max(0, choices.indexOf(defaultValue));
    int? selectedIndex;
    await _ask(
      () => promptSelect(labels,
          title: '$message', initial: start, options: _options),
      onSelection: (indices) => selectedIndex = indices.single,
    );
    return choices[selectedIndex ?? start];
  }

  /// Asks for any number of [choices], shown with [display]. The ones in
  /// [defaultValues] start checked.
  Future<List<T>> chooseAny<T extends Object?>(
    String? message, {
    required List<T> choices,
    List<T>? defaultValues,
    String Function(T choice)? display,
  }) async {
    final labels = [for (final c in choices) display?.call(c) ?? '$c'];
    final initial = {
      for (final v in defaultValues ?? <T>[])
        if (choices.contains(v)) choices.indexOf(v),
    };
    List<int>? selectedIndices;
    await _ask(
      () => promptMultiSelect(labels,
          title: '$message', initial: initial, options: _options),
      onSelection: (indices) => selectedIndices = indices,
    );
    final indices = selectedIndices ?? (initial.toList()..sort());
    return [for (final i in indices) choices[i]];
  }

  T? _askSync<T>(
    String name,
    T? Function() prompt, {
    void Function(List<int>)? onSelection,
  }) {
    if (_in != null) {
      throw StateError(
        'Logger.$name reads the process stdin, and this Logger was given a '
        'stdin stream. Use the async ${name.replaceAll('Sync', '')}.',
      );
    }
    final plain = _plain;
    final value = runZoned(prompt, zoneValues: {
      promptSummaryKey: onSelection ?? true,
      promptExitKey: _exit,
    });
    if (value == null && !plain) _exit(130);
    return value;
  }

  /// Like [prompt], but blocks and returns the answer, as mason_logger's
  /// `prompt` does. For code that is already synchronous; see
  /// [promptInputSync] for what sync prompts can't do.
  String promptSync(
    String? message, {
    Object? defaultValue,
    bool hidden = false,
  }) {
    final fallback = defaultValue == null ? '' : '$defaultValue';
    final label = fallback.isEmpty
        ? '$message'
        : '$message ${_paint(_out, _darkGray, '($fallback)')}';
    final answer = _askSync(
        'promptSync',
        () => promptInputSync(label,
            hidden: hidden, defaultValue: fallback, options: _options));
    final value = hidden ? answer : answer?.trim();
    return value == null || value.isEmpty ? fallback : value;
  }

  /// Like [promptAny], but blocks and returns the answer.
  List<String> promptAnySync(String? message, {String separator = ','}) {
    final answer = _askSync(
        'promptAnySync', () => promptInputSync('$message', options: _options));
    return [
      for (final part in (answer ?? '').split(separator))
        if (part.trim().isNotEmpty) part.trim(),
    ];
  }

  /// Like [confirm], but blocks and returns the answer.
  bool confirmSync(String? message, {bool defaultValue = false}) =>
      _askSync(
          'confirmSync',
          () => promptConfirmSync('$message',
              defaultValue: defaultValue, options: _options)) ??
      defaultValue;

  /// Like [chooseOne], but blocks and returns the answer.
  T chooseOneSync<T extends Object?>(
    String? message, {
    required List<T> choices,
    T? defaultValue,
    String Function(T choice)? display,
  }) {
    if (choices.isEmpty) {
      throw ArgumentError.value(choices, 'choices', 'must not be empty');
    }
    final labels = [for (final c in choices) display?.call(c) ?? '$c'];
    final start =
        defaultValue == null ? 0 : max(0, choices.indexOf(defaultValue));
    int? selectedIndex;
    _askSync(
      'chooseOneSync',
      () => promptSelectSync(labels,
          title: '$message', initial: start, options: _options),
      onSelection: (indices) => selectedIndex = indices.single,
    );
    return choices[selectedIndex ?? start];
  }

  /// Like [chooseAny], but blocks and returns the answer.
  List<T> chooseAnySync<T extends Object?>(
    String? message, {
    required List<T> choices,
    List<T>? defaultValues,
    String Function(T choice)? display,
  }) {
    final labels = [for (final c in choices) display?.call(c) ?? '$c'];
    final initial = {
      for (final v in defaultValues ?? <T>[])
        if (choices.contains(v)) choices.indexOf(v),
    };
    List<int>? selectedIndices;
    _askSync(
      'chooseAnySync',
      () => promptMultiSelectSync(labels,
          title: '$message', initial: initial, options: _options),
      onSelection: (indices) => selectedIndices = indices,
    );
    final indices = selectedIndices ?? (initial.toList()..sort());
    return [for (final i in indices) choices[i]];
  }
}

/// A spinner line from [Logger.progress].
///
/// On a terminal it rewrites one line on a timer: the frame, the message
/// and the elapsed time. In plain mode it writes one line when it starts and
/// one when it ends. Below [Level.info] it writes nothing.
final class Progress implements _Live {
  Progress._(this._logger, String message, this._options)
      : _message = _singleLine(message),
        // Inside a task list it writes start and end lines above the list.
        _plain = _logger._plain || _logger._active is _TaskRun,
        _silent = _logger.level.index > Level.info.index {
    _clock.start();
    if (_silent) return;
    if (_plain) {
      _logger._emit(_logger._out, '$_message${_options.trailing}\n');
      return;
    }
    // A new progress takes over the line from an older one.
    _logger._active?._stop();
    _logger._active = this;
    _draw();
    _timer = Timer.periodic(_options.animation.interval, (_) {
      _tick++;
      _draw();
    });
  }

  final Logger _logger;
  final ProgressOptions _options;
  final bool _plain;
  final bool _silent;
  final _clock = Stopwatch();
  String _message;
  Timer? _timer;
  int _tick = 0;
  bool _done = false;

  io.IOSink get _out => _logger._out;

  String get _time =>
      _logger._paint(_out, _darkGray, '(${_formatElapsed(_clock.elapsed)})');

  void _draw() => _logger._drawRegion();

  @override
  List<String> _frame(int columns, int rows) {
    final frames = _options.animation.frames;
    final frame = frames.isEmpty
        ? ''
        : '${_logger._paint(_out, _lightGreen, frames[_tick % frames.length])} ';
    // Keep the line on one row, so \r can redraw it.
    final trailing = _singleLine(_options.trailing);
    final message = truncate(_message, max(columns - 15, 15));
    final line = _singleLine('$frame$message$trailing $_time');
    return [truncate(line, max(columns - 1, 0))];
  }

  /// Changes the message.
  void update(String message) {
    _message = _singleLine(message);
    if (_timer != null) _draw();
  }

  /// Ends with `✓ message (time)`; [update] replaces the message.
  void complete([String? update]) =>
      _end(_logger._paint(_out, _lightGreen, '✓'), update);

  /// Ends with `✗ message (time)`; [update] replaces the message.
  void fail([String? update]) => _end(_logger._paint(_out, _red, '✗'), update);

  /// Ends and removes the line.
  void cancel() {
    final animated = _timer != null;
    if (_stop() && animated && !_logger._hasOpenLine) {
      _out.write('\r\x1b[K');
      _logger._rows = 0;
    }
  }

  /// Stops the timer; false when already ended.
  @override
  bool _stop() {
    if (_done) return false;
    _done = true;
    _timer?.cancel();
    _timer = null;
    _clock.stop();
    if (identical(_logger._active, this)) _logger._active = null;
    return true;
  }

  void _end(String mark, String? update) {
    final animated = _timer != null;
    if (!_stop() || _silent) return;
    final line = '$mark ${_singleLine(update ?? _message)} $_time';
    if (animated) {
      _out.write('${_logger._hasOpenLine ? '\n' : ''}\r$line\x1b[K\n');
      _logger
        .._hasOpenLine = false
        .._rows = 0;
    } else {
      _logger._emit(_out, '$line\n');
    }
  }
}
