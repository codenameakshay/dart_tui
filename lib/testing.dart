/// Test helpers for dart_tui apps: drive a real [Program] with keys and
/// messages, read its screen, and compare screens with golden files.
///
/// ```dart
/// import 'package:dart_tui/dart_tui.dart';
/// import 'package:dart_tui/testing.dart';
///
/// final t = TuiTester(CounterModel());
/// await t.press('up');
/// await t.waitFor((screen) => screen.contains('Count: 1'));
/// expectScreen(t.screen, 'test/goldens/counter.txt');
/// final result = await t.quit();
/// ```
///
/// It imports no test framework: failures throw [TuiTestFailure], so it works
/// with `package:test` or any other runner.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'src/ansi_state.dart' show stripAnsiSequences;
import 'src/bubbles/style.dart';
import 'src/cmd.dart';
import 'src/input_decoder.dart';
import 'src/model.dart';
import 'src/msg.dart';
import 'src/program.dart';
import 'src/prompts.dart' show promptSelect;
import 'src/view.dart';

/// A failed [TuiTester.waitFor] or [expectScreen].
final class TuiTestFailure implements Exception {
  TuiTestFailure(this.message);
  final String message;
  @override
  String toString() => 'TuiTestFailure: $message';
}

/// An [IOSink] that keeps everything written to it in memory, as text.
///
/// Bytes passed to [add] are decoded as UTF-8.
final class CaptureSink implements IOSink {
  CaptureSink([StringBuffer? buffer]) : buffer = buffer ?? StringBuffer();

  /// The text written so far.
  final StringBuffer buffer;

  /// [buffer] as a string.
  String get text => buffer.toString();

  /// Empties [buffer].
  void clear() {
    buffer.clear();
    _decoder = null;
  }

  Sink<List<int>>? _decoder;

  @override
  Encoding get encoding => _encoding;
  Encoding _encoding = utf8;
  @override
  set encoding(Encoding value) {
    _decoder?.close();
    _decoder = null;
    _encoding = value;
  }

  @override
  void write(Object? object) => buffer.write(object);
  @override
  void writeln([Object? object = '']) => buffer.writeln(object);
  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      buffer.writeAll(objects, separator);
  @override
  void writeCharCode(int charCode) => buffer.writeCharCode(charCode);
  @override
  void add(List<int> data) => (_decoder ??= encoding.decoder
          .startChunkedConversion(StringConversionSink.fromStringSink(buffer)))
      .add(data);
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final data in stream) {
      add(data);
    }
  }

  @override
  Future<void> flush() async {}
  @override
  Future<void> close() async {
    _decoder?.close();
    _decoder = null;
  }

  @override
  Future<void> get done async {}
}

/// How a [TuiTester] run ended.
final class TuiResult {
  TuiResult._(this.model, this.screen, this.styledScreen, this.value);

  /// The last model, after its last update (null if no program ran).
  final Model? model;

  /// The last view as plain text (see [TuiTester.screen]).
  final String screen;

  /// The last view with its escape codes (see [TuiTester.styledScreen]).
  final String styledScreen;

  /// What the body of [TuiTester.run] returned. For [TuiTester.new], the
  /// final model.
  final Object? value;

  /// The model's outcome when it is an [OutcomeModel], else null.
  Object? get outcome => switch (model) {
        final OutcomeModel<Object?> m => m.outcome,
        _ => null,
      };
}

