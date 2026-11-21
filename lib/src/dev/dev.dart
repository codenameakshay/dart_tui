/// `dart_tui dev`: runs an app, reloads its code on save and redraws it.
///
/// Internal. Not exported.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../cli.dart';
import 'vm_service_client.dart';

/// `dart_tui dev [file] [-- app arguments]`.
class DevCommand extends CliCommand<int> {
  @override
  String get name => 'dev';
  @override
  String get description => 'Run an app and reload its code when you save.\n\n'
      'The app keeps its model: view() and update() changes show on the next '
      'frame, and init() does not run again. When the VM cannot apply a '
      'change (a class that changes shape, for example), the app restarts. '
      'A compile error shows a banner; the app keeps running.';
  @override
  String get invocation => 'dart_tui dev [file] [-- app arguments]';
  @override
  List<String> get examples => [
        'dart_tui dev',
        'dart_tui dev example/counter.dart',
        'dart_tui dev -- --name Ada',
      ];

  @override
  Future<int> run() async {
    final args = argResults!;
    final (:files, :appArgs) = splitDevArgs(args.arguments, args.rest);
    if (files.length > 1) {
      usageException('Give one file, not ${files.length}. Put the app '
          'arguments after --.');
    }
    final root = Directory.current.path;
    final target = files.firstOrNull ?? defaultDevFile(root);
    if (target == null) {
      usageException('No file given, and no pubspec.yaml here to find '
          'bin/<package>.dart in. Run it in a package, or give the file: '
          'dart_tui dev bin/app.dart');
    }
    if (!File(target).existsSync()) {
      logger.err('$target does not exist.');
      return 66;
    }
    return DevSession(root: root, file: target, appArgs: appArgs).run();
  }
}

/// Splits the `dev` command's positional arguments into the files before
/// `--` and the app's own arguments after it.
({List<String> files, List<String> appArgs}) splitDevArgs(
  List<String> arguments,
  List<String> rest,
) {
  final dash = arguments.indexOf('--');
  final appArgs = dash < 0 ? const <String>[] : arguments.sublist(dash + 1);
  return (
    files: rest.sublist(0, rest.length - appArgs.length),
    appArgs: appArgs
  );
}

/// `bin/<package>.dart` for the package in [root], or null without a
/// pubspec.yaml.
String? defaultDevFile(String root) {
  final pubspec = File(p.join(root, 'pubspec.yaml'));
  if (!pubspec.existsSync()) return null;
  final name = RegExp(r'''^name:\s*(['"]?)([A-Za-z0-9_-]+)\1\s*(?:#.*)?$''',
          multiLine: true)
      .firstMatch(pubspec.readAsStringSync())?[2];
  return name == null ? null : p.join('bin', '$name.dart');
}

/// Whether a change to [path] (relative to the project) should reload: a
/// `.dart` file outside hidden directories such as `.dart_tool`.
bool isWatchedChange(String path) =>
    path.endsWith('.dart') &&
    !p
        .split(path)
        .any((part) => part.startsWith('.') && part != '.' && part != '..');

/// Whether a directory at [path] (relative to the project) holds sources:
/// no part of it is hidden.
bool isWatchedDirectory(String path) => !p
    .split(path)
    .any((part) => part.startsWith('.') && part != '.' && part != '..');

/// Whether the Linux watcher should descend into [path].
bool shouldWatchDirectory(String path) => !p.basename(path).startsWith('.');

/// Calls an action once no call has come for [delay].
final class Debouncer {
  Debouncer(this.delay, this.action);

  final Duration delay;
  final void Function() action;
  Timer? _timer;

  void call() {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() => _timer?.cancel();
}

/// The first `file:line:col: Error: ...` line of compiler output, without
/// the `Error: ` word: `bin/app.dart:3:9: Expected ';' after this.`
String firstErrorLine(String message) {
  final lines = message.split('\n');
  return lines
      .firstWhere((line) => line.contains(': Error: '),
          orElse: () => lines.first)
      .replaceFirst(': Error: ', ': ');
}

/// The exit code a shell would report for a child's [code] (`-N` = signal N).
int shellExitCode(int code) => code < 0 ? 128 - code : code;

typedef DevProcessStarter = Future<Process> Function(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
  required ProcessStartMode mode,
});

/// One `dart_tui dev` run: the child app, the file watchers and the reloads.
final class DevSession {
  DevSession({
    required this.root,
    required this.file,
    this.appArgs = const [],
    this.debounce = const Duration(milliseconds: 100),
    DevProcessStarter? processStarter,
    Future<VmServiceClient> Function(Uri)? vmServiceConnector,
    Stream<ProcessSignal> Function(ProcessSignal)? signalStream,
  })  : _processStarter = processStarter ?? _startProcess,
        _vmServiceConnector = vmServiceConnector ?? VmServiceClient.connect,
        _signalStream = signalStream ?? _watchSignal;

