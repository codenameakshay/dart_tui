// `dart_tui dev`: the VM service JSON-RPC client against a fake server, and
// the pure parts of the command (arguments, watch filter, debounce).
// tool/pty_dev_test.py runs the whole flow in a PTY (POSIX only).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_tui/cli.dart';
import 'package:dart_tui/src/create/create.dart';
import 'package:dart_tui/src/dev/dev.dart';
import 'package:dart_tui/src/dev/vm_service_client.dart';
import 'package:dart_tui/testing.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// A fake VM service: answers each request with [reply] (a result or an
/// `{'error': ...}` map), or drops the connection when it returns null.
final class _FakeService {
  _FakeService._(this._server);

  static Future<_FakeService> start(
    Object? Function(String method, Map<String, Object?> params)? reply,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = _FakeService._(server);
    server.listen((request) async {
      expect(request.uri.path, '/token=/ws');
      final socket = await WebSocketTransformer.upgrade(request);
      socket.listen((data) {
        final message = jsonDecode(data as String) as Map<String, Object?>;
        final method = message['method'] as String;
        final params = message['params'] as Map<String, Object?>;
        fake.requests.add(method);
        final answer = reply!(method, params);
        if (answer == null) {
          unawaited(socket.close());
          return;
        }
        // An event first: the client must skip messages without an id.
        socket.add(jsonEncode({'jsonrpc': '2.0', 'method': 'streamNotify'}));
        socket.add(jsonEncode({
          'jsonrpc': '2.0',
          'id': message['id'],
          if (answer case {'error': final Object error})
            'error': error
          else
            'result': answer,
        }));
      });
    });
    return fake;
  }

  final HttpServer _server;
  final List<String> requests = [];

  Uri get uri => Uri.parse('http://127.0.0.1:${_server.port}/token=/');

  Future<void> close() => _server.close(force: true);
}

const _vm = {
  'type': 'VM',
  'isolates': [
    {'id': 'isolates/1', 'name': 'vm-service', 'isSystemIsolate': true},
    {'id': 'isolates/2', 'name': 'helper'},
    {'id': 'isolates/3', 'name': 'main'},
  ],
};

Map<String, Object?> _failed(Map<String, Object?> notice) => {
      'type': 'ReloadReport',
      'success': false,
      'notices': [
        {'type': 'ReasonForCancelling', ...notice},
      ],
    };