/// Runs a [Model] in a real [Program], headless, for tests.
///
/// Each program gets a fixed [width] x [height] (also its first
/// [WindowSizeMsg]), an empty environment, plain mode off, no renderer, no
/// stdin and no signal handlers. [Style.defaultProfile] is pinned to
/// [profile] and [Style.hasDarkBackground] starts as [darkBackground]
/// (a `COLORFGBG` in [environment] or a sent [BackgroundColorMsg] changes it,
/// as in a terminal); both are restored when the run ends. Requests that need a terminal reply (such as
/// [RequestBackgroundColorMsg]) get fixed answers. [options] are applied
/// last, for example `withTickInterval`.
///
/// Every view is recorded after each update, so [screen] is current as soon
/// as a call such as [press] completes. Commands still run asynchronously:
/// use [waitFor] for their results.
///
/// [Style] defaults are process-wide, so run one tester at a time, and call
/// [dispose] in a tear-down (for example `addTearDown(t.dispose)`).
///
/// There is no fake clock: timers and ticks run in real time. Test a spinner
/// or timer with a short `withTickInterval` and [waitFor].
final class TuiTester {
  /// Runs [model] in a new [Program].
  TuiTester(
    Model model, {
    int width = 80,
    int height = 24,
    ColorProfile profile = ColorProfile.noColor,
    bool darkBackground = true,
    Map<String, String> environment = const {},
    List<ProgramOption> options = const [],
  }) : this.run(
          () => Program().run(model),
          width: width,
          height: height,
          profile: profile,
          darkBackground: darkBackground,
          environment: environment,
          options: options,
        );

  /// Runs [body], and drives each [Program] it creates and starts, one after
  /// another. Programs created outside [body] do not use this tester.
  ///
  /// Use it for code that makes its own program, such as [promptSelect],
  /// `Form.run` or your app's `main` flow. [TuiResult.value] is what [body]
  /// returns.
  TuiTester.run(
    Future<Object?> Function() body, {
    this.width = 80,
    this.height = 24,
    ColorProfile profile = ColorProfile.noColor,
    bool darkBackground = true,
    Map<String, String> environment = const {},
    List<ProgramOption> options = const [],
  }) {
    _savedProfile = Style.defaultProfile;
    _savedDark = Style.hasDarkBackground;
    Style.defaultProfile = profile;
    Style.hasDarkBackground = darkBackground;
    final hook = _Hook(this, [
      withInput(null),
      withoutRenderer(),
      withoutSignalHandler(),
      withPlainMode(false),
      withEnvironment(environment),
      withColorProfile(profile),
      (program) => withWindowSize(width, height)(program),
      withFps(120),
      ...options,
    ]);
    _run = Future<Object?>.sync(
      () => runZoned(body, zoneValues: {programTestHookKey: hook}),
    ).whenComplete(_ended);
    // A failing run is reported by press, waitFor, quit, done and dispose.
    unawaited(_run.then((_) {}, onError: (Object _) {}));
  }

  /// The window size programs start with (see [resize]).
  int width, height;

  late final Future<Object?> _run;
  late final ColorProfile _savedProfile;
  late final bool _savedDark;
  bool _restored = false;
  bool _disposed = false;
  bool _running = true;
  Program? _program;
  bool _programRunning = false;
  Model? _model;
  View _view = newView('');
  Completer<void> _changed = Completer<void>();
  final List<Completer<void>> _flushes = [];

  void _record(Model model, View view) {
    _model = model;
    _view = view;
    _notify();
  }

  void _notify() {
    final changed = _changed;
    _changed = Completer<void>();
    changed.complete();
  }

  void _programEnded() {
    _programRunning = false;
    for (final flush in _flushes) {
      flush.complete();
    }
    _flushes.clear();
    _notify();
  }

  void _ended() {
    _running = false;
    if (!_restored) {
      _restored = true;
      Style.defaultProfile = _savedProfile;
      Style.hasDarkBackground = _savedDark;
    }
    _programEnded();
  }

  /// The current model (after the last update); null before any program.
  Model? get model => _model;

  /// The current view as text: escape codes removed, trailing spaces trimmed
  /// on every line. This is the view's text, not a terminal emulation: it is
  /// not cut to [width] or [height].
  String get screen => plainScreen(_view.content);

  /// The current view's content with its escape codes.
  String get styledScreen => _view.content;

  /// Whether the run (the model, or the body of [TuiTester.run]) is still
  /// going.
  bool get isRunning => _running;

