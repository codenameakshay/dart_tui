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

int? _savedMode;

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
