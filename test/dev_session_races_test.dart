import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_tui/src/dev/dev.dart';
import 'package:test/test.dart';

final class _FakeProcess implements Process {
  final Completer<int> _exit = Completer<int>();
  final List<ProcessSignal> signals = [];

  @override
  int get pid => 1;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    signals.add(signal);
    exit(-signal.signalNumber);
    return true;
  }

  void exit(int code) {
    if (!_exit.isCompleted) _exit.complete(code);
  }

  @override
  IOSink get stdin => throw UnsupportedError('stdin is not used by DevSession');

  @override
  Stream<List<int>> get stdout => const Stream.empty();

  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeVmService {
  _FakeVmService._(
    this.server,
    this.generation,
    this.rejectReload,
    this.holdReload,
    this.holdGetVm,
  );

  static Future<_FakeVmService> start(
    int generation, {
    bool rejectReload = false,
    bool holdReload = false,
    bool holdGetVm = false,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = _FakeVmService._(
        server, generation, rejectReload, holdReload, holdGetVm);
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      fake.connections++;
      socket.listen((data) async {
        final message = jsonDecode(data as String) as Map<String, Object?>;
        final method = message['method'] as String;
        final params = message['params'] as Map<String, Object?>;
        fake.methods.add(method);
        Object result;
        switch (method) {
          case 'getVM':
            fake.getVmCalls++;
            if (!fake.getVmRequested.isCompleted) {
              fake.getVmRequested.complete();
            }
            if (fake.holdGetVm) await fake.releaseGetVm.future;
            result = {
              'isolates': [
                {'id': 'isolates/main', 'name': 'main'},
              ],
            };
          case 'reloadSources':
            fake.reloadCalls++;
            if (!fake.firstReloadRequested.isCompleted) {
              fake.firstReloadRequested.complete();
            }
            if (fake.holdReload) await fake.releaseReload.future;
            result = fake.rejectReload
                ? {
                    'success': false,
                    'notices': [
                      {'message': 'Class shape changed'},
                    ],
                  }
                : {'success': true};
          case 'ext.dart_tui.devStatus':
            fake.bannerTexts.add(params['text'] as String? ?? '');
            result = <String, Object?>{};
          case 'ext.dart_tui.reassemble':
            result = <String, Object?>{};
          default:
            result = <String, Object?>{};
        }
        if (socket.readyState == WebSocket.open) {
          socket.add(jsonEncode({
            'jsonrpc': '2.0',
            'id': message['id'],
            'result': result,
          }));
        }
      }, onDone: () {
        fake.closedConnections++;
        if (!fake.connectionClosed.isCompleted) {
          fake.connectionClosed.complete();
        }
      });
    });
    if (!holdGetVm) fake.releaseGetVm.complete();
    if (!holdReload) fake.releaseReload.complete();
    return fake;
  }

  final HttpServer server;
  final int generation;
  final bool rejectReload;
  final bool holdReload;
  final bool holdGetVm;
  final Completer<void> firstReloadRequested = Completer<void>();
  final Completer<void> releaseReload = Completer<void>();
  final Completer<void> getVmRequested = Completer<void>();
  final Completer<void> releaseGetVm = Completer<void>();
  final Completer<void> connectionClosed = Completer<void>();
  final List<String> methods = [];
  final List<String> bannerTexts = [];
  int connections = 0;
  int getVmCalls = 0;
  int reloadCalls = 0;
  int closedConnections = 0;

  Uri get uri => Uri.parse('http://127.0.0.1:${server.port}/token=/');

  Future<void> close() => server.close(force: true);
}

