import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:dart_tui/src/posix_terminal.dart';

typedef _TcGetAttrC = Int32 Function(Int32, Pointer<Uint8>);
typedef _TcGetAttrD = int Function(int, Pointer<Uint8>);
typedef _TcSetAttrC = Int32 Function(Int32, Int32, Pointer<Uint8>);
typedef _TcSetAttrD = int Function(int, int, Pointer<Uint8>);

void main(List<String> args) {
  if (args.contains('--non-tty')) {
    enablePosixRawInput();
    restorePosixRawInput();
    print('POSIX non-TTY probe passed');
    return;
  }

  final libc = DynamicLibrary.process();
  final tcgetattr = libc.lookupFunction<_TcGetAttrC, _TcGetAttrD>('tcgetattr');
  final tcsetattr = libc.lookupFunction<_TcSetAttrC, _TcSetAttrD>('tcsetattr');
  final termios = calloc<Uint8>(256);
  try {
    check(tcgetattr(0, termios) == 0, 'stdin must be a terminal');
    final macOS = Platform.isMacOS;
    final data = ByteData.sublistView(termios.asTypedList(256));
    int read(int word) => macOS
        ? data.getUint64(word * 8, Endian.host)
        : data.getUint32(word * 4, Endian.host);
    void write(int word, int value) => macOS
        ? data.setUint64(word * 8, value, Endian.host)
        : data.setUint32(word * 4, value, Endian.host);

    final ixon = macOS ? 0x200 : 0x400;
    final isig = macOS ? 0x80 : 0x1;
    final iexten = macOS ? 0x400 : 0x8000;
    final lflagBits = isig | iexten;
    const echo = 0x8;
    final originalIflag = read(0);
    final originalLflag = read(3);
    final expectedIflag = originalIflag & ~ixon;
    final expectedLflag = (originalLflag | isig) & ~iexten;
    write(0, expectedIflag);
    write(3, expectedLflag);
    check(tcsetattr(0, 0, termios) == 0, 'could not set initial flags');

    enablePosixRawInput();
    enablePosixRawInput();
    check(tcgetattr(0, termios) == 0, 'could not read raw flags');
    check((read(0) & ixon) == 0, 'IXON remained enabled in raw mode');
    check(
        (read(3) & lflagBits) == 0, 'ISIG/IEXTEN remained enabled in raw mode');

    // Simulate external terminal-mode changes while raw input is active.
    final childIflag = (read(0) & ~ixon) | (~expectedIflag & ixon);
    final childEcho = (~read(3)) & echo;
    final childLflag = (read(3) & ~lflagBits & ~echo) |
        (~expectedLflag & lflagBits) |
        childEcho;
    write(0, childIflag);
    write(3, childLflag);
    check(tcsetattr(0, 0, termios) == 0, 'could not set child flags');
    check(tcgetattr(0, termios) == 0, 'could not read child flags');
    check(
      (read(0) & ixon) == (~expectedIflag & ixon),
      'child did not change IXON',
    );
    check(
      (read(3) & lflagBits) == (~expectedLflag & lflagBits),
      'child did not change ISIG/IEXTEN',
    );
    check((read(3) & echo) == childEcho, 'external change to ECHO was lost');

    restorePosixRawInput();
    restorePosixRawInput();
    check(tcgetattr(0, termios) == 0, 'could not read restored flags');
    check(
      (read(0) & ixon) == (expectedIflag & ixon),
      'IXON was not restored',
    );
    check(
      (read(3) & lflagBits) == (expectedLflag & lflagBits),
      'ISIG/IEXTEN were not restored',
    );
    check((read(3) & echo) == childEcho, 'unrelated ECHO change was lost');
    print('POSIX raw mode PTY probe passed');
  } finally {
    restorePosixRawInput();
    calloc.free(termios);
  }
}

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}
