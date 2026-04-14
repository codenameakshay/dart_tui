import 'dart:async';

import 'msg.dart';

/// Async side-effect that eventually yields a [Msg] (Bubble Tea `Cmd`).
typedef Cmd = FutureOr<Msg?> Function();

/// Run several commands concurrently.
Cmd? batch(List<Cmd?> cmds) => _compactCmds(cmds, (v) => BatchMsg(v));

/// Run commands in order.
Cmd? sequence(List<Cmd?> cmds) => _compactCmds(cmds, (v) => SequenceMsg(v));

Cmd? _compactCmds(List<Cmd?> cmds, Msg Function(List<Cmd>) wrap) {
  final valid = cmds.whereType<Cmd>().toList();
  if (valid.isEmpty) return null;
  if (valid.length == 1) return valid.single;
  return () => wrap(valid);
}

/// Delay before delivering a time-based message.
Cmd tick(Duration d, Msg Function(DateTime t) fn) {
  return () async {
    await Future<void>.delayed(d);
    return fn(DateTime.now());
  };
}

/// Tick aligned to wall clock boundary.
Cmd every(Duration d, Msg Function(DateTime t) fn) {
  return () async {
    final now = DateTime.now();
    final micros = d.inMicroseconds;
    final nowMicros = now.microsecondsSinceEpoch;
    final nextMicros = ((nowMicros ~/ micros) + 1) * micros;
    final wait = Duration(microseconds: nextMicros - nowMicros);
    await Future<void>.delayed(wait);
    return fn(DateTime.now());
  };
}

Msg quit() => QuitMsg();
Msg interrupt() => InterruptMsg();
Msg suspend() => SuspendMsg();
Msg clearScreen() => ClearScreenMsg();
Msg requestWindowSize() => RequestWindowSizeMsg();
Msg requestTerminalVersion() => RequestTerminalVersionMsg();
Msg requestForegroundColor() => RequestForegroundColorMsg();
Msg requestBackgroundColor() => RequestBackgroundColorMsg();
Msg requestCursorColor() => RequestCursorColorMsg();
Msg requestCursorPosition() => RequestCursorPositionMsg();
Cmd requestCapability(String name) => () => RequestCapabilityMsg(name);
Cmd setClipboard(String s) => () => SetClipboardMsg(s);
Msg readClipboard() => ReadClipboardMsg();
Cmd setPrimaryClipboard(String s) => () => SetPrimaryClipboardMsg(s);
Msg readPrimaryClipboard() => ReadPrimaryClipboardMsg();
Cmd raw(Object value) => () => RawMsg(value);

/// Execute an external process, releasing terminal control around it.
Cmd execProcess(
  String executable,
  List<String> arguments, {
  Map<String, String>? environment,
  bool inheritStdio = true,
  Msg? Function(int exitCode)? onExit,
}) =>
    () => ExecMsg(
          cmd: executable,
          args: arguments,
          env: environment,
          inheritStdio: inheritStdio,
          onExit: onExit,
        );

/// Tick with an ID for routing to specific timer/stopwatch models.
Cmd tickWithId(Duration d, Object id) => () async {
      await Future<void>.delayed(d);
      return TickMsg(DateTime.now(), id: id);
    };
Cmd println([Object? value]) => () => PrintLineMsg('${value ?? ''}');
Cmd printf(String template, [List<Object?> args = const []]) =>
    () => PrintLineMsg(_format(template, args));

// ── Terminal mode commands ─────────────────────────────────────────────────────

/// Enter the alternate screen buffer.
Msg enterAltScreen() => EnterAltScreenMsg();

/// Exit the alternate screen buffer.
Msg exitAltScreen() => ExitAltScreenMsg();

/// Hide the terminal cursor.
Msg hideCursor() => HideCursorMsg();

/// Show the terminal cursor.
Msg showCursor() => ShowCursorMsg();

/// Set the terminal window title.
Cmd setWindowTitle(String title) => () => SetWindowTitleMsg(title);

/// Clear the scroll area (non-alt-screen) and reset the scroll region.
Msg clearScrollArea() => ClearScrollAreaMsg();

/// Scroll the terminal up by [n] lines.
Cmd scrollUp([int n = 1]) => () => ScrollMsg(n, up: true);

/// Scroll the terminal down by [n] lines.
Cmd scrollDown([int n = 1]) => () => ScrollMsg(n, up: false);

final class RequestWindowSizeMsg extends Msg {}

final class RequestTerminalVersionMsg extends Msg {}

final class RequestForegroundColorMsg extends Msg {}

final class RequestBackgroundColorMsg extends Msg {}

final class RequestCursorColorMsg extends Msg {}

final class RequestCursorPositionMsg extends Msg {}

final class RequestCapabilityMsg extends Msg {
  RequestCapabilityMsg(this.name);
  final String name;
}

final class SetClipboardMsg extends Msg {
  SetClipboardMsg(this.value);
  final String value;
}

final class ReadClipboardMsg extends Msg {}

final class SetPrimaryClipboardMsg extends Msg {
  SetPrimaryClipboardMsg(this.value);
  final String value;
}

final class ReadPrimaryClipboardMsg extends Msg {}

final class EnterAltScreenMsg extends Msg {}

final class ExitAltScreenMsg extends Msg {}

final class HideCursorMsg extends Msg {}

final class ShowCursorMsg extends Msg {}

final class SetWindowTitleMsg extends Msg {
  SetWindowTitleMsg(this.title);
  final String title;
}

final class ClearScrollAreaMsg extends Msg {}

final class ScrollMsg extends Msg {
  ScrollMsg(this.lines, {required this.up});
  final int lines;
  final bool up;
}

String _format(String template, List<Object?> args) {
  var out = template;
  for (final arg in args) {
    out = out.replaceFirst('%s', '$arg');
  }
  return out;
}