  /// Sends [msg] and completes once the program has handled it.
  Future<void> send(Msg msg) => _sendAll([msg]);

  /// Presses one key, given as its keystroke name, for example `enter`,
  /// `ctrl+c`, `shift+tab`, `alt+left`, `pgdown`, `f5`, `space` or `a`.
  ///
  /// The key goes through the real input decoder as the bytes a terminal
  /// sends, so the model gets the same [KeyPressMsg] as from a keyboard.
  /// Throws [ArgumentError] when the decoder cannot read that keystroke (for
  /// example `shift+f3`, whose bytes are also a cursor position report).
  Future<void> press(String key) => _sendAll([keyPressFor(key)]);

  /// Types [text], one [KeyPressMsg] per Unicode scalar value, as a terminal
  /// sends it (a space arrives as `space`, a newline as `enter`).
  Future<void> type(String text) => _sendAll([
        for (final rune in text.runes)
          ..._decode(utf8.encode(String.fromCharCode(rune))),
      ]);

  /// Pastes [text] as a bracketed paste: [PasteStartMsg], [PasteMsg] and
  /// [PasteEndMsg], as a terminal sends it.
  Future<void> paste(String text) =>
      _sendAll(_decode(utf8.encode('\x1b[200~$text\x1b[201~')));

  /// Sends a [WindowSizeMsg] for the new size. Later programs start with it.
  Future<void> resize(int width, int height) {
    this.width = width;
    this.height = height;
    if (_program case final program?) {
      withWindowSize(width, height)(program);
    }
    return send(WindowSizeMsg(width, height));
  }

  /// Sends [msgs] to the running program, waiting up to 2 s for the next
  /// program when one has just ended, and completes once they are handled.
  Future<void> _sendAll(List<Msg> msgs) async {
    final clock = Stopwatch()..start();
    while (_running && !_programRunning) {
      final left = const Duration(seconds: 2) - clock.elapsed;
      if (left <= Duration.zero) {
        throw TuiTestFailure('no program started within 2000 ms.');
      }
      await _changed.future.timeout(left, onTimeout: () {});
    }
    if (!_running) {
      await _run;
      throw StateError('the program has ended');
    }
    final program = _program!;
    for (final msg in msgs) {
      program.send(msg);
    }
    final flush = Completer<void>();
    _flushes.add(flush);
    program.send(_FlushMsg(flush));
    await flush.future;
    if (!_running) await _run;
  }

  /// Waits until [test] is true for [screen], and returns that screen.
  ///
  /// Throws [TuiTestFailure] with the last screen when [timeout] passes or
  /// the run ends first, and rethrows an error the run ended with.
  Future<String> waitFor(
    bool Function(String screen) test, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final clock = Stopwatch()..start();
    while (true) {
      final current = screen;
      if (test(current)) return current;
      if (!_running) {
        await _run;
        throw TuiTestFailure(
            'the program ended before the screen matched.\n${_frame(current)}');
      }
      final left = timeout - clock.elapsed;
      if (left <= Duration.zero) {
        throw TuiTestFailure('waitFor timed out after '
            '${timeout.inMilliseconds} ms.\n${_frame(current)}');
      }
      await _changed.future.timeout(left, onTimeout: () {});
    }
  }

  /// Sends [QuitMsg] to the running program, then waits as [done] does.
  Future<TuiResult> quit({Duration timeout = const Duration(seconds: 2)}) {
    if (_programRunning) _program?.quit();
    return done(timeout: timeout);
  }

