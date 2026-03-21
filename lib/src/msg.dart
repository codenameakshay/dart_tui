import 'cmd.dart';

/// Terminal events and application messages (Bubble Tea style).
abstract class Msg {
  const Msg();
}

/// Program should stop gracefully.
final class QuitMsg extends Msg {}

/// Program should stop with interrupted semantics.
final class InterruptMsg extends Msg {}

/// Program should suspend.
final class SuspendMsg extends Msg {}

/// Program resumed from suspend.
final class ResumeMsg extends Msg {}

/// Tick signal for timers/animation.
final class TickMsg extends Msg {
  TickMsg(this.when, {this.id});
  final DateTime when;
  final Object? id;
}

/// Window resize event.
final class WindowSizeMsg extends Msg {
  WindowSizeMsg(this.width, this.height);
  final int width;
  final int height;
}

/// Internal command message that executes commands concurrently.
final class BatchMsg extends Msg {
  BatchMsg(this.cmds);
  final List<Cmd> cmds;
}

/// Internal command message that executes commands in-order.
final class SequenceMsg extends Msg {
  SequenceMsg(this.cmds);
  final List<Cmd> cmds;
}

/// Internal request to clear screen on next frame.
final class ClearScreenMsg extends Msg {}

/// Raw sequence send message.
final class RawMsg extends Msg {
  RawMsg(this.value);
  final Object value;
}

/// Execute an external process, releasing terminal control around it.
final class ExecMsg extends Msg {
  ExecMsg({
    required this.cmd,
    required this.args,
    this.env,
    this.onExit,
    this.inheritStdio = true,
  });

  final String cmd;
  final List<String> args;
  final Map<String, String>? env;
  final Msg? Function(int exitCode)? onExit;
  final bool inheritStdio;
}

/// Color profile update from terminal introspection.
final class ColorProfileMsg extends Msg {
  ColorProfileMsg(this.profile);
  final ColorProfile profile;
}

enum ColorProfile {
  noColor,
  ansi,
  ansi256,
  trueColor,
}

/// Foreground color response message (hex RGB value).
final class ForegroundColorMsg extends Msg {
  ForegroundColorMsg(this.rgb);
  final int rgb;
}

/// Background color response message (hex RGB value).
final class BackgroundColorMsg extends Msg {
  BackgroundColorMsg(this.rgb);
  final int rgb;
}

/// Cursor color response message (hex RGB value).
final class CursorColorMsg extends Msg {
  CursorColorMsg(this.rgb);
  final int rgb;
}

/// Clipboard content read response.
final class ClipboardMsg extends Msg {
  ClipboardMsg({
    required this.content,
    required this.selection,
  });

  final String content;
  final int selection;
}

/// Bracketed paste text payload.
final class PasteMsg extends Msg {
  PasteMsg(this.content);
  final String content;
}

final class PasteStartMsg extends Msg {}

final class PasteEndMsg extends Msg {}

final class FocusMsg extends Msg {}

final class BlurMsg extends Msg {}

/// Environment payload emitted at startup.
final class EnvMsg extends Msg {
  EnvMsg(this.environment);
  final Map<String, String> environment;
}

final class CapabilityMsg extends Msg {
  CapabilityMsg(this.content);
  final String content;
}

final class TerminalVersionMsg extends Msg {
  TerminalVersionMsg(this.name);
  final String name;
}

final class ModeReportMsg extends Msg {
  ModeReportMsg({
    required this.mode,
    required this.value,
  });

  final int mode;
  final int value;
}

final class PrintLineMsg extends Msg {
  PrintLineMsg(this.messageBody);
  final String messageBody;
}

final class CursorPositionMsg extends Msg {
  CursorPositionMsg({
    required this.x,
    required this.y,
  });

  final int x;
  final int y;
}

/// Keyboard enhancements negotiation response.
final class KeyboardEnhancementsMsg extends Msg {
  KeyboardEnhancementsMsg(this.flags);
  final int flags;

  bool get supportsKeyDisambiguation => flags > 0;
  bool get supportsEventTypes => (flags & kittyReportEventTypes) != 0;
}

const int kittyReportEventTypes = 1 << 1;

/// Keyboard modifiers.
enum KeyMod {
  shift,
  alt,
  ctrl,
  meta,
  hyper,
  superKey,
  capsLock,
  numLock,
  scrollLock,
}

/// Logical key.
final class TeaKey {
  const TeaKey({
    required this.code,
    this.text = '',
    this.modifiers = const <KeyMod>{},
    this.baseCode,
    this.shiftedCode,
    this.isRepeat = false,
  });

