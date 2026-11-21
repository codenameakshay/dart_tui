/// A minimal Dart VM service client for `dart_tui dev`: JSON-RPC 2.0 over a
/// dart:io WebSocket, with only the calls a hot reload needs.
///
/// Internal. Not exported.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../ansi_state.dart' show stripAnsiSequences;

/// An error reply from the VM service.
final class RpcException implements Exception {
  RpcException(this.code, this.message);

  /// The JSON-RPC error code, such as -32601 for an unknown method.
  final int code;
  final String message;

  /// The method is not there, for example an extension not registered yet.
  bool get methodNotFound => code == -32601;

  @override
  String toString() => 'RpcException($code): $message';
}

/// The connection closed before the reply came.
final class ServiceClosedException implements Exception {
  @override
  String toString() => 'The VM service connection closed.';
}

/// What a `reloadSources` call did.
sealed class ReloadResult {
  const ReloadResult();
}

/// The new code is live.
final class ReloadSuccess extends ReloadResult {
  const ReloadSuccess();
}

/// The code does not compile. The old code keeps running.
final class ReloadCompileError extends ReloadResult {
  const ReloadCompileError(this.message);

  /// The compiler output, one or more errors.
  final String message;
}

/// The code compiles, but the VM cannot swap it in, for example because a
/// class changed shape. Only a restart applies it.
final class ReloadRejected extends ReloadResult {
  const ReloadRejected(this.reason);
  final String reason;
}

/// The WebSocket URI for the VM service at [serviceUri], the HTTP URI from
/// `--write-service-info` or `Service.getInfo`.
Uri webSocketUri(Uri serviceUri) {
  final path =
      serviceUri.path.endsWith('/') ? serviceUri.path : '${serviceUri.path}/';
  return serviceUri.replace(
    scheme: serviceUri.scheme == 'https' ? 'wss' : 'ws',
    path: '${path}ws',
  );
}

/// A JSON-RPC client for one VM service connection.
final class VmServiceClient {
  VmServiceClient(this._socket) {
    _socket.listen(
      _onMessage,
      onError: (Object _) => _close(),
      onDone: _close,
      cancelOnError: true,
    );
  }

  /// Connects to the VM service at [serviceUri] (its HTTP URI).
  static Future<VmServiceClient> connect(Uri serviceUri) async =>
      VmServiceClient(await WebSocket.connect('${webSocketUri(serviceUri)}'));

  final WebSocket _socket;
  final Map<String, Completer<Object?>> _pending = {};
  final Completer<void> _done = Completer<void>();
  var _nextId = 0;

  /// Completes when the connection closes.
  Future<void> get done => _done.future;

  bool get isClosed => _done.isCompleted;

  /// Calls [method] and returns its `result`. Throws [RpcException] for an
  /// error reply and [ServiceClosedException] when the connection drops.
  Future<Object?> call(String method,
      [Map<String, Object?> params = const {}]) {
    if (isClosed) return Future.error(ServiceClosedException());
    final id = '${++_nextId}';
    final reply = _pending[id] = Completer<Object?>();
    _socket.add(jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params,
    }));
    return reply.future;
  }

  /// The id of the isolate named `main`, or of the first one that is not a
  /// system isolate. Null when there is none.
  Future<String?> mainIsolateId() async {
    final vm = await call('getVM');
    final isolates = [
      for (final isolate in (vm as Map)['isolates'] as List? ?? const [])
        if (isolate is Map &&
            isolate['id'] is String &&
            isolate['isSystemIsolate'] != true)
          isolate,
    ];
    final main = isolates.where((isolate) => isolate['name'] == 'main');
    final chosen = main.isNotEmpty ? main.first : isolates.firstOrNull;
    return chosen?['id'] as String?;
  }

  /// Reloads the sources of [isolateId] and says what happened.
  Future<ReloadResult> reloadSources(String isolateId) async {
    final report = await call('reloadSources', {'isolateId': isolateId});
    if (report case {'success': true}) return const ReloadSuccess();
    final notices = [
      if (report case {'notices': final List<Object?> notices})
        for (final notice in notices)
          if (notice case {'message': final String message}) message,
    ];
    // With a terminal attached, the compiler colours its errors.
    final message = stripAnsiSequences(
      notices.isEmpty ? 'reload failed' : notices.join('\n'),
    );
    // The kernel compiler reports errors as `file:line:col: Error: ...`;
    // the VM's own refusals (class shape, enums, const classes) do not.
    if (RegExp(r'^\S+:\d+:\d+: Error: ', multiLine: true).hasMatch(message)) {
      return ReloadCompileError(message);
    }
    return ReloadRejected(shortReason(message));
  }

  /// Calls the service extension [method] on [isolateId].
  Future<Object?> callExtension(
    String method,
    String isolateId, [
    Map<String, String> params = const {},
  ]) =>
      call(method, {'isolateId': isolateId, ...params});

  Future<void> close() async {
    await _socket.close();
    _close();
  }

  void _onMessage(Object? data) {
    if (data is! String) return;
    final Object? message;
    try {
      message = jsonDecode(data);
    } on FormatException {
      return;
    }
    if (message is! Map || message['id'] == null) return; // an event
    final reply = _pending.remove('${message['id']}');
    if (reply == null) return;
    if (message['error'] case final Map<Object?, Object?> error) {
      reply.completeError(RpcException(
        error['code'] as int? ?? 0,
        '${error['message'] ?? 'unknown error'}',
      ));
    } else {
      reply.complete(message['result']);
    }
  }

  void _close() {
    if (_done.isCompleted) return;
    _done.complete();
    final pending = [..._pending.values];
    _pending.clear();
    for (final reply in pending) {
      reply.completeError(ServiceClosedException());
    }
  }
}

/// The first line of a VM reload refusal, without the library URI it names:
/// `Const class cannot remove fields: Library:'file:///…' Class: Pt` becomes
/// `Const class cannot remove fields (Pt)`.
String shortReason(String message) {
  final line = message.split('\n').first;
  final match =
      RegExp(r"^(.*?):? Library:'[^']*'(?: Class: (\S+))?").firstMatch(
    line,
  );
  if (match == null) return line;
  final name = match[2];
  return name == null ? match[1]! : '${match[1]} ($name)';
}
