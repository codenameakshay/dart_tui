import 'package:dart_tui/dart_tui.dart';
import 'package:test/test.dart';

void main() {
  test('execProcess with inheritStdio=false delivers exit code via onExit', () async {
    // Note: Full integration test requires a running Program. This tests the
    // ExecMsg object is constructed correctly.
    final cmd = execProcess(
      'echo',
      ['hello'],
      inheritStdio: false,
      onExit: (exitCode) {
        expect(exitCode, 0);
        return null;
      },
    );
    final msg = await cmd();
    expect(msg, isA<ExecMsg>());
    final execMsg = msg as ExecMsg;
    expect(execMsg.cmd, 'echo');
    expect(execMsg.args, ['hello']);
    expect(execMsg.inheritStdio, false);
    expect(execMsg.onExit, isNotNull);
  });

  test('execProcess defaults to inheritStdio=true', () async {
    final cmd = execProcess('echo', ['test']);
    final msg = await cmd();
    expect(msg, isA<ExecMsg>());
    expect((msg as ExecMsg).inheritStdio, true);
  });
}
