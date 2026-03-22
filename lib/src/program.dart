import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

import 'cmd.dart';
import 'input_decoder.dart';
import 'model.dart';
import 'msg.dart';
import 'renderer.dart';
import 'view.dart';

typedef ProgramOption = void Function(Program program);

Stream<List<int>>? _stdinBroadcastCache;

Stream<List<int>> _stdinBroadcast() {
  return _stdinBroadcastCache ??= stdin.asBroadcastStream();
}

/// Compatibility options while migrating toward option-function API.
@immutable
class ProgramOptions {
  const ProgramOptions({
    this.altScreen = false,
    this.hideCursor = true,
    this.tickInterval,
    this.logFile,
  });

  final bool altScreen;
  final bool hideCursor;
  final Duration? tickInterval;
  final File? logFile;
}

ProgramOption withContext(Future<void> Function() cancellation) {
  return (p) {
    p._externalCancellation = cancellation;
  };
}

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

final class Program {
  Program({
    ProgramOptions options = const ProgramOptions(),
    List<ProgramOption> programOptions = const [],
  })  : _compatOptions = options {
    for (final opt in programOptions) {
      opt(this);
    }
  }

  final ProgramOptions _compatOptions;

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

  IOSink? _logSink;
  Model? _runningModel;
  final _msgs = StreamController<Msg>.broadcast(sync: true);
  bool _running = false;
  bool _killed = false;
  Completer<void>? _finished;
  Timer? _tickTimer;
  StreamSubscription<List<int>>? _inputSub;
  StreamSubscription<ProcessSignal>? _sigSub;
  TeaRenderer? _renderer;

  void _setRawMode(bool raw) {
    try {
      stdin.echoMode = !raw;
      stdin.lineMode = !raw;
    } on StdinException {
      // stdin is not a TTY (e.g. in tests or piped input) — ignore.
    }
  }

  Future<Model> run(Model initial) async {
    final (_, model) = await _runCore(initial);
    return model;
  }

  Future<T?> runForResult<T>(OutcomeModel<T> initial) async {
    final (_, model) = await _runCore(initial);
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
    _renderer?.release(reset: resetRenderer);
    _setRawMode(false);
  }

  Future<void> restoreTerminal() async {
    if (!_running) return;
    if (_disableRenderer) return;
    _setRawMode(true);
    final m = _runningModel;
    if (m != null) {
      _renderer?.restore(m.view());
    }
  }

  void println([Object? value]) => send(PrintLineMsg('${value ?? ''}'));
  void printf(String template, [List<Object?> args = const []]) =>
      send(PrintLineMsg(_formatProgram(template, args)));

  Future<void> wait() async {
    await _finished?.future;
  }

