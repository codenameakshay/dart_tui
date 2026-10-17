import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'cmd.dart';
import 'input_decoder.dart';
import 'model.dart';
import 'msg.dart';
import 'posix_terminal.dart';
import 'printf_format.dart';
import 'renderer.dart';
import 'terminal_control.dart';
import 'view.dart';
import 'windows_terminal.dart';

typedef ProgramOption = void Function(Program program);

final _SharedStdin _sharedStdin = _SharedStdin();
final Object _commandZoneOwnerKey = Object();

/// Process stdin shared by every [Program] in the main isolate that does not
/// pass [withInput].
///
/// A helper isolate owns the stdin subscription and forwards bytes here. The
/// receiving port keeps this isolate alive only while a program is reading, so
/// `main` can return after the last program instead of hanging on stdin
/// (issue #15). Between programs the reader is paused, so input stays in the
/// terminal for the next program or for a child process. On macOS a paused
/// reader can close fd 0 once an inherited child has used the terminal, so
/// before such a child starts the helper is cancelled and fd 0 restored.
final class _SharedStdin {
  final Set<StreamController<List<int>>> _readers = {};
  RawReceivePort? _port;
  SendPort? _control;
  bool _reading = false;
  bool _closed = false;
  final Map<int, Completer<void>> _settling = {};
  int _settleId = 0;
  Completer<void>? _controlReady;
  Completer<void>? _readingStarted;
  Completer<void>? _execCancelAck;
  int _execCancelToken = 0;
  int _execUsers = 0;
  Completer<void>? _execSetup;
  bool _pinHelperAlive = false;
  bool _stdinExecResetting = false;

  Stream<List<int>> claim() {
    if (_closed) return const Stream<List<int>>.empty();
    late final StreamController<List<int>> reader;
    reader = StreamController<List<int>>(
      onListen: () {
        _readers.add(reader);
        _sync();
      },
      onPause: _sync,
      onResume: _sync,
      onCancel: () {
        _readers.remove(reader);
        _sync();
      },
    );
    return reader.stream;
  }

  void _sync() {
    if (_closed) return;
    // An inherited exec owns the terminal, even if another program reads.
    final wanted =
        _execUsers == 0 && _readers.any((reader) => !reader.isPaused);
    var port = _port;
    if (port == null) {
      // During an inherited exec fd 0 belongs to the child: do not start a
      // new reader until the exec ends and fd 0 has been restored.
      if (_stdinExecResetting || _execUsers > 0 || !wanted) return;
      port = _port = _spawn();
    }
    port.keepIsolateAlive = wanted ||
        _settling.isNotEmpty ||
        _pinHelperAlive ||
        _execCancelAck != null;
    final control = _control;
    if (control != null && wanted != _reading) {
      _reading = wanted;
      control.send(wanted);
      if (wanted) {
        _readingStarted?.complete();
        _readingStarted = null;
      }
    }
  }

  /// Completes once the reader has been told to read (or stdin has closed).
  Future<void> get reading {
    if (_reading || _closed) return Future<void>.value();
    return (_readingStarted ??= Completer<void>()).future;
  }

  /// Completes once the helper has applied every earlier pause or resume, so
  /// while paused it reads nothing that a child process should get.
  Future<void> settle() {
    final control = _control;
    if (control == null || _closed) return Future<void>.value();
    final settled = Completer<void>();
    _settling[++_settleId] = settled;
    _sync();
    control.send(('settle', _settleId));
    return settled.future;
  }

  /// Stops the stdin reader before a child inherits the terminal: on macOS by
  /// detaching it, elsewhere by pausing it. Pair every call with
  /// [endInheritedExec].
  Future<void> beginInheritedExec() async {
    // Count before the first await, so a concurrent program cannot start or
    // resume a reader while another program's child owns fd 0.
    _execUsers++;
    _sync();
    if (!Platform.isMacOS || !stdin.hasTerminal) {
      return settle();
    }
    final setup = _execSetup;
    if (setup != null) return setup.future;
    final firstSetup = Completer<void>();
    _execSetup = firstSetup;
    try {
      await _prepareForInheritedExec();
      firstSetup.complete();
    } catch (error, stackTrace) {
      firstSetup.completeError(error, stackTrace);
    }
    return firstSetup.future;
  }

  void endInheritedExec() {
    _execUsers--;
    if (_execUsers == 0) {
      _execSetup = null;
      _sync();
    }
  }