  final KeyCode code;
  final String text;
  final Set<KeyMod> modifiers;
  final KeyCode? baseCode;
  final KeyCode? shiftedCode;
  final bool isRepeat;

  String keystroke() {
    final parts = <String>[];
    if (modifiers.contains(KeyMod.ctrl)) parts.add('ctrl');
    if (modifiers.contains(KeyMod.alt)) parts.add('alt');
    if (modifiers.contains(KeyMod.shift)) parts.add('shift');
    if (modifiers.contains(KeyMod.meta)) parts.add('meta');
    if (modifiers.contains(KeyMod.hyper)) parts.add('hyper');
    if (modifiers.contains(KeyMod.superKey)) parts.add('super');
    parts.add(_codeName(code, text));
    return parts.join('+');
  }

  @override
  String toString() => _codeName(code, text);
}

enum KeyCode {
  extended,
  up,
  down,
  right,
  left,
  home,
  end,
  pageUp,
  pageDown,
  insert,
  delete,
  backspace,
  tab,
  enter,
  escape,
  space,
  f1,
  f2,
  f3,
  f4,
  f5,
  f6,
  f7,
  f8,
  f9,
  f10,
  f11,
  f12,
  rune,
  unknown,
}

String _codeName(KeyCode code, String text) {
  if (code == KeyCode.rune) {
    if (text == ' ') return 'space';
    return text;
  }
  return switch (code) {
    KeyCode.up => 'up',
    KeyCode.down => 'down',
    KeyCode.right => 'right',
    KeyCode.left => 'left',
    KeyCode.home => 'home',
    KeyCode.end => 'end',
    KeyCode.pageUp => 'pgup',
    KeyCode.pageDown => 'pgdown',
    KeyCode.insert => 'insert',
    KeyCode.delete => 'delete',
    KeyCode.backspace => 'backspace',
    KeyCode.tab => 'tab',
    KeyCode.enter => 'enter',
    KeyCode.escape => 'esc',
    KeyCode.space => 'space',
    KeyCode.f1 => 'f1',
    KeyCode.f2 => 'f2',
    KeyCode.f3 => 'f3',
    KeyCode.f4 => 'f4',
    KeyCode.f5 => 'f5',
    KeyCode.f6 => 'f6',
    KeyCode.f7 => 'f7',
    KeyCode.f8 => 'f8',
    KeyCode.f9 => 'f9',
    KeyCode.f10 => 'f10',
    KeyCode.f11 => 'f11',
    KeyCode.f12 => 'f12',
    _ => 'unknown',
  };
}

abstract class KeyMsg extends Msg {
  KeyMsg(this.keyEvent);
  final TeaKey keyEvent;
  String get key => keyEvent.keystroke();
  String keystroke() => keyEvent.keystroke();
}

final class KeyPressMsg extends KeyMsg {
  KeyPressMsg(super.keyEvent);
  @override
  String toString() => key;
}

final class KeyReleaseMsg extends KeyMsg {
  KeyReleaseMsg(super.keyEvent);
  @override
  String toString() => key;
}

/// Legacy alias retained for compatibility.
typedef LegacyKeyMsg = KeyPressMsg;

enum MouseButton {
  none,
  left,
  middle,
  right,
  wheelUp,
  wheelDown,
  wheelLeft,
  wheelRight,
  backward,
  forward,
  button10,
  button11,
}

final class Mouse {
  const Mouse({
    required this.x,
    required this.y,
    required this.button,
    this.modifiers = const <KeyMod>{},
  });

  final int x;
  final int y;
  final MouseButton button;
  final Set<KeyMod> modifiers;

  @override
  String toString() => '$button@$x,$y';
}

abstract interface class MouseMsg implements Msg {
  Mouse get mouse;
}

final class MouseClickMsg extends Msg implements MouseMsg {
  MouseClickMsg(this.mouse);
  @override
  final Mouse mouse;
}

final class MouseReleaseMsg extends Msg implements MouseMsg {
  MouseReleaseMsg(this.mouse);
  @override
  final Mouse mouse;
}

final class MouseWheelMsg extends Msg implements MouseMsg {
  MouseWheelMsg(this.mouse);
  @override
  final Mouse mouse;
}

final class MouseMotionMsg extends Msg implements MouseMsg {
  MouseMotionMsg(this.mouse);
  @override
  final Mouse mouse;
}

/// Emitted when TextInput validation fails.
final class ValidationFailedMsg extends Msg {
  ValidationFailedMsg(this.value);
  final String value;
}
