// coverage:ignore-file
// Windows-only console (Win32 FFI) code. Unreachable on the CI runners
// (macOS/Linux), so it is excluded from the coverage denominator rather than
// force-tested with brittle platform mocks.
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

// Windows console input-mode flags (consoleapi / wincon.h).
const int _enableProcessedInput = 0x0001;
const int _enableLineInput = 0x0002;
const int _enableEchoInput = 0x0004;
const int _enableMouseInput = 0x0010;
const int _enableQuickEditMode = 0x0040;
const int _enableExtendedFlags = 0x0080;
const int _enableVirtualTerminalInput = 0x0200;
const int _stdInputHandle = 0xFFFFFFF6; // (DWORD)-10

typedef _GetStdHandleC = IntPtr Function(Uint32);
typedef _GetStdHandleD = int Function(int);
typedef _GetConsoleModeC = Int32 Function(IntPtr, Pointer<Uint32>);
typedef _GetConsoleModeD = int Function(int, Pointer<Uint32>);
typedef _SetConsoleModeC = Int32 Function(IntPtr, Uint32);
typedef _SetConsoleModeD = int Function(int, int);

typedef _GetNumberOfConsoleInputEventsC = Int32 Function(
    IntPtr, Pointer<Uint32>);
typedef _GetNumberOfConsoleInputEventsD = int Function(int, Pointer<Uint32>);
typedef _ConsoleInputC = Int32 Function(
    IntPtr, Pointer<Uint8>, Uint32, Pointer<Uint32>);
typedef _ConsoleInputD = int Function(
    int, Pointer<Uint8>, int, Pointer<Uint32>);
typedef _WaitForSingleObjectC = Uint32 Function(IntPtr, Uint32);
typedef _WaitForSingleObjectD = int Function(int, int);

const int _keyEvent = 0x0001;
const int _inputRecordBytes = 20; // sizeof(INPUT_RECORD)
const int _waitTimeout = 0x102; // WAIT_TIMEOUT

int? _savedMode;

/// Whether the console has a character to read within [timeout].
///
/// Sync prompts call it after an `ESC` byte to tell a lone Escape key from the
/// start of a sequence such as `ESC [ A`. The console input handle is also
/// signalled by records `ReadFile` skips (key releases, focus, mouse and
/// resize events). Those would make a wait return at once and the next read
/// block, so the records are peeked: only a key press with a character counts.
/// Records that hold no character are removed, so they cannot signal again.
///
/// Returns true off Windows, and when stdin is not a console (a pipe or a
/// file), where a blocking read returns the next byte or the end of input.
bool windowsInputReady(Duration timeout) {
  if (!Platform.isWindows) return true;
  final k32 = DynamicLibrary.open('kernel32.dll');
  final getStdHandle =
      k32.lookupFunction<_GetStdHandleC, _GetStdHandleD>('GetStdHandle');
  final count = k32.lookupFunction<_GetNumberOfConsoleInputEventsC,
      _GetNumberOfConsoleInputEventsD>('GetNumberOfConsoleInputEvents');
  final peek =
      k32.lookupFunction<_ConsoleInputC, _ConsoleInputD>('PeekConsoleInputW');
  final read =
      k32.lookupFunction<_ConsoleInputC, _ConsoleInputD>('ReadConsoleInputW');
  final wait = k32.lookupFunction<_WaitForSingleObjectC, _WaitForSingleObjectD>(
      'WaitForSingleObject');
  final handle = getStdHandle(_stdInputHandle);
  final n = calloc<Uint32>();
  const batch = 64;
  final records = calloc<Uint8>(_inputRecordBytes * batch);
  try {
    if (count(handle, n) == 0) return true; // not a console
    final clock = Stopwatch()..start();
    while (true) {
      if (count(handle, n) == 0) return true;
      if (n.value > 0) {
        if (peek(handle, records, batch, n) == 0) return true;
        final seen = n.value;
        final bytes = records.asTypedList(_inputRecordBytes * seen);
        for (var i = 0; i < seen; i++) {
          final r = i * _inputRecordBytes;
          final type = bytes[r] | bytes[r + 1] << 8;
          // KEY_EVENT_RECORD: BOOL bKeyDown at +4, WCHAR uChar at +14.
          final down =
              bytes[r + 4] | bytes[r + 5] | bytes[r + 6] | bytes[r + 7];
          final char = bytes[r + 14] | bytes[r + 15] << 8;
          if (type == _keyEvent && down != 0 && char != 0) return true;
        }
        // None of the peeked records is a character: drop them.
        if (read(handle, records, seen, n) == 0) return true;
        continue;
      }
      final left = timeout.inMilliseconds - clock.elapsedMilliseconds;
      if (left <= 0) return false;
      if (wait(handle, left) == _waitTimeout) return false;
    }
  } finally {
    calloc.free(records);
    calloc.free(n);
  }
}

/// Puts the Windows console **input** handle into raw virtual-terminal mode so
/// arrow keys, Esc, Shift+Tab, function keys and the mouse arrive as the escape
/// sequences [TerminalInputDecoder] understands.
///
/// Flipping Dart's `stdin.lineMode`/`echoMode` alone is not enough on Windows:
/// it leaves the console in legacy input mode, where those events never reach
/// the byte stream at all (only plain ASCII does). Enabling
/// `ENABLE_VIRTUAL_TERMINAL_INPUT` is what makes them work; clearing
/// `ENABLE_QUICK_EDIT_MODE` is what lets mouse clicks through instead of being
/// captured as text selection, and clearing `ENABLE_PROCESSED_INPUT` delivers
/// Ctrl+C as a byte (matching Unix raw mode) rather than a console signal.
///
/// No-op on non-Windows platforms or when stdin is not a real console. Call it
/// while entering raw mode; the previous mode is saved for [restoreWindowsVtInput].
void enableWindowsVtInput() {
  if (!Platform.isWindows) return;
  final k32 = DynamicLibrary.open('kernel32.dll');
  final getStdHandle =
      k32.lookupFunction<_GetStdHandleC, _GetStdHandleD>('GetStdHandle');
  final getConsoleMode =
      k32.lookupFunction<_GetConsoleModeC, _GetConsoleModeD>('GetConsoleMode');
  final setConsoleMode =
      k32.lookupFunction<_SetConsoleModeC, _SetConsoleModeD>('SetConsoleMode');

  final handle = getStdHandle(_stdInputHandle);
  final modePtr = calloc<Uint32>();
  try {
    if (getConsoleMode(handle, modePtr) == 0) return; // not a console
    _savedMode ??= modePtr.value;
    final next = (modePtr.value |
            _enableVirtualTerminalInput |
            _enableExtendedFlags |
            _enableMouseInput) &
        ~(_enableQuickEditMode |
            _enableLineInput |
            _enableEchoInput |
            _enableProcessedInput);
    setConsoleMode(handle, next);
  } finally {
    calloc.free(modePtr);
  }
}

/// Restores the console input mode captured by the first [enableWindowsVtInput]
/// call. No-op on non-Windows platforms or if it was never enabled.
void restoreWindowsVtInput() {
  if (!Platform.isWindows) return;
  final saved = _savedMode;
  if (saved == null) return;
  final k32 = DynamicLibrary.open('kernel32.dll');
  final getStdHandle =
      k32.lookupFunction<_GetStdHandleC, _GetStdHandleD>('GetStdHandle');
  final setConsoleMode =
      k32.lookupFunction<_SetConsoleModeC, _SetConsoleModeD>('SetConsoleMode');
  setConsoleMode(getStdHandle(_stdInputHandle), saved);
  _savedMode = null;
}
