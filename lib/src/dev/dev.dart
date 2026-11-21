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
  final name = RegExp(r'^name:\s*([A-Za-z0-9_]+)', multiLine: true)
      .firstMatch(pubspec.readAsStringSync())?[1];
  return name == null ? null : p.join('bin', '$name.dart');
}

/// Whether a change to [path] (relative to the project) should reload: a
/// `.dart` file outside hidden directories such as `.dart_tool`.
bool isWatchedChange(String path) =>
    path.endsWith('.dart') &&
    !p
        .split(path)
        .any((part) => part.startsWith('.') && part != '.' && part != '..');

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

/// One `dart_tui dev` run: the child app, the file watchers and the reloads.
final class DevSession {
  DevSession({
    required this.root,
    required this.file,
    this.appArgs = const [],
    this.debounce = const Duration(milliseconds: 100),
  });

  final String root;
  final String file;
  final List<String> appArgs;
  final Duration debounce;

  late final Directory _temp;
  late final String _logPath =
      p.join(root, '.dart_tool', 'dart_tui', 'dev.log');
  final List<StreamSubscription<Object?>> _subs = [];
  late final Debouncer _changes = Debouncer(debounce, _reloadAll);

  Process? _child;
  int _generation = 0;
  Future<Uri?>? _serviceUri;
  VmServiceClient? _client;
  String? _isolateId;
  bool _reloading = false;
  bool _again = false;
  bool _bannerShown = false;
  String? _restartReason;
  bool _stopping = false;

  /// Runs the app until it exits and returns its exit code.
  Future<int> run() async {
    _temp = Directory.systemTemp.createTempSync('dart_tui_dev');
    // Ctrl+C reaches the whole foreground process group. The app decides
    // what it means; this process exits when the app does.
    _subs.add(ProcessSignal.sigint.watch().listen((_) {}));
    if (!Platform.isWindows) {
      for (final signal in [ProcessSignal.sigterm, ProcessSignal.sighup]) {
        _subs.add(signal.watch().listen((_) => _stop(signal)));
      }
    }
    _watchSources();
    try {
      String? banner;
      while (true) {
        final child = await _start();
        if (_stopping) _kill();
        if (banner != null) unawaited(_showBanner(banner, _generation));
        final code = await child.exitCode;
        final reason = _restartReason;
        if (reason == null || _stopping) return shellExitCode(code);
        _restartReason = null;
        _bannerShown = false;
        banner = 'restarted: $reason';
      }
    } finally {
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

  Future<Process> _start() async {
    final generation = ++_generation;
    final info = File(p.join(_temp.path, 'service-$generation.json'));
    _client = null;
    _isolateId = null;
    final child = _child = await Process.start(
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
    _serviceUri = _readServiceInfo(info, child);
    return child;
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

  Future<(VmServiceClient, String)?> _connect() async {
    final client = _client;
    final isolate = _isolateId;
    if (client != null && !client.isClosed && isolate != null) {
      return (client, isolate);
    }
    final uri = await _serviceUri;
    if (uri == null) return null;
    unawaited(client?.close());
    final fresh = _client = await VmServiceClient.connect(uri);
    final id = _isolateId = await fresh.mainIsolateId();
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
    if (!watched.any((dir) => p.isWithin(dir, target))) {
      final parent = Directory(p.dirname(target));
      _subs.add(parent.watch().listen((event) {
        if (p.normalize(p.absolute(event.path)) == target) _changes();
      }, onError: (Object _) {}));
    }
  }

  /// Watches [dir] and every directory below it. Linux has no recursive
  /// watch, so there each directory gets its own.
  void _watchTree(Directory dir) {
    final native = !Platform.isLinux;
    _subs.add(dir.watch(recursive: native).listen((event) {
      if (!native && event is FileSystemCreateEvent && event.isDirectory) {
        _watchTree(Directory(event.path));
      }
      for (final path in [
        event.path,
        if (event case FileSystemMoveEvent(:final destination?)) destination,
      ]) {
        if (isWatchedChange(p.relative(path, from: root))) _changes();
      }
    }, onError: (Object _) {}));
    if (native) return;
    for (final entry in dir.listSync()) {
      if (entry is Directory && !p.basename(entry.path).startsWith('.')) {
        _watchTree(entry);
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
      } while (_again && !_stopping);
    } finally {
      _reloading = false;
    }
  }

  Future<void> _reload() async {
    if (_stopping || _restartReason != null) return;
    final generation = _generation;
    try {
      // Null while a new child starts; it compiles the new code anyway.
      final connection = await _connect();
      if (connection == null || generation != _generation) return;
      final (client, isolate) = connection;
      switch (await client.reloadSources(isolate)) {
        case ReloadSuccess():
          if (_bannerShown) await _setBanner(client, isolate, '');
          await _ignoreMissing(
            client.callExtension('ext.dart_tui.reassemble', isolate),
          );
        case ReloadCompileError(:final message):
          final log = _writeLog('Compile error', message);
          await _setBanner(
            client,
            isolate,
            'Compile error ($log): ${firstErrorLine(message)}',
          );
        case ReloadRejected(:final reason):
          _writeLog('Restarted', reason);
          _restart(reason);
      }
    } on Object catch (error) {
      // The app is exiting or restarting; its exit decides what happens.
      _writeLog('Reload failed', '$error');
      unawaited(_client?.close());
      _client = null;
    }
  }

  Future<void> _setBanner(
    VmServiceClient client,
    String isolate,
    String text,
  ) async {
    await _ignoreMissing(
      client.callExtension('ext.dart_tui.devStatus', isolate, {'text': text}),
    );
    _bannerShown = text.isNotEmpty;
  }

  /// Shows [text] once the restarted app registers its extensions.
  Future<void> _showBanner(String text, int generation) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!_stopping &&
        generation == _generation &&
        DateTime.now().isBefore(deadline)) {
      try {
        // Until the app's Program runs there is no main isolate yet, or no
        // extension, or the isolate is not runnable: try again.
        if (await _connect() case (final client, final isolate)) {
          await client.callExtension(
            'ext.dart_tui.devStatus',
            isolate,
            {'text': text},
          );
          _bannerShown = true;
          return;
        }
        if (await _serviceUri == null) return; // the app exited
      } on Object {
        unawaited(_client?.close());
        _client = null;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

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

  void _stop(ProcessSignal signal) {
    _stopping = true;
    _kill(signal);
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
