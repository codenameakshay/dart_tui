// ignore_for_file: non_constant_identifier_names

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
Cmd println([Object? value]) => () => PrintLineMsg('${value ?? ''}');
Cmd printf(String template, [List<Object?> args = const []]) =>
    () => PrintLineMsg(_format(template, args));

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

String _format(String template, List<Object?> args) {
  var out = template;
  for (final arg in args) {
    out = out.replaceFirst('%s', '$arg');
  }
  return out;
}

// Bubble Tea-like aliases.
@Deprecated('Use batch(...)')
Cmd? Batch(List<Cmd?> cmds) => batch(cmds);
@Deprecated('Use sequence(...)')
Cmd? Sequence(List<Cmd?> cmds) => sequence(cmds);
@Deprecated('Use tick(...)')
Cmd Tick(Duration d, Msg Function(DateTime t) fn) => tick(d, fn);
@Deprecated('Use every(...)')
Cmd Every(Duration d, Msg Function(DateTime t) fn) => every(d, fn);
@Deprecated('Use quit()')
Msg Quit() => quit();
@Deprecated('Use interrupt()')
Msg Interrupt() => interrupt();
@Deprecated('Use suspend()')
Msg Suspend() => suspend();
@Deprecated('Use clearScreen()')
Msg ClearScreen() => clearScreen();
@Deprecated('Use requestWindowSize()')
Msg RequestWindowSize() => requestWindowSize();
@Deprecated('Use requestTerminalVersion()')
Msg RequestTerminalVersion() => requestTerminalVersion();
@Deprecated('Use requestForegroundColor()')
Msg RequestForegroundColor() => requestForegroundColor();
@Deprecated('Use requestBackgroundColor()')
Msg RequestBackgroundColor() => requestBackgroundColor();
@Deprecated('Use requestCursorColor()')
Msg RequestCursorColor() => requestCursorColor();
@Deprecated('Use requestCursorPosition()')
Msg RequestCursorPosition() => requestCursorPosition();
@Deprecated('Use requestCapability(...)')
Cmd RequestCapability(String name) => requestCapability(name);
@Deprecated('Use setClipboard(...)')
Cmd SetClipboard(String s) => setClipboard(s);
@Deprecated('Use readClipboard()')
Msg ReadClipboard() => readClipboard();
@Deprecated('Use setPrimaryClipboard(...)')
Cmd SetPrimaryClipboard(String s) => setPrimaryClipboard(s);
@Deprecated('Use readPrimaryClipboard()')
Msg ReadPrimaryClipboard() => readPrimaryClipboard();
@Deprecated('Use raw(...)')
Cmd Raw(Object value) => raw(value);
@Deprecated('Use println(...)')
Cmd Println([Object? value]) => println(value);
@Deprecated('Use printf(...)')
Cmd Printf(String template, [List<Object?> args = const []]) =>
    printf(template, args);
