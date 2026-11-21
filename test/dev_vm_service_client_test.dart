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

/// A socket that sends nothing and never answers.
final class _SilentSocket extends _FailingWriteSocket {
  final List<Object?> sent = [];

  @override
  void add(Object? data) => sent.add(data);
}

void main() {
  test('a call with no reply times out, and a late reply is ignored', () async {
    final socket = _SilentSocket();
    final client = VmServiceClient(
      socket,
      timeout: const Duration(milliseconds: 20),
    );

    await expectLater(
      client.call('reloadSources'),
      throwsA(isA<TimeoutException>()),
    );
    final id = (jsonDecode(socket.sent.single as String) as Map)['id'];
    socket._events.add(jsonEncode(
        {'jsonrpc': '2.0', 'id': id, 'result': <String, Object?>{}}));
    final next = client.call('getVM');
    final nextId = (jsonDecode(socket.sent.last as String) as Map)['id'];
    socket._events.add(jsonEncode(
        {'jsonrpc': '2.0', 'id': nextId, 'result': 'still connected'}));
    expect(await next, 'still connected');
    await client.close();
  });

  for (final outcome in ['reply', 'rpc error', 'close', 'write error']) {
    test('$outcome cancels the call timeout', () async {
      final socket =
          outcome == 'write error' ? _FailingWriteSocket() : _SilentSocket();
      final client = VmServiceClient(socket);
      final timers = <Timer>[];
      final reply = runZoned(
        () => client.call('getVM'),
        zoneSpecification: ZoneSpecification(
          createTimer: (self, parent, zone, duration, callback) {
            final timer = parent.createTimer(zone, duration, callback);
            timers.add(timer);
            return timer;
          },
        ),
      );
      final expectation = outcome == 'reply'
          ? expectLater(reply, completion('ok'))
          : expectLater(
              reply,
              throwsA(switch (outcome) {
                'rpc error' => isA<RpcException>(),
                'close' => isA<ServiceClosedException>(),
                _ => isA<StateError>(),
              }),
            );
      if (socket is _SilentSocket) {
        if (outcome == 'close') {
          await client.close();
        } else {
          final id = (jsonDecode(socket.sent.single as String) as Map)['id'];
          socket._events.add(jsonEncode({
            'jsonrpc': '2.0',
            'id': id,
            if (outcome == 'reply') 'result': 'ok',
            if (outcome == 'rpc error')
              'error': {'code': -32601, 'message': 'not found'},
          }));
        }
      }
      await expectation;
      expect(timers, isNotEmpty);
      expect(timers.every((timer) => !timer.isActive), isTrue);
      if (outcome != 'close') await client.close();
    });
  }

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
