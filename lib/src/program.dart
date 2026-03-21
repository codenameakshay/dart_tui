import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:dart_console/dart_console.dart';
import 'package:meta/meta.dart';

import 'cmd.dart';
import 'key_buffer_parser.dart';
import 'key_util.dart';
import 'model.dart';
import 'msg.dart';

/// [stdin] is single-subscription; chained [Program.run] / [Program.runForResult]
/// calls (e.g. prompts) each need a new listener. Wrapping once as broadcast
/// allows that while keeping a single underlying subscription to stdin.
Stream<List<int>>? _stdinBroadcastCache;

Stream<List<int>> _stdinBroadcast() =>
    _stdinBroadcastCache ??= stdin.asBroadcastStream();

/// Options for [Program].
@immutable
class ProgramOptions {
  const ProgramOptions({
    this.altScreen = false,
    this.hideCursor = true,
    this.tickInterval,
    this.logFile,
  });

  /// Use the alternate screen buffer (DEC 1049).
  final bool altScreen;

  /// Hide the caret while the program runs.
  final bool hideCursor;

  /// If set, [Program] emits [TickMsg] on this interval.
  ///
  /// Input is read asynchronously from stdin so the event loop can deliver
  /// [TickMsg] between key events (for spinners and other animations).
  final Duration? tickInterval;

  /// Optional append-only debug log (Bubble Tea–style file logging).
  final File? logFile;
}

/// Bubble Tea–style terminal program loop.
final class Program {
  Program({
    Console? console,
    ProgramOptions options = const ProgramOptions(),
  })  : _console = console ?? Console(),
        _options = options;

  final Console _console;
  final ProgramOptions _options;

  IOSink? _logSink;

  /// Run until [TeaModel.quit] is true or [QuitMsg] is processed.
  Future<void> run(TeaModel initial) async {
    await _runCore(initial);
  }

  /// Run an [OutcomeModel] until [OutcomeModel.outcome] is non-null.
  Future<T?> runForResult<T>(OutcomeModel<T> initial) async {
    final o = await _runCore(initial);
    return o as T?;
  }

  Future<Object?> _runCore(TeaModel initial) async {
    final queue = Queue<Msg>();
    StreamSubscription<ProcessSignal>? sigSub;
    StreamSubscription<List<int>>? stdinSub;
    Timer? tickTimer;
    Completer<void>? wake;
    final keyBuffer = <int>[];
    var shouldExit = false;

    void enqueue(Msg m) {
      queue.add(m);
      final w = wake;
      wake = null;
      w?.complete();
    }

    Future<void> waitForActivity() async {
      while (queue.isEmpty && !shouldExit) {
        final c = Completer<void>();
        wake = c;
        if (queue.isNotEmpty) {
          wake = null;
          if (!c.isCompleted) c.complete();
          continue;
        }
        await c.future;
      }
    }

    void schedule(Cmd? cmd) {
      if (cmd == null) return;
      cmd().then((m) {
        if (m != null) enqueue(m);
      });
    }

    var model = initial;

    void applyOne(Msg msg) {
      if (msg is CompoundMsg) {
        for (final m in msg.msgs) {
          applyOne(m);
        }
        return;
      }
      if (msg is QuitMsg) {
        shouldExit = true;
        return;
      }
      final result = model.update(msg);
      model = result.$1;
      schedule(result.$2);
    }

    _logSink = _options.logFile?.openWrite(mode: FileMode.append);

    try {
      if (_options.altScreen) {
        stdout.write('\x1b[?1049h');
      }
      if (_options.hideCursor) {
        stdout.write('\x1b[?25l');
      }

      _console.rawMode = true;

      schedule(model.init());

      if (!Platform.isWindows) {
        try {
          sigSub = ProcessSignal.sigwinch.watch().listen((_) {
            enqueue(
              WindowSizeMsg(_console.windowWidth, _console.windowHeight),
            );
          });
        } on Object {
          // Some embedders may not expose SIGWINCH.
        }
      }

      enqueue(
        WindowSizeMsg(_console.windowWidth, _console.windowHeight),
      );

      if (_options.tickInterval != null) {
        tickTimer = Timer.periodic(_options.tickInterval!, (_) {
          enqueue(TickMsg(DateTime.now()));
        });
      }

      stdinSub = _stdinBroadcast().listen(
        (data) {
          keyBuffer.addAll(data);
          Key? k;
          while ((k = parseKeyFromBuffer(keyBuffer)) != null) {
            enqueue(KeyMsg(keyToTeaString(k!)));
          }
        },
        cancelOnError: true,
      );

      while (!shouldExit) {
        await Future<void>.delayed(Duration.zero);
        while (queue.isNotEmpty) {
          applyOne(queue.removeFirst());
        }
        if (shouldExit) {
          break;
        }

        if (model is OutcomeModel) {
          final o = model as OutcomeModel;
          if (o.outcome != null) {
            return o.outcome;
          }
        }

        if (model.quit) {
          break;
        }

        _render(model.view());
        await waitForActivity();
      }

      if (model is OutcomeModel) {
        return (model as OutcomeModel).outcome;
      }
      return null;
    } finally {
      tickTimer?.cancel();
      await stdinSub?.cancel();
      await sigSub?.cancel();
      if (_options.hideCursor) {
        stdout.write('\x1b[?25h');
      }
      if (_options.altScreen) {
        stdout.write('\x1b[?1049l');
      }
      _console.rawMode = false;
      await _logSink?.flush();
      await _logSink?.close();
      _logSink = null;
    }
  }

  void _render(String view) {
    stdout.write('\x1b[H\x1b[2J');
    stdout.write(view);
    _logSink?.writeln('--- frame ---\n$view');
  }
}
