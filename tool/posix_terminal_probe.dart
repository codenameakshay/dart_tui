import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:dart_tui/src/posix_terminal.dart';

typedef _TcGetAttrC = Int32 Function(Int32, Pointer<Uint8>);
typedef _TcGetAttrD = int Function(int, Pointer<Uint8>);
typedef _TcSetAttrC = Int32 Function(Int32, Int32, Pointer<Uint8>);
typedef _TcSetAttrD = int Function(int, int, Pointer<Uint8>);
typedef _CloseC = Int32 Function(Int32);
typedef _CloseD = int Function(int);
typedef _OpenC = Int32 Function(Pointer<Utf8>, Int32);
typedef _OpenD = int Function(Pointer<Utf8>, int);
typedef _FcntlC = Int32 Function(Int32, Int32);
typedef _FcntlD = int Function(int, int);

Future<void> main(List<String> args) async {
  if (args.contains('--non-tty')) {
    enablePosixRawInput();
    restorePosixRawInput();
    print('POSIX non-TTY probe passed');
    return;
  }

  final libc = DynamicLibrary.process();
  final close = libc.lookupFunction<_CloseC, _CloseD>('close');
  final open = libc.lookupFunction<_OpenC, _OpenD>('open');
  final fcntl = libc.lookupFunction<_FcntlC, _FcntlD>('fcntl');
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

    if (macOS || Platform.isLinux) {
      final savedStdin = preserveStdin();
      if (savedStdin == null) throw StateError('could not preserve stdin');
      check(close(0) == 0, 'could not simulate stdin reader cancellation');
      final nullPath = '/dev/null'.toNativeUtf8();
      late final int blocker;
      try {
        blocker = open(nullPath, 0);
      } finally {
        calloc.free(nullPath);
      }
      check(blocker == 0, 'could not occupy fd 0 for retry test');
      final releaseBlocker = Future<void>.delayed(Duration.zero, () {
        check(close(blocker) == 0, 'could not release fd 0');
      });
      check(await restoreStdin(savedStdin), 'could not restore fd 0');
      await releaseBlocker;
      check(tcgetattr(0, termios) == 0, 'restored fd 0 is not the PTY');

      final timedOutBackup = preserveStdin();
      final recoveryBackup = preserveStdin();
      if (timedOutBackup == null || recoveryBackup == null) {
        throw StateError('could not preserve stdin for timeout test');
      }
      check(close(0) == 0, 'could not close fd 0 for timeout test');
      final occupiedPath = '/dev/null'.toNativeUtf8();
      late final int occupiedStdin;
      try {
        occupiedStdin = open(occupiedPath, 0);
      } finally {
        calloc.free(occupiedPath);
      }
      check(occupiedStdin == 0, 'could not occupy fd 0 for timeout test');
      check(
        !await restoreStdin(timedOutBackup),
        'restore succeeded while fd 0 stayed occupied',
      );
      check(
        fcntl(timedOutBackup, 1) == -1,
        'timed-out restore leaked its saved descriptor',
      );
      check(close(occupiedStdin) == 0, 'could not release occupied fd 0');
      check(await restoreStdin(recoveryBackup), 'could not recover fd 0');
      check(tcgetattr(0, termios) == 0, 'recovered fd 0 is not the PTY');
    }
    print('POSIX raw mode PTY probe passed');
  } finally {
    restorePosixRawInput();
    calloc.free(termios);
  }
}

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}
