// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:dart_console/dart_console.dart' as dc;
import 'package:meta/meta.dart';

import 'cmd.dart';
import 'key_buffer_parser.dart';
import 'key_util.dart';
import 'model.dart';
import 'msg.dart';
import 'view.dart';

typedef ProgramOption = void Function(Program program);

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

ProgramOption WithContext(Future<void> Function() cancellation) =>
    withContext(cancellation);

ProgramOption withInput(Stream<List<int>>? input) {
  return (p) {
    p._input = input;
    p._disableInput = input == null;
  };
}

ProgramOption WithInput(Stream<List<int>>? input) => withInput(input);

ProgramOption withOutput(IOSink output) {
  return (p) {
    p._output = output;
  };
}

ProgramOption WithOutput(IOSink output) => withOutput(output);

ProgramOption withEnvironment(Map<String, String> env) {
  return (p) {
    p._environment = Map<String, String>.unmodifiable(env);
  };
}

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

ProgramOption WithoutSignalHandler() => withoutSignalHandler();
ProgramOption WithoutCatchPanics() => withoutCatchPanics();
ProgramOption WithoutRenderer() => withoutRenderer();
ProgramOption WithFilter(Msg? Function(Model model, Msg msg) filter) =>
    withFilter(filter);
ProgramOption WithFps(int fps) => withFps(fps);
ProgramOption WithColorProfile(ColorProfile profile) =>
    withColorProfile(profile);
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
  bool _altScreenEnabled = false;
  bool _cursorHidden = false;
  bool _focusReportingEnabled = false;
  bool _bracketedPasteEnabled = false;
  MouseMode _mouseMode = MouseMode.none;

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
    _output.write('\x1b[?25h');
    _output.write('\x1b[?1049l');
    _output.write('\x1b[?1000l\x1b[?1002l\x1b[?1003l\x1b[?1006l');
    _output.write('\x1b[?1004l');
    _output.write('\x1b[?2004l');
    _cursorHidden = false;
    _altScreenEnabled = false;
    _focusReportingEnabled = false;
    _bracketedPasteEnabled = false;
    _mouseMode = MouseMode.none;
    if (resetRenderer) {
      _output.write('\x1b[H\x1b[2J');
    }
    _console.rawMode = false;
  }

  Future<void> restoreTerminal() async {
    if (!_running) return;
    if (_disableRenderer) return;
    _console.rawMode = true;
    _startRenderTicker();
    final m = _runningModel;
    if (m != null) {
      final v = m.view();
      _configureTerminalForView(v);
      _render(v);
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

    void configureTerminalForView(View v) {
      final wantsAlt = v.altScreen || _compatOptions.altScreen;
      if (wantsAlt != _altScreenEnabled) {
        _output.write(wantsAlt ? '\x1b[?1049h' : '\x1b[?1049l');
        _altScreenEnabled = wantsAlt;
      }

      final wantsHiddenCursor = v.cursor == null && _compatOptions.hideCursor;
      if (wantsHiddenCursor != _cursorHidden) {
        _output.write(wantsHiddenCursor ? '\x1b[?25l' : '\x1b[?25h');
        _cursorHidden = wantsHiddenCursor;
      }

      if (v.reportFocus != _focusReportingEnabled) {
        _output.write(v.reportFocus ? '\x1b[?1004h' : '\x1b[?1004l');
        _focusReportingEnabled = v.reportFocus;
      }

      final wantsBracketedPaste = !v.disableBracketedPasteMode;
      if (wantsBracketedPaste != _bracketedPasteEnabled) {
        _output.write(wantsBracketedPaste ? '\x1b[?2004h' : '\x1b[?2004l');
        _bracketedPasteEnabled = wantsBracketedPaste;
      }

      if (v.mouseMode != _mouseMode) {
        _output.write('\x1b[?1000l\x1b[?1002l\x1b[?1003l\x1b[?1006l');
        switch (v.mouseMode) {
          case MouseMode.none:
            break;
          case MouseMode.cellMotion:
            _output.write('\x1b[?1002h\x1b[?1006h');
            break;
          case MouseMode.allMotion:
            _output.write('\x1b[?1003h\x1b[?1006h');
            break;
        }
        _mouseMode = v.mouseMode;
      }
    }

    void render(View v) {
      if (_disableRenderer) return;
      configureTerminalForView(v);
      if (v.windowTitle.isNotEmpty) {
        _output.write('\x1b]0;${v.windowTitle}\x07');
      }
      _output.write('\x1b[H\x1b[2J');
      _output.write(v.content);
      _logSink?.writeln('--- frame ---\n${v.content}');
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
          _output.write('\x1b[H\x1b[2J');
          return;
        case PrintLineMsg():
          if (!_altScreenEnabled) {
            _output.writeln(msg.messageBody);
          }
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
        final source = _input ?? stdin.asBroadcastStream();
        final keyBuffer = <int>[];
        _inputSub = source.listen(
          (bytes) {
            keyBuffer.addAll(bytes);
            dc.Key? parsed;
            while ((parsed = parseKeyFromBuffer(keyBuffer)) != null) {
              enqueue(KeyPressMsg(toTeaKey(parsed!)));
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
    if (_cursorHidden) {
      _output.write('\x1b[?25h');
      _cursorHidden = false;
    }
    if (_altScreenEnabled) {
      _output.write('\x1b[?1049l');
      _altScreenEnabled = false;
    }
    if (!_disableRenderer) {
      _console.rawMode = false;
    }
    unawaited(_logSink?.flush());
    unawaited(_logSink?.close());
    _logSink = null;
    _finished?.complete();
  }

  void _configureTerminalForView(View v) {
    final wantsAlt = v.altScreen || _compatOptions.altScreen;
    if (wantsAlt != _altScreenEnabled) {
      _output.write(wantsAlt ? '\x1b[?1049h' : '\x1b[?1049l');
      _altScreenEnabled = wantsAlt;
    }
  }

  void _render(View v) {
    _output.write('\x1b[H\x1b[2J');
    _output.write(v.content);
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
