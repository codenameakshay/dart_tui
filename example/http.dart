// Ported from charmbracelet/bubbletea examples/http
import 'dart:io';
import 'package:dart_tui/dart_tui.dart';

final class _StatusMsg extends Msg {
  _StatusMsg(this.status);
  final int status;
}

final class _ErrMsg extends Msg {
  _ErrMsg(this.error);
  final String error;
}

Future<void> main() async {
  await Program(
    options: const ProgramOptions(tickInterval: Duration(milliseconds: 100)),
  ).run(HttpModel());
}

final class HttpModel extends TeaModel {
  HttpModel({
    SpinnerModel? spinner,
    this.status,
    this.error,
    this.done = false,
  }) : spinner =
            spinner ?? SpinnerModel(suffix: ' Checking http://example.com...');

  final SpinnerModel spinner;
  final int? status;
  final String? error;
  final bool done;

  @override
  Cmd? init() => () async {
        try {
          final client = HttpClient();
          client.connectionTimeout = const Duration(seconds: 10);
          final request = await client.getUrl(Uri.parse('http://example.com'));
          final response = await request.close();
          client.close();
          return _StatusMsg(response.statusCode);
        } catch (e) {
          return _ErrMsg(e.toString());
        }
      };

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is KeyMsg) {
      if (msg.key == 'q' || msg.key == 'ctrl+c') return (this, () => quit());
    }
    if (msg is _StatusMsg) {
      return (
        HttpModel(spinner: spinner, status: msg.status, done: true),
        null,
      );
    }
    if (msg is _ErrMsg) {
      return (HttpModel(spinner: spinner, error: msg.error, done: true), null);
    }
    if (msg is TickMsg) {
      final (next, cmd) = spinner.update(msg);
      return (
        HttpModel(
          spinner: next as SpinnerModel,
          status: status,
          error: error,
          done: done,
        ),
        cmd,
      );
    }
    return (this, null);
  }

  @override
  View view() {
    if (done) {
      final content = error != null
          ? const Style().foregroundColor256(196).render('Error: $error')
          : const Style().foregroundColor256(82).render('HTTP $status OK');
      return newView('$content\n\nPress q to quit.');
    }
    return newView('${spinner.view().content}\n\nq: quit');
  }
}
