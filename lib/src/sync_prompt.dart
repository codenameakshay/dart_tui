part of 'program.dart';

/// Internal: the byte source sync prompts read instead of the process stdin.
/// Tests put one in the zone under [syncPromptInputKey].
abstract interface class SyncPromptInput {
  /// The next byte, blocking until there is one, or -1 at the end of input.
  int readByte();

  /// Whether [readByte] would return within [timeout]. Used after an `ESC`
  /// byte to tell a lone Escape key from the start of a key sequence.
  bool waitForByte(Duration timeout);
}

/// Internal zone key: a [SyncPromptInput] for the sync prompts.
final Object syncPromptInputKey = Object();

/// Internal zone key: the `Never Function(int)` a sync prompt calls with 130
/// after Ctrl+C. Without one it is `dart:io`'s `exit`.
final Object promptExitKey = Object();

/// How long a sync prompt waits after `ESC` for the rest of a key sequence.
/// A terminal writes a whole sequence at once, so its bytes are already
/// waiting; a lone Escape key costs this much.
const Duration _syncEscWait = Duration(milliseconds: 50);

/// Process stdin for sync prompts: bytes an async plain prompt read ahead
/// (held by [_SharedStdin]) first, then `readByteSync`.
///
/// Once an async reader has seen the end of input, Dart has closed fd 0, so
/// only the held bytes are left. A read error also ends the input, as an
/// input error cancels an async prompt.
final class _StdinSyncInput implements SyncPromptInput {
  _StdinSyncInput(this._pending, {required bool ended}) : _ended = ended;

  final List<int> _pending;
  bool _ended;

  @override
  int readByte() {
    if (_pending.isNotEmpty) return _pending.removeAt(0);
    if (_ended) return -1;
    try {
      final byte = stdin.readByteSync();
      if (byte < 0) _ended = true;
      return byte;
    } on StdinException {
      _ended = true;
      return -1;
    }
  }

  /// One line, without its newline, or null at the end of input.
  String? readLine() {
    if (_pending.isEmpty && !_ended) {
      String? line;
      try {
        line = stdin.readLineSync(
          encoding: const Utf8Codec(allowMalformed: true),
          retainNewlines: true,
        );
      } on StdinException {
        line = null;
      }
      if (line == null || !line.endsWith('\n')) _ended = true;
      return line == null || !line.endsWith('\n')
          ? line
          : line.substring(0, line.length - 1);
    }
    // Held bytes may end inside a character: read the rest of the line as
    // bytes too, and decode it once.
    return _readLineBytes(this);
  }

  @override
  bool waitForByte(Duration timeout) =>
      _pending.isNotEmpty ||
      _ended ||
      (Platform.isWindows
          ? windowsInputReady(timeout)
          : posixInputReady(timeout));
}

/// Opens the input for a sync prompt that [program] describes, or returns
/// null when it has no input (`withInput(null)`).
///
/// Throws a [StateError] while a [Program] or an async prompt reads stdin, or
/// under `TuiTester`, and an [ArgumentError] for `withInput(stream)`: a stream
/// cannot be read synchronously.
(SyncPromptInput, bool)? _openSyncInput(Program program, String name) {
  final injected = Zone.current[syncPromptInputKey];
  if (injected is SyncPromptInput) return (injected, false);
  if (program._testHook != null) {
    throw StateError(
      '$name blocks the isolate, so TuiTester cannot drive it. Test the '
      'async prompt instead.',
    );
  }
  if (program._disableInput) return null;
  if (!program._usesSharedStdin) {
    throw ArgumentError(
      '$name reads the process stdin and cannot read a withInput stream. '
      'Use the async prompt to read a stream.',
    );
  }
  program._checkStdinIsolate();
  if (_sharedStdin.busy) {
    throw StateError(
      '$name cannot run while a Program or an async prompt reads stdin: '
      'there would be two readers. Await it first, or use the async prompt.',
    );
  }
  return (
    _StdinSyncInput(_sharedStdin.takePending(), ended: _sharedStdin._closed),
    true,
  );
}

/// Gives bytes a sync prompt did not use back to the shared stdin owner.
void _closeSyncInput(SyncPromptInput input) {
  if (input is _StdinSyncInput) _sharedStdin.giveBack(input._pending);
}