  /// Waits for the run to end on its own (for example an [OutcomeModel] with
  /// an outcome), and returns the result. Throws [TuiTestFailure] when
  /// [timeout] passes first; rethrows an error the run ended with.
  Future<TuiResult> done({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final value = await _run.timeout(timeout, onTimeout: () {
      throw TuiTestFailure('the program did not end within '
          '${timeout.inMilliseconds} ms.\n${_frame(screen)}');
    });
    return TuiResult._(model, screen, styledScreen, value);
  }

  /// Stops the running program, waits for the run to end, and restores the
  /// [Style] defaults. Safe to call more than once; never throws.
  ///
  /// A program the body starts after this is stopped as soon as it starts,
  /// so a prompt helper returns null and the body can finish.
  Future<void> dispose() async {
    _disposed = true;
    if (_programRunning) _program?.kill();
    try {
      await _run.timeout(const Duration(seconds: 2));
    } catch (_) {
      // Reported by press, waitFor, quit or done.
    }
    _ended();
  }
}

final class _Hook implements ProgramTestHook {
  _Hook(this.tester, this.options);
  final TuiTester tester;
  @override
  final List<ProgramOption> options;

  @override
  Model attach(Program program, Model model) {
    tester
      .._program = program
      .._programRunning = true
      .._notify();
    // After dispose, stop it once run() has started it (kill is a no-op
    // before that).
    if (tester._disposed) scheduleMicrotask(program.kill);
    return _Recorder(model, tester);
  }

  @override
  bool handleMessage(Msg msg) {
    if (msg is! _FlushMsg) return false;
    tester._flushes.remove(msg.done);
    msg.done.complete();
    return true;
  }

  @override
  Model unwrap(Model model) => model is _Recorder ? model.inner : model;