  Future<void> _prepareForInheritedExec() async {
    if (!stdin.hasTerminal || _closed) return;
    var control = _control;
    if (control == null) {
      final ready = _controlReady;
      if (ready == null) return; // no reader was ever started
      _pinHelperAlive = true;
      _port?.keepIsolateAlive = true;
      try {
        await ready.future.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        _pinHelperAlive = false;
        _sync();
        throw StateError('stdin reader did not start before exec');
      }
      control = _control;
    }
    if (control == null) {
      _pinHelperAlive = false;
      _sync();
      return;
    }
    // Cancelling the reader closes fd 0, so keep a copy to restore.
    final backup = preserveStdin();
    if (backup == null) {
      _pinHelperAlive = false;
      _sync();
      throw StateError('could not preserve stdin before exec');
    }
    final token = ++_execCancelToken;
    final ack = Completer<void>();
    _execCancelAck = ack;
    _pinHelperAlive = false;
    _stdinExecResetting = true;
    _port?.keepIsolateAlive = true;
    try {
      control.send(('cancel-for-exec', token));
      try {
        await ack.future.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        throw StateError('stdin reader did not stop before exec');
      }
    } finally {
      if (identical(_execCancelAck, ack)) _execCancelAck = null;
      _port?.close();
      _port = null;
      _control = null;
      _controlReady = null;
      _reading = false;
      try {
        if (!await restoreStdin(backup)) {
          throw StateError('could not restore stdin before exec');
        }
      } finally {
        _stdinExecResetting = false;
        _sync();
      }
    }
  }

  RawReceivePort _spawn() {
    final port = RawReceivePort(_onMessage, 'dart_tui stdin');
    _controlReady = Completer<void>();
    unawaited(Isolate.spawn(_readStdin, port.sendPort));
    return port;
  }

  void _onMessage(Object? message) {
    switch (message) {
      case SendPort():
        _control = message;
        final ready = _controlReady;
        if (ready != null && !ready.isCompleted) ready.complete();
        _sync();
      case ('settled', final int id):
        _settling.remove(id)?.complete();
        _sync();
      case ('exec-cancelled', final int token):
        final ack = _execCancelAck;
        if (token == _execCancelToken && ack != null && !ack.isCompleted) {
          ack.complete();
        }
      case ('exec-cancel-failed', final int token, final String error):
        final ack = _execCancelAck;
        if (token == _execCancelToken && ack != null && !ack.isCompleted) {
          ack.completeError(StateError('stdin reader cancel failed: $error'));
        }
      case List<int>():
        for (final reader in [..._readers]) {
          reader.add(message);
        }
      case String():
        for (final reader in [..._readers]) {
          reader.addError(StdinException(message));
        }
      case null:
        _closed = true;
        _pinHelperAlive = false;
        _readingStarted?.complete();
        _readingStarted = null;
        final ready = _controlReady;
        if (ready != null && !ready.isCompleted) ready.complete();
        final ack = _execCancelAck;
        if (ack != null && !ack.isCompleted) ack.complete();
        for (final settled in _settling.values) {
          settled.complete();
        }
        _settling.clear();
        _port?.close();
        for (final reader in [..._readers]) {
          unawaited(reader.close());
        }
    }
  }
}

/// Helper-isolate entry point: reads stdin while told to (`true`), pauses on
/// `false`, and forwards bytes, errors (as text) and end of input (`null`).
void _readStdin(SendPort events) {
  final control = RawReceivePort();
  final subscription = stdin.listen(
    events.send,
    onError: (Object error) => events.send('$error'),
    onDone: () {
      events.send(null);
      control.close();
    },
  )..pause();
  control.handler = (Object? message) {
    if (message case ('cancel-for-exec', final int token)) {
      unawaited(subscription.cancel().then(
            (_) => Isolate.exit(events, ('exec-cancelled', token)),
            onError: (Object error) =>
                Isolate.exit(events, ('exec-cancel-failed', token, '$error')),
          ));
      return;
    }
    if (message == true && subscription.isPaused) subscription.resume();
    if (message == false && !subscription.isPaused) subscription.pause();
    if (message case ('settle', final int id)) events.send(('settled', id));
  };
  events.send(control.sendPort);
}

ProgramOption withContext(Future<void> Function() cancellation) {
  return (p) {
    p._externalCancellation = cancellation;
  };
}

