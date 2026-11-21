import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_tui/src/dev/vm_service_client.dart';
import 'package:test/test.dart';

final class _FailingWriteSocket implements WebSocket {
  final StreamController<Object?> _events = StreamController<Object?>();

  @override
  StreamSubscription<dynamic> listen(
    void Function(dynamic)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      _events.stream.listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );

  @override
  void add(Object? data) => throw StateError('write failed');

  @override
  Future<void> close([int? code, String? reason]) => _events.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('a synchronous socket write failure completes and removes the request',
      () async {
    final client = VmServiceClient(_FailingWriteSocket());

    await expectLater(client.call('writeFails'), throwsA(isA<StateError>()));
    await expectLater(
        client.call('writeFailsAgain'), throwsA(isA<StateError>()));
  });

  test('classifies compiler diagnostics when the source path has spaces',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      socket.listen((data) {
        final request = jsonDecode(data as String) as Map<String, Object?>;
        socket.add(jsonEncode({
          'jsonrpc': '2.0',
          'id': request['id'],
          'result': {
            'success': false,
            'notices': [
              {
                'message': 'lib/my app.dart:8:18: Error: Expected a name.',
              },
            ],
          },
        }));
      });
    });
    final client = await VmServiceClient.connect(
      Uri.parse('http://127.0.0.1:${server.port}/'),
    );
    addTearDown(client.close);
    addTearDown(() => server.close(force: true));

    expect(
      await client.reloadSources('isolates/1'),
      isA<ReloadCompileError>().having(
        (result) => result.message,
        'message',
        'lib/my app.dart:8:18: Error: Expected a name.',
      ),
    );
  });
}
