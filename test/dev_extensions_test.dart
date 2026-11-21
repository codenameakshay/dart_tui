// Program's `dart_tui dev` service extensions: registered once, only with a
// VM service; reassemble redraws every running program; devStatus banners.
import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:dart_tui/dart_tui.dart';
import 'package:dart_tui/src/program.dart' show setDevHooksForTesting;
import 'package:dart_tui/testing.dart';
import 'package:test/test.dart';

/// Stands in for code that a hot reload changes.
var _label = 'OLD';

final class _Counter extends Model {
  _Counter([this.count = 0]);
  final int count;

  @override
  (Model, Cmd?) update(Msg msg) => (this, null);

  @override
  View view() => newView('$_label count=$count');
}

final class _Run {
  _Run(bool alt) {
    program = Program(options: [
      withInput(input.stream),
      withOutput(out),
      withWindowSize(60, 10),
      withColorProfile(ColorProfile.noColor),
      withEnvironment(const {}),
      withoutSignalHandler(),
      if (alt) withAltScreen(),
    ]);
    done = program.run(_Counter(7));
  }

  final input = StreamController<List<int>>();
  final out = CaptureSink();
  late final Program program;
  late final Future<Model> done;

  Future<void> waitFor(String text) async {
    for (var i = 0; i < 200 && !out.text.contains(text); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(out.text, contains(text));
  }

  Future<void> stop() async {
    program.quit();
    await done;
    unawaited(input.close());
  }
}

void main() {
  late Map<String, ServiceExtensionHandler> handlers;
  late int registrations;

  void fakeService({bool running = true}) {
    handlers = {};
    registrations = 0;
    setDevHooksForTesting(
      serviceUri: () async => running ? Uri.parse('http://127.0.0.1:1/') : null,
      register: (method, handler) {
        registrations++;
        handlers[method] = handler;
      },
    );
  }

  Future<Map<String, Object?>> call(String method,
      [Map<String, String> params = const {}]) async {
    final response = await handlers[method]!(method, params);
    return jsonDecode(response.result!) as Map<String, Object?>;
  }

  setUp(() {
    _label = 'OLD';
    final profile = Style.defaultProfile;
    final dark = Style.hasDarkBackground;
    addTearDown(() {
      Style.defaultProfile = profile;
      Style.hasDarkBackground = dark;
      setDevHooksForTesting();
    });
  });

  test('registers nothing without a VM service', () async {
    fakeService(running: false);
    final run = _Run(false);
    await run.waitFor('OLD count=7');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await run.stop();
    expect(registrations, 0);
  });

  test('two programs and a second run register once', () async {
    fakeService();
    final a = _Run(false);
    final b = _Run(true);
    await a.waitFor('OLD count=7');
    await b.waitFor('OLD count=7');
    await a.stop();
    await b.stop();
    final c = _Run(false);
    await c.waitFor('OLD count=7');
    await c.stop();
    expect(registrations, 2);
    expect(
      handlers.keys,
      unorderedEquals(['ext.dart_tui.reassemble', 'ext.dart_tui.devStatus']),
    );
  });

  test('reassemble redraws inline and alt-screen programs, model kept',
      () async {
    fakeService();
    final inline = _Run(false);
    final alt = _Run(true);
    await inline.waitFor('OLD count=7');
    await alt.waitFor('OLD count=7');
    for (var i = 0; i < 100 && handlers.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    _label = 'NEW';
    expect(await call('ext.dart_tui.reassemble'), {'programs': 2});
    await inline.waitFor('NEW count=7');
    await alt.waitFor('NEW count=7');

    await inline.stop();
    expect(await call('ext.dart_tui.reassemble'), {'programs': 1});
    await alt.stop();
    expect(await call('ext.dart_tui.reassemble'), {'programs': 0});
  });

  test('devStatus shows a banner line and clears it', () async {
    fakeService();
    final run = _Run(false);
    await run.waitFor('OLD count=7');
    for (var i = 0; i < 100 && handlers.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    await call('ext.dart_tui.devStatus', {'text': 'Compile error: x'});
    await run.waitFor(' Compile error: x ');
    run.out.clear();

    await call('ext.dart_tui.devStatus', {'text': ''});
    // The frame shrinks back to one row: everything below it is erased.
    await run.waitFor('\x1b[J');
    await run.stop();
  });

  test('the banner replaces the bottom row of a full alt screen', () async {
    fakeService();
    _label = [for (var row = 1; row <= 12; row++) 'row$row'].join('\n');
    final run = _Run(true);
    await run.waitFor('row12 count=7');
    for (var i = 0; i < 100 && handlers.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    run.out.clear();
    await call('ext.dart_tui.devStatus', {'text': 'restarted: x'});
    await run.waitFor('restarted: x');
    // Ten rows: nine of the view, then the banner on the last one.
    expect(run.out.text, matches(RegExp(r'\x1b\[10;1H[^\n]*restarted: x')));
    await run.stop();
  });
}