/// Reads input from [input] instead of the terminal, or no input when null.
///
/// Without this option a [Program] reads the process stdin, which only the
/// main isolate may do; programs in other isolates must pass an input stream
/// or null.
ProgramOption withInput(Stream<List<int>>? input) {
  return (p) {
    p._input = input;
    p._disableInput = input == null;
  };
}

ProgramOption withOutput(IOSink output) {
  return (p) {
    p._output = output;
  };
}

ProgramOption withEnvironment(Map<String, String> env) {
  return (p) {
    p._environment = Map<String, String>.unmodifiable(env);
  };
}

ProgramOption withoutSignalHandler() => (p) => p._disableSignalHandler = true;
ProgramOption withoutCatchPanics() => (p) => p._disableCatchPanics = true;
ProgramOption withoutRenderer() => (p) => p._disableRenderer = true;
ProgramOption withCellRenderer() => (p) => p._useCellRenderer = true;
ProgramOption withFilter(Msg? Function(Model model, Msg msg) filter) =>
    (p) => p._filter = filter;
ProgramOption withFps(int fps) => (p) => p._fps = fps.clamp(1, 120);
ProgramOption withColorProfile(ColorProfile profile) =>
    (p) => p._profile = profile;
ProgramOption withWindowSize(int width, int height) {
  return (p) {
    p._width = width;
    p._height = height;
  };
}

/// Enter the alternate screen buffer at startup.
ProgramOption withAltScreen() => (p) => p._altScreen = true;

/// Hide the terminal cursor at startup (default behaviour).
/// Pass `false` to keep the cursor visible.
ProgramOption withHideCursor([bool hide = true]) => (p) => p._hideCursor = hide;

/// Emit tick messages on a fixed [interval].
ProgramOption withTickInterval(Duration interval) =>
    (p) => p._tickInterval = interval;

/// Append renderer output to [file] while the program is running.
ProgramOption withLogFile(File file) => (p) => p._logFile = file;

/// Enable cell-motion mouse tracking at startup (button events + drag).
ProgramOption withMouseCellMotion() =>
    (p) => p._defaultMouseMode = MouseMode.cellMotion;

/// Enable all-motion mouse tracking at startup (includes hover).
ProgramOption withMouseAllMotion() =>
    (p) => p._defaultMouseMode = MouseMode.allMotion;

/// Enable terminal focus/blur reporting at startup.
ProgramOption withReportFocus() => (p) => p._defaultReportFocus = true;

final class Program {
  Program({List<ProgramOption> options = const []}) {
    for (final opt in options) {
      opt(this);
    }
  }

  IOSink _output = stdout;
  Stream<List<int>>? _input;
  Map<String, String> _environment = Platform.environment;
  Msg? Function(Model model, Msg msg)? _filter;
  Future<void> Function()? _externalCancellation;
  ColorProfile _profile = ColorProfile.trueColor;
  int _fps = 60;
  int? _width;
  int? _height;
  bool _disableInput = false;
  bool _disableRenderer = false;
  bool _disableCatchPanics = false;
  bool _disableSignalHandler = false;
  bool _useCellRenderer = false;

  bool _altScreen = false;
  bool _hideCursor = true;
  Duration? _tickInterval;
  MouseMode _defaultMouseMode = MouseMode.none;
  bool _defaultReportFocus = false;

  File? _logFile;
  IOSink? _logSink;
  Model? _runningModel;
  final _msgs = StreamController<Msg>.broadcast(sync: true);
  bool _running = false;
  bool _killed = false;
  Completer<void>? _finished;
  Completer<void>? _activityWake;
  Timer? _tickTimer;
  Timer? _loneEscTimer;
  StreamSubscription<List<int>>? _inputSub;
  bool _unicodeCoreSupported = false;
  StreamSubscription<ProcessSignal>? _sigSub;
  StreamSubscription<ProcessSignal>? _sigintSub;
  StreamSubscription<ProcessSignal>? _sigtermSub;
  TeaRenderer? _renderer;
  bool _endedInAltScreen = false;
  bool _terminalReleased = false;
  int _runs = 0;