  final String root;
  final String file;
  final List<String> appArgs;
  final Duration debounce;
  final DevProcessStarter _processStarter;
  final Future<VmServiceClient> Function(Uri) _vmServiceConnector;
  final Stream<ProcessSignal> Function(ProcessSignal) _signalStream;

  late final Directory _temp;
  late final String _logPath =
      p.join(root, '.dart_tool', 'dart_tui', 'dev.log');
  final List<StreamSubscription<Object?>> _subs = [];
  final Set<String> _watchedDirs = {};
  final Map<String, StreamSubscription<FileSystemEvent>> _dirWatchSubs = {};
  late final Debouncer _changes = Debouncer(debounce, _reloadAll);

  Process? _child;
  int _generation = 0;
  Future<Uri?>? _serviceUri;
  Future<(VmServiceClient, String)?>? _connecting;
  VmServiceClient? _client;
  String? _isolateId;
  bool _reloading = false;
  bool _again = false;
  String? _restartReason;
  bool _stopping = false;
  int _bannerRevision = 0;

  /// Runs the app until it exits and returns its exit code.
  Future<int> run() async {
    _temp = Directory.systemTemp.createTempSync('dart_tui_dev');
    // Ctrl+C reaches the whole foreground process group. The app decides
    // what it means; this process exits when the app does.
    _subs.add(_signalStream(ProcessSignal.sigint).listen((_) {}));
    if (!Platform.isWindows) {
      // A Program quits on SIGTERM and restores the terminal; on SIGHUP
      // it would just die, so the app gets SIGTERM for both.
      for (final signal in [ProcessSignal.sigterm, ProcessSignal.sighup]) {
        _subs.add(_signalStream(signal).listen((_) => _stop()));
      }
    }
    try {
      _watchSources();
      String? banner;
      while (true) {
        final child = await _start();
        if (_stopping) _kill();
        if (banner != null) unawaited(_showBanner(banner, _generation));
        final code = await child.exitCode;
        final reason = _restartReason;
        if (reason == null || _stopping) return shellExitCode(code);
        _restartReason = null;
        banner = 'restarted: $reason';
      }
    } finally {
      _stopping = true;
      _generation++;
      final child = _child;
      if (child != null) await child.exitCode;
      _changes.cancel();
      for (final sub in _subs) {
        await sub.cancel();
      }
      await _client?.close();
      try {
        _temp.deleteSync(recursive: true);
      } on FileSystemException {
        // Best effort.
      }
    }
  }

  static String get _dart {
    final exe = Platform.resolvedExecutable;
    // An AOT-compiled dart_tui is not the dart tool.
    return p.basenameWithoutExtension(exe) == 'dart' ? exe : 'dart';
  }