  @override
  void detach(Program program) {
    if (identical(program, tester._program)) tester._programEnded();
  }
}

String _frame(String screen) => 'Last screen:\n'
    '──────────\n$screen\n──────────';

/// [content] without escape codes, and with trailing spaces trimmed on every
/// line. This is [TuiTester.screen] for any string, such as a `view()`.
String plainScreen(String content) => stripAnsiSequences(content)
    .split('\n')
    .map((line) => line.trimRight())
    .join('\n');

/// The [KeyPressMsg] a terminal produces for the keystroke [key] (see
/// [TuiTester.press]).
KeyPressMsg keyPressFor(String key) {
  final cut = key.length > 1 ? key.lastIndexOf('+', key.length - 2) : -1;
  final base = key.substring(cut + 1);
  final mods = cut < 0 ? const <String>[] : key.substring(0, cut).split('+');
  const bits = {
    'shift': 1,
    'alt': 2,
    'ctrl': 4,
    'super': 8,
    'hyper': 16,
    'meta': 32,
  };
  var m = 0;
  for (final mod in mods) {
    final bit = bits[mod];
    if (bit == null) {
      throw ArgumentError.value(key, 'key', 'unknown modifier "$mod"');
    }
    m |= bit;
  }
  // The keystroke() spelling: modifiers in a fixed order.
  final want = [
    for (final (name, bit) in const [
      ('ctrl', 4),
      ('alt', 2),
      ('shift', 1),
      ('meta', 32),
      ('hyper', 16),
      ('super', 8),
    ])
      if (m & bit != 0) name,
    base,
  ].join('+');

  const finals = {
    'up': 'A',
    'down': 'B',
    'right': 'C',
    'left': 'D',
    'home': 'H',
    'end': 'F',
    'f1': 'P',
    'f2': 'Q',
    'f3': 'R',
    'f4': 'S',
  };
  const tildes = {
    'insert': 2,
    'delete': 3,
    'pgup': 5,
    'pgdown': 6,
    'f5': 15,
    'f6': 17,
    'f7': 18,
    'f8': 19,
    'f9': 20,
    'f10': 21,
    'f11': 23,
    'f12': 24,
  };
  const named = {
    'enter': 13,
    'tab': 9,
    'esc': 27,
    'backspace': 127,
    'space': 32,
  };
  final rune = base.runes.length == 1 ? base.runes.single : null;
  final code = named[base] ?? rune;

  // What a legacy terminal sends; then the xterm / kitty form with modifiers.
  String? legacy() {
    if (m == 0) {
      if (finals[base] case final f?) return '\x1b[$f';
      if (tildes[base] case final n?) return '\x1b[$n~';
      return code == null ? null : String.fromCharCode(code);
    }
    if (m == 1 && base == 'tab') return '\x1b[Z';
    if (m == 4 && base == 'space') return '\x00';
    if (m == 4 && rune != null && rune >= 0x61 && rune <= 0x7a) {
      return String.fromCharCode(rune - 0x60);
    }
    if (m == 2 && code != null) return '\x1b${String.fromCharCode(code)}';
    return null;
  }

  String? modified() {
    if (m == 0) return null;
    if (finals[base] case final f?) return '\x1b[1;${m + 1}$f';
    if (tildes[base] case final n?) return '\x1b[$n;${m + 1}~';
    return code == null ? null : '\x1b[$code;${m + 1}u';
  }

  for (final bytes in [legacy(), modified()]) {
    if (bytes == null) continue;
    final msgs = _decode(utf8.encode(bytes));
    if (msgs case [final KeyPressMsg msg] when msg.key == want) return msg;
  }
  throw ArgumentError.value(
      key, 'key', 'the input decoder does not read this keystroke');
}

List<Msg> _decode(List<int> bytes) {
  final decoder = TerminalInputDecoder();
  return [...decoder.feed(bytes), ...decoder.takeLoneEscapeIfStillPending()];
}

/// Compares [actual] with the golden file at [path].
///
/// When [update] is true (by default when the environment variable
/// `DART_TUI_UPDATE_GOLDENS` is `1`), it writes [actual] to [path] instead.
/// Throws [TuiTestFailure] when the file is missing or differs, naming the
/// first differing line. Line endings in the file are normalised to `\n`.
///
/// Pass [TuiTester.screen] for a plain-text golden, or
/// [TuiTester.styledScreen] for one that keeps the colours.
void expectScreen(String actual, String path, {bool? update}) {
  final file = File(path);
  if (update ?? Platform.environment['DART_TUI_UPDATE_GOLDENS'] == '1') {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('$actual\n');
    return;
  }
  if (!file.existsSync()) {
    throw TuiTestFailure(
      'golden file $path does not exist. Run the test '
      'with DART_TUI_UPDATE_GOLDENS=1 to create it.',
    );
  }
  var expected = file.readAsStringSync().replaceAll('\r\n', '\n');
  if (expected.endsWith('\n')) {
    expected = expected.substring(0, expected.length - 1);
  }
  if (expected == actual) return;
  final want = expected.split('\n');
  final got = actual.split('\n');
  var line = 0;
  while (line < want.length && line < got.length && want[line] == got[line]) {
    line++;
  }
  String show(List<String> lines) =>
      line < lines.length ? jsonEncode(lines[line]) : '(no line)';
  throw TuiTestFailure(
    'screen does not match golden file $path\n'
    'first difference at line ${line + 1} '
    '(expected ${want.length} lines, got ${got.length}):\n'
    '  expected: ${show(want)}\n'
    '  actual:   ${show(got)}\n'
    'Run with DART_TUI_UPDATE_GOLDENS=1 to accept the new screen.',
  );
}

final class _FlushMsg extends Msg {
  _FlushMsg(this.done);
  final Completer<void> done;
}

/// Wraps the model under test and records every view.
final class _Recorder extends Model implements OutcomeModel<Object?> {
  _Recorder(this.inner, this.tester);

  final Model inner;
  final TuiTester tester;
  late final View _view = inner.view();

  @override
  Object? get outcome => switch (inner) {
        final OutcomeModel<Object?> m => m.outcome,
        _ => null,
      };

  @override
  Cmd? init() => inner.init();

  @override
  (Model, Cmd?) update(Msg msg) {
    final (next, cmd) = inner.update(msg);
    final wrapped = _Recorder(next, tester);
    tester._record(next, wrapped._view);
    return (wrapped, cmd);
  }

  @override
  View view() {
    tester._record(inner, _view);
    return _view;
  }
}