  void _setRawMode(bool raw) {
    try {
      stdin.echoMode = !raw;
      stdin.lineMode = !raw;
    } on StdinException {
      // stdin is not a TTY (e.g. in tests or piped input) — ignore.
    }
    // On Windows, lineMode/echoMode alone leave the console in legacy input
    // mode, where arrow keys / Esc / Shift+Tab / mouse never reach the byte
    // stream. On macOS/Linux they leave ISIG/IEXTEN/IXON set, so Ctrl+C/Z/\
    // become signals. Finish raw mode here (and restore it when leaving raw
    // mode). Each helper is a no-op on the other platforms.
    if (raw) {
      enableWindowsVtInput();
      enablePosixRawInput();
    } else {
      restorePosixRawInput();
      restoreWindowsVtInput();
    }
  }

  Future<Model> run(Model initial) async {
    final runZone = Zone.current.fork(
      zoneValues: {_commandZoneOwnerKey: null},
    );
    final (_, model) = await runZone.run(() => _runCore(initial));
    return model;
  }

  Future<T?> runForResult<T>(OutcomeModel<T> initial) async {
    final runZone = Zone.current.fork(
      zoneValues: {_commandZoneOwnerKey: null},
    );
    final (_, model) = await runZone.run(() => _runCore(initial));
    if (model is OutcomeModel<T>) {
      return model.outcome;
    }
    return null;
  }

  void send(Msg msg) {
    if (!_running) return;
    if (_msgs.isClosed) return;
    _msgs.add(msg);
  }

  void quit() => send(QuitMsg());

  void kill() {
    _killed = true;
    _shutdown();
  }

  Future<void> releaseTerminal({bool resetRenderer = false}) async {
    if (!_running) return;
    if (_disableRenderer) return;
    _terminalReleased = true;
    // Cook the terminal before the release sequences reach it.
    _setRawMode(false);
    _renderer?.release(reset: resetRenderer);
  }

  Future<void> restoreTerminal() async {
    if (!_running) return;
    if (_disableRenderer) return;
    _setRawMode(true);
    final m = _runningModel;
    if (m != null) {
      if (_unicodeCoreSupported) _renderer?.setUnicodeCore(true);
      _renderer?.restore(m.view());
    }
    _terminalReleased = false;
  }

  void println([Object? value]) => send(PrintLineMsg('${value ?? ''}'));
  void printf(String template, [List<Object?> args = const []]) =>
      send(PrintLineMsg(formatPrintf(template, args)));

  Future<void> wait() async {
    await _finished?.future;
  }