/// Runs [initial] without an event loop: raw mode, `readByteSync`, the same
/// key decoder, `update` and `view` as a [Program], and an inline repaint.
/// Returns the final model, or null when input ended first. Ctrl+C restores
/// the terminal and then exits with code 130.
///
/// No commands run: a command is called only to see whether it quits. The
/// prompt models need nothing else.
Model? runModelSync(Program program, Model initial, {required String name}) {
  final opened = _openSyncInput(program, name);
  if (opened == null) return null;
  final (input, realStdin) = opened;
  var model = initial;
  var interrupted = false;
  final restoreStyle = program._applyStyleDefaults();
  final renderer = program._disableRenderer
      ? NilRenderer()
      : program._useCellRenderer
          ? CellRenderer(
              output: program._output,
              defaultAltScreen: program._altScreen,
              defaultHideCursor: program._hideCursor,
              defaultMouseMode: program._defaultMouseMode,
              defaultReportFocus: program._defaultReportFocus,
            )
          : AnsiRenderer(
              output: program._output,
              defaultAltScreen: program._altScreen,
              defaultHideCursor: program._hideCursor,
              defaultMouseMode: program._defaultMouseMode,
              defaultReportFocus: program._defaultReportFocus,
            );
  final raw = realStdin && !program._disableRenderer;
  var ended = false;
  try {
    if (raw) program._setRawMode(true);
    renderer.render(model.view());
    final decoder = TerminalInputDecoder();
    var done = false;
    while (!done) {
      final byte = input.readByte();
      final List<Msg> msgs;
      if (byte < 0) {
        // The end of input: a held ESC was a lone Escape key.
        msgs = decoder.takeLoneEscapeIfStillPending();
        ended = msgs.isEmpty;
        done = true;
      } else {
        final decoded = decoder.feed([byte]);
        msgs = decoder.hasPendingLoneEscape && !input.waitForByte(_syncEscWait)
            ? [...decoded, ...decoder.takeLoneEscapeIfStillPending()]
            : decoded;
      }
      if (msgs.isEmpty) continue;
      for (final msg in msgs) {
        if (msg is KeyMsg && msg.key == 'ctrl+c') interrupted = true;
        final (next, cmd) = model.update(msg);
        model = next;
        if (interrupted ||
            _quits(cmd) ||
            (model is OutcomeModel && model.outcome != null)) {
          done = true;
          break;
        }
      }
      renderer.render(model.view());
    }
  } finally {
    // The same order as Program's shutdown: cook the terminal, reset its
    // modes (showing the cursor), then end on a fresh line. A failing write
    // must not skip the rest.
    try {
      if (raw) program._setRawMode(false);
    } finally {
      try {
        final altScreen = renderer.altScreenActive;
        renderer.close();
        if (!program._disableRenderer && !altScreen) program._output.writeln();
      } finally {
        restoreStyle();
        _closeSyncInput(input);
      }
    }
  }
  if (interrupted) {
    final onExit = Zone.current[promptExitKey];
    (onExit is Never Function(int) ? onExit : exit)(130);
  }
  return ended ? null : model;
}

/// Calls [cmd] to see whether it quits. A command that returns a [Future]
/// does not quit here.
bool _quits(Cmd? cmd) {
  if (cmd == null) return false;
  final msg = cmd();
  return msg is QuitMsg || msg is InterruptMsg;
}

/// [PlainSession] without an event loop: the same questions, rule and
/// output, read with `stdin.readLineSync`.
final class SyncPlainSession {
  SyncPlainSession._(this._out, this._input, this._realStdin);

  /// A session for [program] when it is in plain mode (the [PlainSession]
  /// rule), else null. See [_openSyncInput] for what it throws.
  static SyncPlainSession? open(Program program, String name) {
    if (!PlainSession._isPlain(program)) return null;
    final opened = _openSyncInput(program, name);
    return SyncPlainSession._(
      program._output,
      opened?.$1,
      opened?.$2 ?? false,
    );
  }

  final IOSink _out;
  final SyncPromptInput? _input;
  final bool _realStdin;

  /// Runs [body], then gives unread input back to the stdin owner.
  T run<T>(T Function(SyncPlainSession session) body) {
    try {
      return body(this);
    } finally {
      final input = _input;
      if (input != null) _closeSyncInput(input);
    }
  }

  void write(String text) =>
      _out.write(stripAnsiSequences(text).replaceAll('\x1b', ''));
  void writeln([String text = '']) => write('$text\n');

  int? askChoice(List<String> heading, List<String> labels,
          {int? defaultIndex}) =>
      _ask(_choiceQuestion(heading, labels, defaultIndex: defaultIndex));

  Set<int>? askMany(List<String> heading, List<String> labels,
          {Set<int> defaults = const {}}) =>
      _ask(_manyQuestion(heading, labels, defaults: defaults));

  bool? askConfirm(String question, bool defaultValue) =>
      _ask(_confirmQuestion(question, defaultValue));

  String? askText(String prompt, {String initial = '', bool secret = false}) =>
      _ask(_textQuestion(prompt, initial: initial, secret: secret));

  T? _ask<T extends Object>(_Question<T> question) {
    question.intro.forEach(writeln);
    while (true) {
      write(question.prompt);
      final line = _readLine(secret: question.secret);
      if (line == null) return null;
      switch (question.parse(line)) {
        case _Retry(:final message):
          writeln(message);
        case final T answer:
          return answer;
      }
    }
  }

  /// Reads one answer, or null at the end of input, like
  /// [PlainSession.readLine].
  String? _readLine({required bool secret}) {
    final echoedByTerminal = _realStdin && stdin.hasTerminal;
    final hideEcho = secret && echoedByTerminal;
    final previousEcho = hideEcho ? stdin.echoMode : null;
    if (hideEcho) PlainSession._setEcho(false);
    try {
      final raw = _readRawLine();
      if (raw == null) {
        _out.writeln();
        return null;
      }
      final line =
          stripAnsiSequences(raw).replaceAll(PlainSession._controlChars, '');
      if (!echoedByTerminal) {
        _out.writeln(secret ? '' : line);
      } else if (hideEcho) {
        _out.writeln();
      }
      return line;
    } finally {
      if (previousEcho != null) PlainSession._setEcho(previousEcho);
    }
  }

  /// One line without its newline, or null at the end of input.
  String? _readRawLine() {
    final input = _input;
    if (input == null) return null;
    if (input is _StdinSyncInput) return input.readLine();
    return _readLineBytes(input);
  }
}

/// One line from [input]'s bytes, decoded once, without its newline; null at
/// the end of input.
String? _readLineBytes(SyncPromptInput input) {
  final bytes = <int>[];
  while (true) {
    final byte = input.readByte();
    if (byte < 0 && bytes.isEmpty) return null;
    if (byte < 0 || byte == 0x0a) {
      return utf8.decode(bytes, allowMalformed: true);
    }
    bytes.add(byte);
  }
}
