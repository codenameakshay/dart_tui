// coverage:ignore-file
// POSIX termios (FFI) code. It only acts on a real TTY, which `dart test`
// never has; tool/pty_program_runtime_test.py exercises it in a PTY instead.
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

typedef _TcGetAttrC = Int32 Function(Int32, Pointer<Uint8>);
typedef _TcGetAttrD = int Function(int, Pointer<Uint8>);
typedef _TcSetAttrC = Int32 Function(Int32, Int32, Pointer<Uint8>);
typedef _TcSetAttrD = int Function(int, int, Pointer<Uint8>);
typedef _DupC = Int32 Function(Int32);
typedef _DupD = int Function(int);
typedef _CloseC = Int32 Function(Int32);
typedef _CloseD = int Function(int);

// Larger than `struct termios` on macOS (72 bytes) and Linux (60 bytes).
const int _termiosBytes = 256;
const int _tcsaNow = 0;
const Duration _stdinRestoreTimeout = Duration(seconds: 2);

// Bits of c_iflag / c_lflag that were set before raw mode, or null when raw
// input is not active.
({int iflag, int lflag})? _saved;

/// Clears the termios flags that dart:io's `lineMode`/`echoMode` leave set:
/// `ISIG` (Ctrl+C/Z/\ become signals), `IEXTEN` (Ctrl+V/O are swallowed) and
/// `IXON` (Ctrl+S/Q pause output). With them cleared those keys arrive as
/// bytes, as in Bubble Tea's raw mode, so a model can bind `ctrl+z` to
/// `suspend` instead of the kernel stopping the process without cleanup.
///
/// No-op off macOS/Linux or when stdin is not a terminal. The previous bits are
/// saved for [restorePosixRawInput].
void enablePosixRawInput() => _setRawInput(true);

/// Restores the flags cleared by [enablePosixRawInput]. No-op if raw input is
/// not active.
void restorePosixRawInput() => _setRawInput(false);

/// Keeps stdin open while a Dart stdin reader is cancelled, which closes fd 0.
///
/// Pass the returned descriptor to [restoreStdin] after cancelling the
/// reader. Returns null off macOS/Linux or when stdin cannot be duplicated.
int? preserveStdin() {
  if (!Platform.isMacOS && !Platform.isLinux) return null;
  final dup = DynamicLibrary.process().lookupFunction<_DupC, _DupD>('dup');
  final saved = dup(0);
  return saved < 0 ? null : saved;
}

/// Reclaims fd 0 from [savedFd] after a Dart stdin reader closes it.
///
/// Each `dup` atomically chooses the lowest unused descriptor. If fd 0 is
/// still occupied, only the descriptor allocated by that attempt is closed
/// before yielding and retrying. The saved descriptor is closed on every exit.
Future<bool> restoreStdin(int savedFd) async {
  if (!Platform.isMacOS && !Platform.isLinux) {
    throw UnsupportedError('restoreStdin is only available on macOS/Linux');
  }
  final libc = DynamicLibrary.process();
  final dup = libc.lookupFunction<_DupC, _DupD>('dup');
  final close = libc.lookupFunction<_CloseC, _CloseD>('close');
  try {
    final timeout = Stopwatch()..start();
    do {
      final restored = dup(savedFd);
      if (restored == 0) return true;
      if (restored < 0) return false;
      close(restored);
      await Future<void>.delayed(const Duration(milliseconds: 1));
    } while (timeout.elapsed < _stdinRestoreTimeout);
    return false;
  } finally {
    close(savedFd);
  }
}

void _setRawInput(bool raw) {
  if (!Platform.isMacOS && !Platform.isLinux) return;
  if (raw == (_saved != null)) return;
  // <termios.h>: tcflag_t is unsigned long on macOS, unsigned int on Linux;
  // c_iflag is the first flag word and c_lflag the fourth.
  final macOS = Platform.isMacOS;
  final ixon = macOS ? 0x200 : 0x400;
  final lflagBits = macOS ? 0x80 | 0x400 : 0x1 | 0x8000; // ISIG | IEXTEN
  final libc = DynamicLibrary.process();
  final tcgetattr = libc.lookupFunction<_TcGetAttrC, _TcGetAttrD>('tcgetattr');
  final tcsetattr = libc.lookupFunction<_TcSetAttrC, _TcSetAttrD>('tcsetattr');
  final termios = calloc<Uint8>(_termiosBytes);
  try {
    if (tcgetattr(0, termios) != 0) return; // not a terminal
    final data = ByteData.sublistView(termios.asTypedList(_termiosBytes));
    int read(int word) => macOS
        ? data.getUint64(word * 8, Endian.host)
        : data.getUint32(word * 4, Endian.host);
    void write(int word, int value) => macOS
        ? data.setUint64(word * 8, value, Endian.host)
        : data.setUint32(word * 4, value, Endian.host);
    var iflag = read(0);
    var lflag = read(3);
    if (raw) {
      _saved = (iflag: iflag & ixon, lflag: lflag & lflagBits);
      iflag &= ~ixon;
      lflag &= ~lflagBits;
    } else {
      iflag = (iflag & ~ixon) | _saved!.iflag;
      lflag = (lflag & ~lflagBits) | _saved!.lflag;
      _saved = null;
    }
    write(0, iflag);
    write(3, lflag);
    tcsetattr(0, _tcsaNow, termios);
  } finally {
    calloc.free(termios);
  }
}