  Future<(Object?, Model)> _runCore(Model initial) async {
    if (_running) {
      throw StateError('Program is already running');
    }
    if (!_disableInput &&
        (_input == null || identical(_input, stdin)) &&
        Isolate.current.debugName != 'main') {
      // Each isolate would start its own reader on fd 0, and readers in
      // different isolates race for input and for the descriptor itself.
      throw StateError(
        'Default stdin can only be read from the main isolate. Pass '
        'withInput(...) to a Program in another isolate, or withInput(null) '
        'for no input.',
      );
    }
    _running = true;
    _killed = false;
    _endedInAltScreen = false;
    _terminalReleased = false;
    final runId = ++_runs;
    final usesSharedStdin = _input == null || identical(_input, stdin);
    _finished = Completer<void>();
    _activityWake = null;
    _runningModel = initial;
    var runModel = initial;
    StreamSubscription<List<int>>? runInputSub;
    IOSink? runLogSink;

    // Opt-in startup phase timer: set DART_TUI_BENCH=1 to enable.
    final benchEnabled = Platform.environment['DART_TUI_BENCH'] == '1';
    final benchSw = benchEnabled ? (Stopwatch()..start()) : null;
    void bench(String label) {
      if (benchSw == null) return;
      stderr.writeln('[bench] +${benchSw.elapsedMilliseconds}ms\t$label');
    }

    bench('start');

    final queue = Queue<Msg>();

    void enqueue(Msg msg) {
      queue.add(msg);
      _activityWake?.complete();
      _activityWake = null;
    }

    // [send] pushes to [_msgs]; bridge it into the same queue as stdin/ticks.
    // Without this listener, async side-effects (e.g. HTTP progress/completion)
    // never reach [applyMsg].
    final StreamSubscription<Msg> externalMsgSub = _msgs.stream.listen(
      (Msg msg) {
        if (_running && runId == _runs) {
          enqueue(msg);
        }
      },
    );

    Future<void> waitForActivity() async {
      while (_running && runId == _runs && queue.isEmpty) {
        _activityWake = Completer<void>();
        await _activityWake!.future;
      }
    }

    // Commands from an earlier run must not reach this one.
    bool current() => _running && runId == _runs;

    // Replies to the startup queries. An inherited exec started right away
    // waits for them, so the child does not read them as keystrokes.
    final pendingReplies = <int>{};
    final repliesReceived = Completer<void>();

    // Timers that commands start end with the run, so a pending tick or delay
    // cannot keep the process alive after the program has quit.
    final commandTimers = <Timer>{};
    final commandParentZone = Zone.current;
    final commandZone = commandParentZone.fork(
      zoneValues: {_commandZoneOwnerKey: commandTimers},
      specification: ZoneSpecification(
        createTimer: (self, parent, zone, duration, callback) {
          if (!identical(zone[_commandZoneOwnerKey], commandTimers)) {
            return parent.createTimer(zone, duration, callback);
          }
          late final Timer timer;
          timer = parent.createTimer(zone, duration, () {
            commandTimers.remove(timer);
            callback();
          });
          if (current()) {
            commandTimers.removeWhere((timer) => !timer.isActive);
            commandTimers.add(timer);
          } else {
            timer.cancel();
          }
          return timer;
        },
        createPeriodicTimer: (self, parent, zone, period, callback) {
          if (!identical(zone[_commandZoneOwnerKey], commandTimers)) {
            return parent.createPeriodicTimer(zone, period, callback);
          }
          final timer = parent.createPeriodicTimer(zone, period, callback);
          if (current()) {
            commandTimers.removeWhere((timer) => !timer.isActive);
            commandTimers.add(timer);
          } else {
            timer.cancel();
          }
          return timer;
        },
      ),
    );

    // Returns whether a sequence may run its next command.
    Future<bool> runCmd(Cmd? cmd) async {
      if (cmd == null) return current();
      if (!current()) return false;
      try {
        final msg = await commandZone.run(() => Future<Msg?>.value(cmd()));
        if (!current()) return false;
        if (msg != null) enqueue(msg);
        return msg is! QuitMsg && msg is! InterruptMsg;
      } catch (e, st) {
        if (!_disableCatchPanics) {
          stderr.writeln('Caught command exception: $e');
          stderr.writeln(st);
        }
        if (current()) enqueue(InterruptMsg());
        return false;
      }
    }

    final minFrameMicros = _fps > 0 ? (1000000 / _fps).round() : 0;
    final frameClock = Stopwatch()..start();
    var lastRenderMicros = -1;
    View? lastRenderedView;
    Future<void> render(View v) async {
      final nowMicros = frameClock.elapsedMicroseconds;
      if (lastRenderMicros >= 0 && minFrameMicros > 0) {
        final delta = nowMicros - lastRenderMicros;
        if (delta < minFrameMicros) {
          await Future<void>.delayed(
            Duration(microseconds: minFrameMicros - delta),
          );
        }
      }
      // A throttled frame must not land after a release or kill.
      if (runId == _runs && !_killed && !_terminalReleased) {
        _renderer?.render(v);
      }
      lastRenderedView = v;
      lastRenderMicros = frameClock.elapsedMicroseconds;
    }

    void scheduleResizeMsg() {
      final width =
          _width ?? (stdout.hasTerminal ? stdout.terminalColumns : 80);
      final height =
          _height ?? (stdout.hasTerminal ? stdout.terminalLines : 24);
      enqueue(WindowSizeMsg(width, height));
    }

    // Process one message: update model / fire side-effects.
    // Returns true when the view may have changed and a re-render is needed.
    // Does NOT call render() — the event loop renders once per drained batch.
    Future<bool> applyMsg(Msg rawMsg) async {
      var msg = rawMsg;
      final model = runModel;
      if (_filter != null) {
        final filtered = _filter!(model, msg);
        if (!current()) return false;
        if (filtered == null) return false;
        msg = filtered;
      }

      switch (msg) {
        case QuitMsg():
          _running = false;
          return false;
        case InterruptMsg():
          _running = false;
          return false;
        case SuspendMsg():
          await releaseTerminal(resetRenderer: true);
          if (!current()) return false;
          if (!Platform.isWindows) {
            Process.killPid(pid, ProcessSignal.sigstop);
            // SIGSTOP cannot be caught or ignored. Execution continues here
            // only after an external SIGCONT resumes the process.
            await Future<void>.delayed(Duration.zero);
          }
          if (!current()) return false;
          await restoreTerminal();
          if (current()) enqueue(ResumeMsg());
          return false; // ResumeMsg will trigger re-render next batch
        case RequestWindowSizeMsg():
          scheduleResizeMsg();
          return false;
        case RequestForegroundColorMsg():
          _output.write('\x1b]10;?\x07');
          if (_disableInput) enqueue(ForegroundColorMsg(0xFFFFFF));
          return false;
        case RequestBackgroundColorMsg():
          _output.write('\x1b]11;?\x07');
          if (_disableInput) enqueue(BackgroundColorMsg(0x000000));
          return false;
        case RequestCursorColorMsg():
          _output.write('\x1b]12;?\x07');
          if (_disableInput) enqueue(CursorColorMsg(0xFFFFFF));
          return false;
        case RequestCursorPositionMsg():
          _output.write('\x1b[6n');
          if (_disableInput) enqueue(CursorPositionMsg(x: 0, y: 0));
          return false;
        case RequestTerminalVersionMsg():
          _output.write('\x1b[>0c');
          if (_disableInput) enqueue(TerminalVersionMsg('unknown'));
          return false;
        case RequestCapabilityMsg():
          final encoded = _hexEncode(msg.name);
          _output.write('\x1bP+q$encoded\x1b\\');
          if (_disableInput) enqueue(CapabilityMsg('${msg.name}=unknown'));
          return false;
        case SetClipboardMsg():
          _output.write('\x1b]52;c;${_base64(msg.value)}\x07');
          return false;
        case ReadClipboardMsg():
          _output.write('\x1b]52;c;?\x07');
          return false;
        case SetPrimaryClipboardMsg():
          _output.write('\x1b]52;p;${_base64(msg.value)}\x07');
          return false;
        case ReadPrimaryClipboardMsg():
          _output.write('\x1b]52;p;?\x07');
          return false;
        case ClearScreenMsg():
          _renderer?.clearScreen();
          return true;
        case EnterAltScreenMsg():
          _renderer?.setAltScreen(true);
          return false;
        case ExitAltScreenMsg():
          _renderer?.setAltScreen(false);
          return false;
        case HideCursorMsg():
          _renderer?.setCursorVisibility(false);
          return false;
        case ShowCursorMsg():
          _renderer?.setCursorVisibility(true);
          return false;
        case SetWindowTitleMsg():
          _output.write(windowTitleSequence(msg.title));
          return false;
        case ClearScrollAreaMsg():
          _output.write('\x1b[2J\x1b[H');
          _renderer?.clearScreen();
          return true;
        case ScrollMsg():
          _renderer?.scroll(msg.lines, up: msg.up);
          return false;
        case PrintLineMsg():
          _renderer?.insertAbove(msg.messageBody);
          return true;
        case BatchMsg():
          for (final c in msg.cmds) {
            unawaited(runCmd(c));
          }
          return false;
        case SequenceMsg():
          // Run in order without blocking the event loop, as Bubble Tea does.
          final cmds = msg.cmds;
          unawaited(() async {
            for (final c in cmds) {
              if (!await runCmd(c)) break;
            }
          }());
          return false;
        case ExecMsg():
          if (msg.inheritStdio && pendingReplies.isNotEmpty) {
            // Let the terminal's replies to the startup queries reach our
            // decoder first. A terminal that never replies costs 250 ms, once.
            if (usesSharedStdin && !_disableInput) {
              await _sharedStdin.reading
                  .timeout(const Duration(seconds: 1), onTimeout: () {});
            }
            await repliesReceived.future
                .timeout(const Duration(milliseconds: 250), onTimeout: () {});
            pendingReplies.clear();
          }
          if (!current()) return false;
          // Stop reading, and wait until the stdin reader has stopped, so the
          // child gets every byte typed once the terminal is released.
          _inputSub?.pause();
          var inheritedExecLease = false;
          try {
            if (msg.inheritStdio) {
              _setRawMode(false);
              inheritedExecLease = true;
              await _sharedStdin.beginInheritedExec();
            }
            if (!current()) return false;
            await releaseTerminal(resetRenderer: true);
            if (!current()) return false;
            if (msg.inheritStdio) {
              final process = await Process.start(
                msg.cmd,
                msg.args,
                environment: msg.env,
                mode: ProcessStartMode.inheritStdio,
              );
              final exitCode = await process.exitCode;
              if (msg.onExit != null && current()) {
                final followUp = msg.onExit!(exitCode);
                if (followUp != null) enqueue(followUp);
              }
            } else {
              final result = await Process.run(
                msg.cmd,
                msg.args,
                environment: msg.env,
              );
              if (msg.onExit != null && current()) {
                final followUp = msg.onExit!(result.exitCode);
                if (followUp != null) enqueue(followUp);
              }
            }
          } finally {
            try {
              if (runId == _runs) await restoreTerminal();
            } finally {
              if (runId == _runs) _inputSub?.resume();
              if (inheritedExecLease) _sharedStdin.endInheritedExec();
            }
          }
          return current();
        default:
      }

      if (msg is ModeReportMsg &&
          msg.mode == 2026 &&
          (msg.value == 1 || msg.value == 2)) {
        _renderer?.setSyncUpdates(true);
      }
      if (msg is ModeReportMsg &&
          msg.mode == 2027 &&
          (msg.value == 1 || msg.value == 2 || msg.value == 3)) {
        _unicodeCoreSupported = true;
        _renderer?.setUnicodeCore(true);
      }
      if (msg is MouseMsg) {
        final onMouse = lastRenderedView?.onMouse;
        if (onMouse != null) {
          try {
            unawaited(runCmd(onMouse(msg)));
          } catch (e, st) {
            if (!_disableCatchPanics) {
              stderr.writeln('Caught mouse handler exception: $e');
              stderr.writeln(st);
            }
            enqueue(InterruptMsg());
          }
        }
      }
      final (nextModel, cmd) = model.update(msg);
      if (!current()) return false;
      runModel = nextModel;
      _runningModel = nextModel;
      // Fire cmd asynchronously so its result message is queued and processed
      // in the next event-loop batch, unblocking key-event handling.
      unawaited(runCmd(cmd));
      return true;
    }

    try {
      _logSink = _logFile?.openWrite(mode: FileMode.append);
      runLogSink = _logSink;
      _renderer = _disableRenderer
          ? NilRenderer()
          : _useCellRenderer
              ? CellRenderer(
                  output: _output,
                  logSink: _logSink,
                  defaultAltScreen: _altScreen,
                  defaultHideCursor: _hideCursor,
                  defaultMouseMode: _defaultMouseMode,
                  defaultReportFocus: _defaultReportFocus,
                )
              : AnsiRenderer(
                  output: _output,
                  logSink: _logSink,
                  defaultAltScreen: _altScreen,
                  defaultHideCursor: _hideCursor,
                  defaultMouseMode: _defaultMouseMode,
                  defaultReportFocus: _defaultReportFocus,
                );
      if (!_disableRenderer) {
        _setRawMode(true);
      }
      bench('raw_mode');

      if (!_disableSignalHandler) {
        _sigintSub = ProcessSignal.sigint.watch().listen((_) {
          if (_running) enqueue(InterruptMsg());
        });
        if (!Platform.isWindows) {
          _sigSub =
              ProcessSignal.sigwinch.watch().listen((_) => scheduleResizeMsg());
          // As in Bubble Tea, SIGTERM quits so the terminal is restored.
          _sigtermSub = ProcessSignal.sigterm.watch().listen((_) {
            if (_running) enqueue(QuitMsg());
          });
        }
      }

      scheduleResizeMsg();
      enqueue(ColorProfileMsg(_profile));
      enqueue(EnvMsg(_environment));
      bench('terminal_queries');

      if (!_disableInput) {
        final source = usesSharedStdin ? _sharedStdin.claim() : _input!;
        final decoder = TerminalInputDecoder();
        runInputSub = source.listen(
          (bytes) {
            _loneEscTimer?.cancel();
            _loneEscTimer = null;
            for (final msg in decoder.feed(bytes)) {
              final reply = switch (msg) {
                ModeReportMsg(mode: 2026) => 2026,
                ModeReportMsg(mode: 2027) => 2027,
                BackgroundColorMsg() => 11,
                _ => null,
              };
              if (reply != null &&
                  pendingReplies.remove(reply) &&
                  pendingReplies.isEmpty) {
                repliesReceived.complete();
              }
              enqueue(msg);
            }
            if (decoder.hasPendingLoneEscape) {
              _loneEscTimer = Timer(const Duration(milliseconds: 10), () {
                _loneEscTimer = null;
                if (!_running) return;
                for (final msg in decoder.takeLoneEscapeIfStillPending()) {
                  enqueue(msg);
                }
              });
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!_disableCatchPanics) {
              stderr.writeln('Caught input exception: $error');
              stderr.writeln(stackTrace);
            }
            enqueue(InterruptMsg());
          },
          cancelOnError: true,
        );
        _inputSub = runInputSub;
      }
      bench('input_ready');

      if (_tickInterval != null) {
        _tickTimer?.cancel();
        _tickTimer = Timer.periodic(_tickInterval!, (_) {
          enqueue(TickMsg(DateTime.now()));
        });
      }

      final initCmd = _runningModel!.init();
      bench('init_cmd_created');
      // Render the first frame immediately before firing the init command.
      // This matches Bubbletea's behaviour: Init() runs concurrently while
      // the initial view is already visible on screen.
      await render(_runningModel!.view());
      bench('first_frame');

      // Send capability queries AFTER the first frame so the first visible
      // output reaches the terminal without being delayed by query bytes.
      if (!_disableInput) {
        pendingReplies.addAll(const [2026, 2027, 11]);
        _output.write('\x1b[?2026\$p');
        _output.write('\x1b[?2027\$p');
        // OSC 11: auto-detect terminal background color.
        // The response arrives as BackgroundColorMsg in the event loop.
        _output.write('\x1b]11;?\x07');
      }

      if (initCmd != null) {
        unawaited(runCmd(initCmd));
      }

      final externalCancellation = _externalCancellation;
      if (externalCancellation != null) {
        unawaited(externalCancellation().then((_) {
          if (current()) {
            enqueue(InterruptMsg());
          }
        }));
      }

      while (_running && runId == _runs) {
        // Drain all pending messages without rendering between them.
        // This ensures rapid key events are processed immediately without
        // each one incurring the FPS-throttle delay.
        var needsRender = false;
        while (queue.isNotEmpty && _running && runId == _runs) {
          needsRender |= await applyMsg(queue.removeFirst());
          final m = runModel;
          if (m is OutcomeModel && m.outcome != null) {
            _running = false;
            break;
          }
        }
        // Render once for the entire drained batch, including the batch that
        // quit, so the final frame shows the last update (unless killed).
        if (needsRender && !_killed && runId == _runs) {
          await render(runModel.view());
        }
        if (_running) {
          await waitForActivity();
        }
      }
    } finally {
      if (runId == _runs) _shutdown();
      for (final timer in commandTimers) {
        timer.cancel();
      }
      commandTimers.clear();
      await externalMsgSub.cancel();
      await runInputSub?.cancel();
      if (runLogSink != null) await runLogSink.done;
      if (runId == _runs && !_disableRenderer) {
        // Move to a fresh line so the shell prompt appears cleanly after exit
        // (leaving the alt screen already restores the cursor), then flush so
        // all reset sequences reach the terminal before the shell gets control.
        if (!_endedInAltScreen) _output.writeln();
        await _output.flush();
      }
    }

    return (_killed ? StateError('program killed') : null, runModel);
  }

