import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

void main() {
  test('Go-style command aliases map to expected messages', () async {
    expect(Quit(), isA<QuitMsg>());
    expect(Interrupt(), isA<InterruptMsg>());
    expect(Suspend(), isA<SuspendMsg>());
    expect(ClearScreen(), isA<ClearScreenMsg>());
    expect(RequestWindowSize(), isA<RequestWindowSizeMsg>());
    expect(RequestCursorPosition(), isA<RequestCursorPositionMsg>());
    expect(RequestForegroundColor(), isA<RequestForegroundColorMsg>());
    expect(RequestBackgroundColor(), isA<RequestBackgroundColorMsg>());
    expect(RequestCursorColor(), isA<RequestCursorColorMsg>());
    expect(RequestTerminalVersion(), isA<RequestTerminalVersionMsg>());

    expect(await RequestCapability('Tc')(), isA<RequestCapabilityMsg>());
    expect(await SetClipboard('abc')(), isA<SetClipboardMsg>());
    expect(ReadClipboard(), isA<ReadClipboardMsg>());
    expect(await SetPrimaryClipboard('abc')(), isA<SetPrimaryClipboardMsg>());
    expect(ReadPrimaryClipboard(), isA<ReadPrimaryClipboardMsg>());
  });

  test('Print aliases emit print message', () async {
    final line = await Println('hello')();
    final fmt = await Printf('hello %s', ['world'])();
    expect(line, isA<PrintLineMsg>());
    expect((line! as PrintLineMsg).messageBody, 'hello');
    expect(fmt, isA<PrintLineMsg>());
    expect((fmt! as PrintLineMsg).messageBody, 'hello world');
  });
}
