import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:dart_console/dart_console.dart' as dc;
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
    dc.Console? console,
    ProgramOptions options = const ProgramOptions(),
    List<ProgramOption> programOptions = const [],
  })  : _console = console ?? dc.Console(),
        _compatOptions = options {
    for (final opt in programOptions) {
      opt(this);
    }
  }

  final dc.Console _console;
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
    _console.rawMode = false;
  }

  Future<void> restoreTerminal() async {
    if (!_running) return;
    if (_disableRenderer) return;
    _console.rawMode = true;
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
      final width = _width ?? _console.windowWidth;
      final height = _height ?? _console.windowHeight;
      enqueue(WindowSizeMsg(width, height));
    }

    Future<void> handleMsg(Msg rawMsg) async {
      var msg = rawMsg;
      final model = _runningModel!;
      if (_filter != null) {
        final filtered = _filter!(model, msg);
        if (filtered == null) return;
        msg = filtered;
      }

      switch (msg) {
        case QuitMsg():
          _running = false;
          return;
        case InterruptMsg():
          _running = false;
          return;
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
          return;
        case RequestWindowSizeMsg():
          scheduleResizeMsg();
          return;
        case RequestForegroundColorMsg():
          _output.write('\x1b]10;?\x07');
          if (_disableInput) enqueue(ForegroundColorMsg(0xFFFFFF));
          return;
        case RequestBackgroundColorMsg():
          _output.write('\x1b]11;?\x07');
          if (_disableInput) enqueue(BackgroundColorMsg(0x000000));
          return;
        case RequestCursorColorMsg():
          _output.write('\x1b]12;?\x07');
          if (_disableInput) enqueue(CursorColorMsg(0xFFFFFF));
          return;
        case RequestCursorPositionMsg():
          _output.write('\x1b[6n');
          if (_disableInput) enqueue(CursorPositionMsg(x: 0, y: 0));
          return;
        case RequestTerminalVersionMsg():
          _output.write('\x1b[>0c');
          if (_disableInput) enqueue(TerminalVersionMsg('unknown'));
          return;
        case RequestCapabilityMsg():
          final encoded = _hexEncode(msg.name);
          _output.write('\x1bP+q$encoded\x1b\\');
          if (_disableInput) enqueue(CapabilityMsg('${msg.name}=unknown'));
          return;
        case SetClipboardMsg():
          _output.write('\x1b]52;c;${_base64(msg.value)}\x07');
          return;
        case ReadClipboardMsg():
          _output.write('\x1b]52;c;?\x07');
          return;
        case SetPrimaryClipboardMsg():
          _output.write('\x1b]52;p;${_base64(msg.value)}\x07');
          return;
        case ReadPrimaryClipboardMsg():
          _output.write('\x1b]52;p;?\x07');
          return;
        case ClearScreenMsg():
          _renderer?.clearScreen();
          return;
        case PrintLineMsg():
          _renderer?.insertAbove(msg.messageBody);
          return;
        case BatchMsg():
          for (final c in msg.cmds) {
            unawaited(runCmd(c));
          }
          return;
        case SequenceMsg():
          for (final c in msg.cmds) {
            await runCmd(c);
          }
          return;
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
          return;
        default:
      }

      if (msg is ModeReportMsg && msg.mode == 2026 && (msg.value == 1 || msg.value == 2)) {
        _renderer?.setSyncUpdates(true);
      }
      final (nextModel, cmd) = model.update(msg);
      _runningModel = nextModel;
      await runCmd(cmd);
      await render(_runningModel!.view());
    }

    try {
      _logSink = _compatOptions.logFile?.openWrite(mode: FileMode.append);
      _renderer = _disableRenderer
          ? NilRenderer()
          : AnsiRenderer(
              output: _output,
              logSink: _logSink,
              defaultAltScreen: _compatOptions.altScreen,
              defaultHideCursor: _compatOptions.hideCursor,
            );
      if (!_disableRenderer) {
        _console.rawMode = true;
      }

      if (!_disableSignalHandler && !Platform.isWindows) {
        _sigSub =
            ProcessSignal.sigwinch.watch().listen((_) => scheduleResizeMsg());
      }

      scheduleResizeMsg();
      // Query terminal for synchronized updates support (DEC mode 2026)
      if (!_disableInput) {
        _output.write('\x1b[?2026\$y');
      }
      enqueue(ColorProfileMsg(_profile));
      enqueue(EnvMsg(_environment));

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

      if (_compatOptions.tickInterval != null) {
        _tickTimer?.cancel();
        _tickTimer = Timer.periodic(_compatOptions.tickInterval!, (_) {
          enqueue(TickMsg(DateTime.now()));
        });
      }

      final initCmd = _runningModel!.init();
      await runCmd(initCmd);
      await render(_runningModel!.view());

      final externalCancellation = _externalCancellation;
      if (externalCancellation != null) {
        unawaited(externalCancellation().then((_) {
          if (_running) {
            enqueue(InterruptMsg());
          }
        }));
      }

      while (_running) {
        while (queue.isNotEmpty && _running) {
          await handleMsg(queue.removeFirst());
          final m = _runningModel;
          if (m is OutcomeModel && m.outcome != null) {
            _running = false;
            break;
          }
        }
        if (_running) {
          await waitForActivity();
        }
      }
    } finally {
      _shutdown();
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
      _console.rawMode = false;
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