  void _shutdown() {
    if (!_running && (_finished?.isCompleted ?? true)) return;
    _running = false;
    final activityWake = _activityWake;
    _activityWake = null;
    if (activityWake != null && !activityWake.isCompleted) {
      activityWake.complete();
    }
    _tickTimer?.cancel();
    _tickTimer = null;
    _loneEscTimer?.cancel();
    _loneEscTimer = null;
    if (!_disableRenderer) {
      _setRawMode(false);
    }
    _terminalReleased = true;
    _endedInAltScreen = _renderer?.altScreenActive ?? false;
    _renderer?.close();
    _renderer = null;
    final inputSub = _inputSub;
    _inputSub = null;
    if (inputSub != null) unawaited(inputSub.cancel());
    unawaited(_sigSub?.cancel());
    _sigSub = null;
    unawaited(_sigintSub?.cancel());
    _sigintSub = null;
    unawaited(_sigtermSub?.cancel());
    _sigtermSub = null;
    final logSink = _logSink;
    _logSink = null;
    if (logSink != null) {
      unawaited(logSink.close());
    }
    _finished?.complete();
  }
}

String _base64(String s) => base64Encode(utf8.encode(s));

String _hexEncode(String input) =>
    input.codeUnits.map((c) => c.toRadixString(16).padLeft(2, '0')).join();
