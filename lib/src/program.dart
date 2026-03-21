// ignore_for_file: non_constant_identifier_names

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
  return _stdinBroadcastCache ??= stdin.asBroadcastStream(
    onListen: (subscription) => subscription.resume(),
    onCancel: (subscription) => subscription.pause(),
  );
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

@Deprecated('Use withContext(...)')
ProgramOption WithContext(Future<void> Function() cancellation) =>
    withContext(cancellation);

ProgramOption withInput(Stream<List<int>>? input) {
  return (p) {
    p._input = input;
    p._disableInput = input == null;
  };
}

@Deprecated('Use withInput(...)')
ProgramOption WithInput(Stream<List<int>>? input) => withInput(input);

ProgramOption withOutput(IOSink output) {
  return (p) {
    p._output = output;
  };
}

@Deprecated('Use withOutput(...)')
ProgramOption WithOutput(IOSink output) => withOutput(output);

ProgramOption withEnvironment(Map<String, String> env) {
  return (p) {
    p._environment = Map<String, String>.unmodifiable(env);
  };
}

@Deprecated('Use withEnvironment(...)')
ProgramOption WithEnvironment(Map<String, String> env) => withEnvironment(env);

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

@Deprecated('Use withoutSignalHandler()')
ProgramOption WithoutSignalHandler() => withoutSignalHandler();
@Deprecated('Use withoutCatchPanics()')
ProgramOption WithoutCatchPanics() => withoutCatchPanics();
@Deprecated('Use withoutRenderer()')
ProgramOption WithoutRenderer() => withoutRenderer();
@Deprecated('Use withFilter(...)')
ProgramOption WithFilter(Msg? Function(Model model, Msg msg) filter) =>
    withFilter(filter);
@Deprecated('Use withFps(...)')
ProgramOption WithFps(int fps) => withFps(fps);
@Deprecated('Use withColorProfile(...)')
ProgramOption WithColorProfile(ColorProfile profile) =>
    withColorProfile(profile);
@Deprecated('Use withWindowSize(...)')
ProgramOption WithWindowSize(int width, int height) =>
    withWindowSize(width, height);

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
  Timer? _renderTicker;
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
    _renderTicker?.cancel();
    _renderTicker = null;
    _renderer?.release(reset: resetRenderer);
    _console.rawMode = false;
  }

  Future<void> restoreTerminal() async {
    if (!_running) return;
    if (_disableRenderer) return;
    _console.rawMode = true;
    _startRenderTicker();
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

    void render(View v) {
      _renderer?.render(v);
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
          await restoreTerminal();
          enqueue(ResumeMsg());
          return;
        case RequestWindowSizeMsg():
          scheduleResizeMsg();
          return;
        case RequestForegroundColorMsg():
          enqueue(ForegroundColorMsg(0xFFFFFF));
          return;
        case RequestBackgroundColorMsg():
          enqueue(BackgroundColorMsg(0x000000));
          return;
        case RequestCursorColorMsg():
          enqueue(CursorColorMsg(0xFFFFFF));
          return;
        case RequestCursorPositionMsg():
          enqueue(CursorPositionMsg(x: 0, y: 0));
          return;
        case RequestTerminalVersionMsg():
          enqueue(
              TerminalVersionMsg(_environment['TERM_PROGRAM'] ?? 'unknown'));
          return;
        case RequestCapabilityMsg():
          enqueue(CapabilityMsg(msg.name));
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
        default:
      }

      final (nextModel, cmd) = model.update(msg);
      _runningModel = nextModel;
      await runCmd(cmd);
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
        Timer.periodic(_compatOptions.tickInterval!, (_) {
          enqueue(TickMsg(DateTime.now()));
        });
      }

      _startRenderTicker(render);

      final initCmd = _runningModel!.init();
      await runCmd(initCmd);
      render(_runningModel!.view());

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
    _renderTicker?.cancel();
    _renderTicker = null;
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

  void _render(View v) {
    _renderer?.render(v);
  }

  void _startRenderTicker([void Function(View v)? customRender]) {
    _renderTicker?.cancel();
    _renderTicker =
        Timer.periodic(Duration(milliseconds: (1000 / _fps).ceil()), (_) {
      final m = _runningModel;
      if (m != null && _running) {
        final v = m.view();
        if (customRender != null) {
          customRender(v);
        } else {
          _render(v);
        }
      }
    });
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