void main() {
  group('VmServiceClient', () {
    Future<(VmServiceClient, _FakeService)> connect(
      Object? Function(String method, Map<String, Object?> params) reply,
    ) async {
      final fake = await _FakeService.start(reply);
      addTearDown(fake.close);
      final client = await VmServiceClient.connect(fake.uri);
      addTearDown(client.close);
      return (client, fake);
    }

    test('finds the main isolate and reloads it', () async {
      String? reloaded;
      final (client, fake) = await connect((method, params) {
        if (method == 'getVM') return _vm;
        reloaded = params['isolateId'] as String?;
        return {'type': 'ReloadReport', 'success': true};
      });
      final isolate = await client.mainIsolateId();
      expect(isolate, 'isolates/3');
      expect(await client.reloadSources(isolate!), isA<ReloadSuccess>());
      expect(reloaded, 'isolates/3');
      expect(fake.requests, ['getVM', 'reloadSources']);
    });

    test('without a main isolate, takes the first non-system one', () async {
      final (client, _) = await connect((_, __) => {
            'isolates': [
              {
                'id': 'isolates/1',
                'name': 'vm-service',
                'isSystemIsolate': true
              },
              {'id': 'isolates/2', 'name': 'app'},
            ],
          });
      expect(await client.mainIsolateId(), 'isolates/2');
    });

    test('a compile error, coloured by the compiler, is not a rejection',
        () async {
      final (client, _) = await connect((_, __) => _failed({
            'message': "bin/app.dart:8:18: \x1b[31mError: '+' is not a prefix "
                "operator.\nTry removing '+'.\x1b[39;49m",
          }));
      final result = await client.reloadSources('isolates/3');
      expect(
        result,
        isA<ReloadCompileError>().having(
            (r) => r.message,
            'message',
            "bin/app.dart:8:18: Error: '+' is not a prefix operator.\n"
                "Try removing '+'."),
      );
    });

    test('a class shape change is a rejection with a short reason', () async {
      final (client, _) = await connect((_, __) => _failed({
            'class': {'type': '@Class', 'name': 'Mode'},
            'message': 'Enum class cannot be redefined to be a non-enum '
                "class: Library:'file:///tmp/app/bin/app.dart' Class: Mode",
          }));
      expect(
        await client.reloadSources('isolates/3'),
        isA<ReloadRejected>().having((r) => r.reason, 'reason',
            'Enum class cannot be redefined to be a non-enum class (Mode)'),
      );
    });

    test('an error reply throws RpcException', () async {
      final (client, _) = await connect((_, __) => {
            'error': {'code': -32601, 'message': 'Method not found'},
          });
      await expectLater(
        client.callExtension('ext.dart_tui.reassemble', 'isolates/3'),
        throwsA(isA<RpcException>()
            .having((e) => e.methodNotFound, 'methodNotFound', isTrue)),
      );
    });

    test('a dropped connection fails pending and later calls', () async {
      final (client, _) = await connect((_, __) => null);
      await expectLater(
        client.reloadSources('isolates/3'),
        throwsA(isA<ServiceClosedException>()),
      );
      await client.done;
      expect(client.isClosed, isTrue);
      await expectLater(
        client.call('getVM'),
        throwsA(isA<ServiceClosedException>()),
      );
    });

    test('connecting to a closed port throws', () async {
      final fake = await _FakeService.start(null);
      final uri = fake.uri;
      await fake.close();
      await expectLater(
          VmServiceClient.connect(uri), throwsA(isA<SocketException>()));
    });
  });

  test('webSocketUri appends ws and keeps the auth token', () {
    expect(webSocketUri(Uri.parse('http://127.0.0.1:5/abc=/')).toString(),
        'ws://127.0.0.1:5/abc=/ws');
    expect(webSocketUri(Uri.parse('http://127.0.0.1:5')).toString(),
        'ws://127.0.0.1:5/ws');
    expect(webSocketUri(Uri.parse('https://h/t')).scheme, 'wss');
  });

  test('shortReason drops the library URI', () {
    expect(
      shortReason("Const class cannot remove fields: Library:'file:///a.dart' "
          'Class: Pt\nmore'),
      'Const class cannot remove fields (Pt)',
    );
    expect(shortReason("Bad thing: Library:'file:///a.dart'"), 'Bad thing');
    expect(shortReason('plain\nsecond'), 'plain');
  });

  test('firstErrorLine finds the error and drops the word Error', () {
    expect(
      firstErrorLine("lib/a.dart:1:2: Warning: w\nlib/a.dart:3:4: Error: "
          "Expected ';'.\nmore"),
      "lib/a.dart:3:4: Expected ';'.",
    );
    expect(firstErrorLine('no location'), 'no location');
  });

  test('shellExitCode maps a signal to 128 + N', () {
    expect(shellExitCode(0), 0);
    expect(shellExitCode(3), 3);
    expect(shellExitCode(-15), 143);
  });

  group('watch filter', () {
    test('does not descend into hidden directories', () {
      expect(shouldWatchDirectory(p.join('lib', 'src')), isTrue);
      expect(shouldWatchDirectory(p.join('lib', '.generated')), isFalse);
    });

    test('takes .dart files', () {
      expect(isWatchedChange(p.join('lib', 'src', 'app.dart')), isTrue);
      expect(isWatchedChange(p.join('bin', 'app.dart')), isTrue);
      expect(isWatchedChange(p.join('..', 'example', 'a.dart')), isTrue);
    });

    test('skips other files, editor temp files and hidden directories', () {
      expect(isWatchedChange(p.join('lib', 'app.dart~')), isFalse);
      expect(isWatchedChange(p.join('lib', 'app.dart.swp')), isFalse);
      expect(isWatchedChange(p.join('lib', '.app.dart.swp')), isFalse);
      expect(isWatchedChange(p.join('lib', '.#app.dart')), isFalse);
      expect(isWatchedChange(p.join('lib', 'README.md')), isFalse);
      expect(isWatchedChange(p.join('.dart_tool', 'x', 'a.dart')), isFalse);
    });
  });

  group('Debouncer', () {
    test('runs once after the calls stop', () async {
      var runs = 0;
      final debounce =
          Debouncer(const Duration(milliseconds: 40), () => runs++);
      for (var i = 0; i < 5; i++) {
        debounce();
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(runs, 0);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(runs, 1);
      debounce();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(runs, 2);
    });

    test('cancel drops a pending call', () async {
      var runs = 0;
      Debouncer(const Duration(milliseconds: 20), () => runs++)
        ..call()
        ..cancel();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(runs, 0);
    });
  });

  group('arguments', () {
    test('splits the file from the app arguments after --', () {
      List<List<String>> split(List<String> arguments, List<String> rest) {
        final (:files, :appArgs) = splitDevArgs(arguments, rest);
        return [files, appArgs];
      }

      expect(
          split(['bin/a.dart', '--', '-x', 'y'], ['bin/a.dart', '-x', 'y']), [
        ['bin/a.dart'],
        ['-x', 'y']
      ]);
      expect(split(['--', 'bin/a.dart'], ['bin/a.dart']), [
        <String>[],
        ['bin/a.dart'],
      ]);
      expect(split([], []), [<String>[], <String>[]]);
    });

    test('defaults to bin/<package>.dart', () {
      final dir = Directory.systemTemp.createTempSync('dart_tui_dev');
      addTearDown(() => dir.deleteSync(recursive: true));
      expect(defaultDevFile(dir.path), isNull);
      File(p.join(dir.path, 'pubspec.yaml'))
          .writeAsStringSync('# app\nname: my_app\nversion: 1.0.0\n');
      expect(defaultDevFile(dir.path), p.join('bin', 'my_app.dart'));
      File(p.join(dir.path, 'pubspec.yaml'))
          .writeAsStringSync('name: "quoted-app"\nversion: 1.0.0\n');
      expect(defaultDevFile(dir.path), p.join('bin', 'quoted-app.dart'));
    });
  });

  group('dart_tui dev', () {
    late CaptureSink out;
    late CaptureSink err;
    late Directory dir;
    late Directory previous;

    setUp(() {
      out = CaptureSink();
      err = CaptureSink();
      dir = Directory.systemTemp.createTempSync('dart_tui_dev');
      previous = Directory.current;
      Directory.current = dir;
      addTearDown(() {
        Directory.current = previous;
        dir.deleteSync(recursive: true);
      });
    });

    Future<int?> run(List<String> args) async {
      final runner = DartTuiRunner(
        logger: Logger(stdout: out, stderr: err),
      );
      try {
        return await runner.run(args);
      } on UsageException catch (e) {
        err.write(e.message);
        return 64;
      }
    }

    test('without a file or a pubspec, says what to give', () async {
      expect(await run(['dev']), 64);
      expect(err.text, contains('no pubspec.yaml'));
    });

    test('a missing file exits 66', () async {
      expect(await run(['dev', 'bin/nope.dart']), 66);
      expect(err.text, contains('does not exist'));
    });

    test('two files before -- is a usage error', () async {
      expect(await run(['dev', 'a.dart', 'b.dart']), 64);
      expect(err.text, contains('Give one file, not 2'));
    });
  });
}