  Future<(Object?, Model)> _runCore(Model initial) async {
    if (_running) {
      throw StateError('Program is already running');
    }
    _running = true;
    _killed = false;
    _finished = Completer<void>();
    _runningModel = initial;

    // Opt-in startup phase timer: set DART_TUI_BENCH=1 to enable.
    final benchEnabled =
        Platform.environment['DART_TUI_BENCH'] == '1';
    final benchSw = benchEnabled ? (Stopwatch()..start()) : null;
    void bench(String label) {
      if (benchSw == null) return;
      stderr.writeln('[bench] +${benchSw.elapsedMilliseconds}ms\t$label');
    }

    bench('start');

    final queue = Queue<Msg>();
    Completer<void>? wake;

    void enqueue(Msg msg) {
      queue.add(msg);
      wake?.complete();
      wake = null;
    }

    Future<void> waitForActivity() async {
      while (_running && queue.isEmpty) {
        wake = Completer<void>();
        await wake!.future;
      }
    }

    Future<void> runCmd(Cmd? cmd) async {
      if (cmd == null || !_running) return;
      try {
        final msg = await Future<Msg?>.value(cmd());
        if (msg != null) enqueue(msg);
      } catch (e, st) {
        if (!_disableCatchPanics) {
          stderr.writeln('Caught command exception: $e');
          stderr.writeln(st);
        }
        enqueue(InterruptMsg());
      }
    }

    var lastRenderMicros = 0;
    Future<void> render(View v) async {
      final minFrameMicros = (1000000 / _fps).round();
      final nowMicros = DateTime.now().microsecondsSinceEpoch;
      if (lastRenderMicros != 0 && minFrameMicros > 0) {
        final delta = nowMicros - lastRenderMicros;
        if (delta < minFrameMicros) {
          await Future<void>.delayed(
            Duration(microseconds: minFrameMicros - delta),
          );
        }
      }
      _renderer?.render(v);
      lastRenderMicros = DateTime.now().microsecondsSinceEpoch;
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
      final model = _runningModel!;
      if (_filter != null) {
        final filtered = _filter!(model, msg);
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
          if (!Platform.isWindows) {
            final contCompleter = Completer<void>();
            final contSub = ProcessSignal.sigcont.watch().listen((_) {
              if (!contCompleter.isCompleted) contCompleter.complete();
            });
            Process.killPid(pid, ProcessSignal.sigstop);
            await contCompleter.future;
            await contSub.cancel();
          }
          await restoreTerminal();
          enqueue(ResumeMsg());
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
        case PrintLineMsg():
          _renderer?.insertAbove(msg.messageBody);
          return true;
        case BatchMsg():
          for (final c in msg.cmds) {
            unawaited(runCmd(c));
          }
          return false;
        case SequenceMsg():
          for (final c in msg.cmds) {
            await runCmd(c);
          }
          return false;
        case ExecMsg():
          await releaseTerminal(resetRenderer: true);
          try {
            if (msg.inheritStdio) {
              final process = await Process.start(
                msg.cmd,
                msg.args,
                environment: msg.env,
                mode: ProcessStartMode.inheritStdio,
              );
              final exitCode = await process.exitCode;
              if (msg.onExit != null) {
                final followUp = msg.onExit!(exitCode);
                if (followUp != null) enqueue(followUp);
              }
            } else {
              final result = await Process.run(
                msg.cmd,
                msg.args,
                environment: msg.env,
              );
              if (msg.onExit != null) {
                final followUp = msg.onExit!(result.exitCode);
                if (followUp != null) enqueue(followUp);
              }
            }
          } finally {
            await restoreTerminal();
          }
          return true;
        default:
      }

      if (msg is ModeReportMsg &&
          msg.mode == 2026 &&
          (msg.value == 1 || msg.value == 2)) {
        _renderer?.setSyncUpdates(true);
      }
      final (nextModel, cmd) = model.update(msg);
      _runningModel = nextModel;
      // Fire cmd asynchronously so its result message is queued and processed
      // in the next event-loop batch, unblocking key-event handling.
      unawaited(runCmd(cmd));
      return true;
    }

    try {
      _logSink = _compatOptions.logFile?.openWrite(mode: FileMode.append);
      _renderer = _disableRenderer
          ? NilRenderer()
          : _useCellRenderer
              ? CellRenderer(
                  output: _output,
                  logSink: _logSink,
                  defaultAltScreen: _compatOptions.altScreen,
                  defaultHideCursor: _compatOptions.hideCursor,
                )
              : AnsiRenderer(
                  output: _output,
                  logSink: _logSink,
                  defaultAltScreen: _compatOptions.altScreen,
                  defaultHideCursor: _compatOptions.hideCursor,
                );
      if (!_disableRenderer) {
        _setRawMode(true);
      }
      bench('raw_mode');

      if (!_disableSignalHandler && !Platform.isWindows) {
        _sigSub =
            ProcessSignal.sigwinch.watch().listen((_) => scheduleResizeMsg());
      }

      scheduleResizeMsg();
      enqueue(ColorProfileMsg(_profile));
      enqueue(EnvMsg(_environment));
      bench('terminal_queries');

      if (!_disableInput) {
        final source = _input ?? _stdinBroadcast();
        final decoder = TerminalInputDecoder();
        _inputSub = source.listen(
          (bytes) {
            for (final msg in decoder.feed(bytes)) {
              enqueue(msg);
            }
          },
          cancelOnError: true,
        );
      }
      bench('input_ready');

      if (_compatOptions.tickInterval != null) {
        _tickTimer?.cancel();
        _tickTimer = Timer.periodic(_compatOptions.tickInterval!, (_) {
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
        _output.write('\x1b[?2026\$y');
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
          if (_running) {
            enqueue(InterruptMsg());
          }
        }));
      }

      while (_running) {
        // Drain all pending messages without rendering between them.
        // This ensures rapid key events are processed immediately without
        // each one incurring the FPS-throttle delay.
        var needsRender = false;
        while (queue.isNotEmpty && _running) {
          needsRender |= await applyMsg(queue.removeFirst());
          final m = _runningModel;
          if (m is OutcomeModel && m.outcome != null) {
            _running = false;
            break;
          }
        }
        // Render once for the entire drained batch.
        if (needsRender && _running) {
          await render(_runningModel!.view());
        }
        if (_running) {
          await waitForActivity();
        }
      }
    } finally {
      _shutdown();
      if (!_disableRenderer) {
        // Move to a fresh line so the shell prompt appears cleanly after exit,
        // then flush so all ANSI reset sequences (show cursor, exit alt-screen)
        // actually reach the terminal before the shell gets control.
        _output.writeln();
        await _output.flush();
      }
    }

    return (_killed ? StateError('program killed') : null, _runningModel!);
  }

  void _shutdown() {
    if (!_running && (_finished?.isCompleted ?? true)) return;
    _running = false;
    _tickTimer?.cancel();
    _tickTimer = null;
    unawaited(_inputSub?.cancel());
    _inputSub = null;
    unawaited(_sigSub?.cancel());
    _sigSub = null;
    _renderer?.close();
    _renderer = null;
    if (!_disableRenderer) {
      _setRawMode(false);
    }
    unawaited(_logSink?.flush());
    unawaited(_logSink?.close());
    _logSink = null;
    _finished?.complete();
  }
}

String _formatProgram(String template, List<Object?> args) {
  var out = template;
  for (final arg in args) {
    out = out.replaceFirst('%s', '$arg');
  }
  return out;
}

String _base64(String s) => base64Encode(utf8.encode(s));

String _hexEncode(String input) =>
    input.codeUnits.map((c) => c.toRadixString(16).padLeft(2, '0')).join();
