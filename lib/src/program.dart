import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';

import 'package:dart_console/dart_console.dart';
import 'package:meta/meta.dart';

import 'cmd.dart';
import 'key_util.dart';
import 'model.dart';
import 'msg.dart';

const _tickSentinel = '__dart_tui_tick__';

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

  /// If set, [Program] races key reads with this interval and emits [TickMsg].
  /// Needed for spinners/animations without blocking the event loop.
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

    void schedule(Cmd? cmd) {
      if (cmd == null) return;
      cmd().then((m) {
        if (m != null) queue.add(m);
      });
    }

    var model = initial;
    var exit = false;

    void applyOne(Msg msg) {
      if (msg is CompoundMsg) {
        for (final m in msg.msgs) {
          applyOne(m);
        }
        return;
      }
      if (msg is QuitMsg) {
        exit = true;
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

      schedule(model.init());

      if (!Platform.isWindows) {
        try {
          sigSub = ProcessSignal.sigwinch.watch().listen((_) {
            queue.add(
              WindowSizeMsg(_console.windowWidth, _console.windowHeight),
            );
          });
        } on Object {
          // Some embedders may not expose SIGWINCH.
        }
      }

      queue.add(
        WindowSizeMsg(_console.windowWidth, _console.windowHeight),
      );

      while (!exit) {
        await Future<void>.delayed(Duration.zero);
        while (queue.isNotEmpty) {
          applyOne(queue.removeFirst());
        }
        if (exit) {
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

        String? keyOrTick;
        if (_options.tickInterval != null) {
          keyOrTick = await Future.any<String?>([
            _readKeyTeaIsolate(),
            Future<String?>.delayed(
              _options.tickInterval!,
              () => _tickSentinel,
            ),
          ]);
        } else {
          keyOrTick = await _readKeyTeaIsolate();
        }

        if (keyOrTick == _tickSentinel) {
          queue.add(TickMsg(DateTime.now()));
        } else if (keyOrTick != null) {
          queue.add(KeyMsg(keyOrTick));
        }
      }

      if (model is OutcomeModel) {
        return (model as OutcomeModel).outcome;
      }
      return null;
    } finally {
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

  /// Reads one key in a short-lived isolate so the main isolate can still run timers.
  Future<String> _readKeyTeaIsolate() {
    return Isolate.run(() {
      final c = Console();
      final key = c.readKey();
      return keyToTeaString(key);
    });
  }

  void _render(String view) {
    stdout.write('\x1b[H\x1b[2J');
    stdout.write(view);
    _logSink?.writeln('--- frame ---\n$view');
  }
}