  static Future<Process> _startProcess(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
    required ProcessStartMode mode,
  }) =>
      Process.start(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        mode: mode,
      );

  Future<Process> _start() async {
    final generation = ++_generation;
    final info = File(p.join(_temp.path, 'service-$generation.json'));
    final oldClient = _client;
    _client = null;
    _isolateId = null;
    _connecting = null;
    final serviceUri = Completer<Uri?>();
    _serviceUri = serviceUri.future;
    try {
      await oldClient?.close();
      final child = _child = await _processStarter(
        _dart,
        [
          'run',
          '--enable-vm-service=0',
          '--no-dds',
          '-DSILENT_VM_SERVICE=true',
          '--write-service-info=${Uri.file(info.path)}',
          file,
          ...appArgs,
        ],
        workingDirectory: root,
        // The app owns the terminal; this process never reads stdin.
        mode: ProcessStartMode.inheritStdio,
      );
      serviceUri.complete(_readServiceInfo(info, child));
      return child;
    } on Object {
      serviceUri.complete(null);
      rethrow;
    }
  }

  /// Waits for the child to write its service URI; null if it exits first.
  Future<Uri?> _readServiceInfo(File info, Process child) async {
    var exited = false;
    unawaited(child.exitCode.then((_) => exited = true));
    while (!exited) {
      try {
        final uri = (jsonDecode(info.readAsStringSync()) as Map)['uri'];
        if (uri is String) return Uri.parse(uri);
      } on Object {
        // Not written yet, or half written.
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return null;
  }

  Future<(VmServiceClient, String)?> _connect() {
    final client = _client;
    final isolate = _isolateId;
    if (client != null && !client.isClosed && isolate != null) {
      return Future.value((client, isolate));
    }
    final connecting = _connecting;
    if (connecting != null) return connecting;
    final generation = _generation;
    late final Future<(VmServiceClient, String)?> pending;
    pending = _connectFresh(generation).whenComplete(() {
      if (identical(_connecting, pending)) _connecting = null;
    });
    _connecting = pending;
    return pending;
  }

  Future<(VmServiceClient, String)?> _connectFresh(int generation) async {
    final uri = await _serviceUri;
    if (uri == null || generation != _generation) return null;
    final old = _client;
    final fresh = await _vmServiceConnector(uri);
    final String? id;
    try {
      id = await fresh.mainIsolateId();
    } on Object {
      await fresh.close();
      rethrow;
    }
    if (generation != _generation || _stopping || fresh.isClosed) {
      await fresh.close();
      return null;
    }
    unawaited(old?.close());
    _client = fresh;
    _isolateId = id;
    return id == null ? null : (fresh, id);
  }

  void _watchSources() {
    final target = p.normalize(p.absolute(root, file));
    final watched = <String>[];
    for (final name in ['lib', 'bin']) {
      final dir = Directory(p.join(root, name));
      if (dir.existsSync()) {
        _watchTree(dir);
        watched.add(dir.path);
      }
    }
    _subs.add(Directory(root).watch().listen((event) {
      final paths = [
        event.path,
        if (event case FileSystemMoveEvent(:final destination?)) destination,
      ];
      for (final path in paths) {
        if (!['lib', 'bin'].contains(p.basename(path))) continue;
        if (Directory(path).existsSync()) {
          if (event is FileSystemMoveEvent || event is FileSystemCreateEvent) {
            _forgetDirectoryWatch(path);
          }
          _watchTree(Directory(path));
          _changes();
        } else if (event is FileSystemDeleteEvent ||
            event is FileSystemMoveEvent) {
          _forgetDirectoryWatch(path);
        }
      }
    }, onError: (Object _) {}));
    if (!watched.any((dir) => p.isWithin(dir, target))) {
      final parent = Directory(p.dirname(target));
      _subs.add(parent.watch().listen((event) {
        final movedToTarget = event is FileSystemMoveEvent &&
            event.destination != null &&
            p.normalize(p.absolute(event.destination!)) == target;
        if (p.normalize(p.absolute(event.path)) == target || movedToTarget) {
          _changes();
        }
      }, onError: (Object _) {}));
    }
  }

  /// Watches [dir] and every directory below it. Linux has no recursive
  /// watch, so there each directory gets its own.
  void _watchTree(Directory dir) {
    if (!dir.existsSync() || !shouldWatchDirectory(dir.path)) return;
    final path = p.normalize(p.absolute(dir.path));
    if (!_watchedDirs.add(path)) return;
    final native = !Platform.isLinux;
    try {
      final sub = dir.watch(recursive: native).listen((event) {
        // A directory of sources created or moved in is a change everywhere.
        if (event is FileSystemCreateEvent &&
            event.isDirectory &&
            isWatchedDirectory(p.relative(event.path, from: root))) {
          _changes();
        }
        if (!native && event is FileSystemCreateEvent && event.isDirectory) {
          final created = Directory(event.path);
          if (created.existsSync() && shouldWatchDirectory(event.path)) {
            _watchTree(created);
            _changes();
          }
        }
        if (!native && event is FileSystemMoveEvent) {
          _forgetDirectoryWatch(event.path);
          final destination = event.destination;
          if (destination != null &&
              shouldWatchDirectory(destination) &&
              Directory(destination).existsSync()) {
            _watchTree(Directory(destination));
            _changes();
          }
        }
        if (!native && event is FileSystemDeleteEvent) {
          _forgetDirectoryWatch(event.path);
        }
        for (final path in [
          event.path,
          if (event case FileSystemMoveEvent(:final destination?)) destination,
        ]) {
          if (isWatchedChange(p.relative(path, from: root))) _changes();
        }
      }, onError: (Object _) {});
      _dirWatchSubs[path] = sub;
      _subs.add(sub);
    } on FileSystemException {
      _watchedDirs.remove(path);
      return;
    }
    if (native) return;
    try {
      for (final entry in dir.listSync()) {
        if (entry is Directory && shouldWatchDirectory(entry.path)) {
          _watchTree(entry);
        }
      }
    } on FileSystemException {
      _forgetDirectoryWatch(path);
    }
  }

  void _forgetDirectoryWatch(String path) {
    final normalized = p.normalize(p.absolute(path));
    for (final watched in _watchedDirs.toList()) {
      if (watched == normalized || p.isWithin(normalized, watched)) {
        _watchedDirs.remove(watched);
        final sub = _dirWatchSubs.remove(watched);
        if (sub != null) {
          _subs.remove(sub);
          unawaited(sub.cancel());
        }
      }
    }
  }

  /// Reloads, and again if more files change while it runs.
  Future<void> _reloadAll() async {
    if (_reloading) {
      _again = true;
      return;
    }
    _reloading = true;
    try {
      do {
        _again = false;
        await _reload();
        if (_again && !_stopping) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      } while (_again && !_stopping);
    } finally {
      _reloading = false;
    }
  }

  Future<void> _reload() async {
    if (_stopping || _restartReason != null) return;
    final generation = _generation;
    VmServiceClient? activeClient;
    try {
      // Null while a new child starts; it compiles the new code anyway.
      final connection = await _connect();
      if (connection == null) {
        if (generation == _generation && !_stopping) _again = true;
        return;
      }
      if (generation != _generation || _stopping) return;
      final (client, isolate) = connection;
      activeClient = client;
      final result = await client.reloadSources(isolate);
      if (generation != _generation || _stopping) return;
      switch (result) {
        case ReloadSuccess():
          await _setBanner(client, isolate, '', generation);
          await _ignoreMissing(
            client.callExtension('ext.dart_tui.reassemble', isolate),
          );
        case ReloadCompileError(:final message):
          final log = _writeLog('Compile error', message);
          await _setBanner(
            client,
            isolate,
            'Compile error ($log): ${firstErrorLine(message)}',
            generation,
          );
        case ReloadRejected(:final reason):
          _writeLog('Restarted', reason);
          _restart(reason);
      }
    } on Object catch (error) {
      // The app is exiting or restarting; its exit decides what happens.
      _writeLog('Reload failed', '$error');
      if (activeClient != null && identical(_client, activeClient)) {
        unawaited(activeClient.close());
        _client = null;
        _isolateId = null;
      }
    }
  }

  Future<void> _setBanner(
    VmServiceClient client,
    String isolate,
    String text,
    int generation,
  ) async {
    if (generation != _generation || _stopping) return;
    final revision = ++_bannerRevision;
    try {
      await client
          .callExtension('ext.dart_tui.devStatus', isolate, {'text': text});
    } on RpcException catch (error) {
      if (!error.methodNotFound) rethrow;
      if (text.isNotEmpty && generation == _generation && !_stopping) {
        unawaited(_tryShowBanner(text, generation, revision));
      }
      return;
    }
    if (generation != _generation || _stopping || revision != _bannerRevision) {
      return;
    }
  }

  /// Shows [text] once the restarted app registers its extensions.
  Future<void> _showBanner(String text, int generation) async {
    final revision = ++_bannerRevision;
    await _tryShowBanner(text, generation, revision);
  }

  Future<void> _tryShowBanner(
    String text,
    int generation,
    int revision,
  ) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!_stopping &&
        generation == _generation &&
        revision == _bannerRevision &&
        DateTime.now().isBefore(deadline)) {
      VmServiceClient? activeClient;
      try {
        // Until the app's Program runs there is no main isolate yet, or no
        // extension, or the isolate is not runnable: try again.
        final connection = await _connect();
        if (_stopping ||
            generation != _generation ||
            revision != _bannerRevision) {
          return;
        }
        if (connection case (final client, final isolate)) {
          activeClient = client;
          await client.callExtension(
            'ext.dart_tui.devStatus',
            isolate,
            {'text': text},
          );
          if (_stopping ||
              generation != _generation ||
              revision != _bannerRevision) {
            return;
          }
          return;
        }
        if (await _serviceUri == null) return; // the app exited
      } on Object {
        if (activeClient != null && identical(_client, activeClient)) {
          unawaited(activeClient.close());
          _client = null;
          _isolateId = null;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  static Stream<ProcessSignal> _watchSignal(ProcessSignal signal) =>
      signal.watch();

  Future<void> _ignoreMissing(Future<Object?> call) async {
    try {
      await call;
    } on RpcException catch (error) {
      // No Program has run yet, so the extensions are not there.
      if (!error.methodNotFound) rethrow;
    }
  }

  /// Writes [message] to the log file and returns its path for the banner.
  String _writeLog(String title, String message) {
    try {
      File(_logPath)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('$title at ${DateTime.now()}:\n\n$message\n');
    } on FileSystemException {
      // The banner still shows the first line.
    }
    return p.relative(_logPath);
  }

  void _restart(String reason) {
    _restartReason = reason;
    _kill();
  }

  void _stop() {
    _stopping = true;
    _kill();
  }

  /// Asks the child to quit, so it restores the terminal, and kills it if
  /// it has not exited after 5 seconds.
  void _kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    final child = _child;
    if (child == null) return;
    child.kill(signal);
    final generation = _generation;
    unawaited(child.exitCode.timeout(const Duration(seconds: 5), onTimeout: () {
      if (generation == _generation) child.kill(ProcessSignal.sigkill);
      return 0;
    }));
  }
}
