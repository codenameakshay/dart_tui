import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

void main() {
  test('command helpers map to expected messages', () async {
    expect(quit(), isA<QuitMsg>());
    expect(interrupt(), isA<InterruptMsg>());
    expect(suspend(), isA<SuspendMsg>());
    expect(clearScreen(), isA<ClearScreenMsg>());
    expect(requestWindowSize(), isA<RequestWindowSizeMsg>());
    expect(requestCursorPosition(), isA<RequestCursorPositionMsg>());
    expect(requestForegroundColor(), isA<RequestForegroundColorMsg>());
    expect(requestBackgroundColor(), isA<RequestBackgroundColorMsg>());
    expect(requestCursorColor(), isA<RequestCursorColorMsg>());
    expect(requestTerminalVersion(), isA<RequestTerminalVersionMsg>());

    expect(await requestCapability('Tc')(), isA<RequestCapabilityMsg>());
    expect(await setClipboard('abc')(), isA<SetClipboardMsg>());
    expect(readClipboard(), isA<ReadClipboardMsg>());
    expect(await setPrimaryClipboard('abc')(), isA<SetPrimaryClipboardMsg>());
    expect(readPrimaryClipboard(), isA<ReadPrimaryClipboardMsg>());
  });

  test('print helpers emit print messages', () async {
    final line = await println('hello')();
    final fmt = await printf('hello %s', ['world'])();
    expect(line, isA<PrintLineMsg>());
    expect((line! as PrintLineMsg).messageBody, 'hello');
    expect(fmt, isA<PrintLineMsg>());
    expect((fmt! as PrintLineMsg).messageBody, 'hello world');
  });
}