void main() {
  test('restart banner and reload share one connection for the new child',
      () async {
    final root = Directory.systemTemp.createTempSync('dart_tui_dev_race');
    addTearDown(() => root.deleteSync(recursive: true));
    final lib = Directory('${root.path}/lib')..createSync();
    Directory('${root.path}/bin').createSync();
    final source = File('${lib.path}/source.dart')..writeAsStringSync('one');
    final processes = <_FakeProcess>[];
    final services = <_FakeVmService>[];

    Future<Process> startChild(
      String _,
      List<String> args, {
      required String workingDirectory,
      required ProcessStartMode mode,
    }) async {
      final generation = processes.length + 1;
      final process = _FakeProcess();
      final service = await _FakeVmService.start(
        generation,
        rejectReload: generation == 1,
        holdGetVm: generation == 2,
      );
      processes.add(process);
      services.add(service);
      final infoArg =
          args.singleWhere((arg) => arg.startsWith('--write-service-info='));
      final info = File.fromUri(Uri.parse(infoArg.split('=').last));
      info.writeAsStringSync(jsonEncode({'uri': service.uri.toString()}));
      return process;
    }

    final session = DevSession(
      root: root.path,
      file: 'bin/app.dart',
      debounce: const Duration(milliseconds: 15),
      processStarter: startChild,
    );
    final running = session.run();
    addTearDown(() async {
      if (processes.isNotEmpty) processes.last.exit(0);
      await running.timeout(const Duration(seconds: 5));
      for (final service in services) {
        await service.close();
      }
    });

    source.writeAsStringSync('two');
    await _waitUntil(() => processes.length == 2);
    final firstRestart = services.first;
    await firstRestart.getVmRequested.future
        .timeout(const Duration(seconds: 5));
    await _waitUntil(() => firstRestart.methods.contains('reloadSources'));

    final nextChild = services.last;
    await nextChild.getVmRequested.future.timeout(const Duration(seconds: 5));
    expect(nextChild.connections, 1);

    source.writeAsStringSync('three');
    await Future<void>.delayed(const Duration(milliseconds: 80));
    nextChild.releaseGetVm.complete();

    await _waitUntil(() =>
        nextChild.bannerTexts.contains('restarted: Class shape changed') &&
        nextChild.methods.contains('reloadSources'));
    expect(nextChild.connections, 1);
    expect(nextChild.getVmCalls, 1);
    expect(firstRestart.bannerTexts, isEmpty);

    processes.last.exit(0);
    expect(await running.timeout(const Duration(seconds: 5)), 0);
  });

  test('a save during a pending reload causes one follow-up reload', () async {
    final root =
        Directory.systemTemp.createTempSync('dart_tui_dev_reload_race');
    addTearDown(() => root.deleteSync(recursive: true));
    final lib = Directory('${root.path}/lib')..createSync();
    Directory('${root.path}/bin').createSync();
    final source = File('${lib.path}/source.dart')..writeAsStringSync('one');
    final child = _FakeProcess();
    final serviceReady = Completer<_FakeVmService>();
    late _FakeVmService service;

    Future<Process> startChild(
      String _,
      List<String> args, {
      required String workingDirectory,
      required ProcessStartMode mode,
    }) async {
      service = await _FakeVmService.start(
        1,
        holdReload: true,
      );
      serviceReady.complete(service);
      final infoArg = args.singleWhere(
        (arg) => arg.startsWith('--write-service-info='),
      );
      File.fromUri(Uri.parse(infoArg.split('=').last))
          .writeAsStringSync(jsonEncode({'uri': service.uri.toString()}));
      return child;
    }

    final session = DevSession(
      root: root.path,
      file: 'bin/app.dart',
      debounce: const Duration(milliseconds: 15),
      processStarter: startChild,
    );
    final running = session.run();
    addTearDown(() async {
      child.exit(0);
      await running.timeout(const Duration(seconds: 5));
      if (serviceReady.isCompleted) await service.close();
    });

    source.writeAsStringSync('two');
    await serviceReady.future.timeout(const Duration(seconds: 5));
    await service.firstReloadRequested.future.timeout(
      const Duration(seconds: 5),
    );
    source.writeAsStringSync('three');
    await Future<void>.delayed(const Duration(milliseconds: 80));
    service.releaseReload.complete();

    await _waitUntil(() => service.reloadCalls == 2);
    expect(service.connections, 1);
    child.exit(0);
    expect(await running.timeout(const Duration(seconds: 5)), 0);
  });

  test('a late VM handshake closes instead of attaching to a stopped child',
      () async {
    final root = Directory.systemTemp.createTempSync('dart_tui_dev_stale');
    addTearDown(() => root.deleteSync(recursive: true));
    final lib = Directory('${root.path}/lib')..createSync();
    Directory('${root.path}/bin').createSync();
    final source = File('${lib.path}/source.dart')..writeAsStringSync('one');
    final serviceReady = Completer<_FakeVmService>();
    final signals = StreamController<ProcessSignal>.broadcast();
    final child = _FakeProcess();

    Future<Process> startChild(
      String _,
      List<String> args, {
      required String workingDirectory,
      required ProcessStartMode mode,
    }) async {
      final service = await _FakeVmService.start(1, holdGetVm: true);
      serviceReady.complete(service);
      final infoArg = args.singleWhere(
        (arg) => arg.startsWith('--write-service-info='),
      );
      File.fromUri(Uri.parse(infoArg.split('=').last))
          .writeAsStringSync(jsonEncode({'uri': service.uri.toString()}));
      return child;
    }

    final session = DevSession(
      root: root.path,
      file: 'bin/app.dart',
      debounce: const Duration(milliseconds: 15),
      processStarter: startChild,
      signalStream: (signal) =>
          signals.stream.where((actual) => actual == signal),
    );
    final running = session.run();
    addTearDown(() async {
      child.exit(0);
      await running.timeout(const Duration(seconds: 5));
      if (serviceReady.isCompleted) {
        final service = await serviceReady.future;
        if (!service.releaseGetVm.isCompleted) service.releaseGetVm.complete();
        await service.close();
      }
      await signals.close();
    });

    source.writeAsStringSync('two');
    final service = await serviceReady.future.timeout(
      const Duration(seconds: 5),
    );
    await service.getVmRequested.future.timeout(const Duration(seconds: 5));
    final signalObserved = Completer<void>();
    signals.stream.listen((signal) {
      if (signal == ProcessSignal.sighup && !signalObserved.isCompleted) {
        signalObserved.complete();
      }
    });
    signals.add(ProcessSignal.sighup);
    await signalObserved.future;
    expect(child.signals, [ProcessSignal.sigterm]);
    expect(await running.timeout(const Duration(seconds: 5)), 143);

    service.releaseGetVm.complete();
    await service.connectionClosed.future.timeout(const Duration(seconds: 5));
    expect(service.closedConnections, 1);
    expect(service.methods, contains('getVM'));
    expect(service.methods, isNot(contains('reloadSources')));
  });

  test(
    'a signal during child startup is forwarded to that child',
    () async {
      final root = Directory.systemTemp.createTempSync('dart_tui_dev_signal');
      addTearDown(() => root.deleteSync(recursive: true));
      Directory('${root.path}/lib').createSync();
      Directory('${root.path}/bin').createSync();
      final starting = Completer<Process>();
      final started = Completer<void>();
      final signals = StreamController<ProcessSignal>.broadcast();
      final child = _FakeProcess();
      final session = DevSession(
        root: root.path,
        file: 'bin/app.dart',
        processStarter: (_, __, {required workingDirectory, required mode}) {
          started.complete();
          return starting.future;
        },
        signalStream: (signal) =>
            signals.stream.where((actual) => actual == signal),
      );
      final running = session.run();
      addTearDown(() async {
        if (!starting.isCompleted) starting.complete(child);
        child.exit(0);
        await running.timeout(const Duration(seconds: 5));
        await signals.close();
      });
      await started.future;
      final signalObserved = Completer<void>();
      signals.stream.listen((signal) {
        if (signal == ProcessSignal.sighup && !signalObserved.isCompleted) {
          signalObserved.complete();
        }
      });

      signals.add(ProcessSignal.sighup);
      await signalObserved.future;
      expect(child.signals, isEmpty);
      starting.complete(child);
      await _waitUntil(() => child.signals.isNotEmpty);
      expect(child.signals, [ProcessSignal.sigterm]);
      child.exit(0);
      expect(await running.timeout(const Duration(seconds: 5)), 143);
    },
    skip: Platform.isWindows ? 'SIGHUP is not supported on Windows' : false,
  );
}

Future<void> _waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue);
}
