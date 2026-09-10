// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:math' show min;

import 'package:characters/characters.dart';
import 'package:dart_tui/dart_tui.dart';
import 'package:dart_tui/src/ansi_state.dart';
import 'package:dart_tui/src/input_decoder.dart';
import 'package:dart_tui/src/renderer.dart';

final class _Sink implements IOSink {
  final StringBuffer buffer = StringBuffer();

  @override
  void add(List<int> data) => buffer.write(utf8.decode(data));
  @override
  Future<void> addStream(Stream<List<int>> stream) async {}
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future<void> close() async {}
  @override
  Future<void> flush() async {}
  @override
  Future<void> get done async {}
  @override
  Encoding get encoding => utf8;
  @override
  set encoding(Encoding value) {}
  @override
  void write(Object? object) => buffer.write(object);
  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) =>
      buffer.writeAll(objects, separator);
  @override
  void writeCharCode(int charCode) => buffer.writeCharCode(charCode);
  @override
  void writeln([Object? object = '']) => buffer.writeln(object);
}

final class _BenchRow {
  const _BenchRow({
    required this.name,
    this.naiveMicros,
    required this.dartTuiMicros,
    this.naiveChecksum,
    required this.dartTuiChecksum,
    this.ratio,
  });

  final String name;
  final int? naiveMicros;
  final int dartTuiMicros;
  final int? naiveChecksum;
  final int dartTuiChecksum;
  final double? ratio;
}

final class _JsonRow {
  const _JsonRow({
    required this.name,
    required this.impl,
    required this.medianMicros,
    required this.checksum,
  });

  final String name;
  final String impl;
  final int medianMicros;
  final int checksum;

  Map<String, Object> toJson() => {
        'name': name,
        'impl': impl,
        'medianMicros': medianMicros,
        'checksum': checksum,
      };
}

int _naiveVisibleWidth(String s) => s.characters.fold<int>(
      0,
      (w, g) => w + (g.runes.first > 0x7F ? 2 : 1),
    );

int _benchGetWidthPlainNaive(String plain) {
  var result = 0;
  for (var i = 0; i < 10000; i++) {
    result += _naiveVisibleWidth(plain);
  }
  if (result == 0) throw StateError('unreachable');
  return result;
}

int _benchGetWidthPlainDartTui(String plain) {
  var result = 0;
  for (var i = 0; i < 10000; i++) {
    result += getWidth(plain);
  }
  if (result == 0) throw StateError('unreachable');
  return result;
}

int _benchGetWidthAnsiNaive(String ansi) {
  final re = RegExp(r'\x1b\[[0-9;]*m');
  var result = 0;
  for (var i = 0; i < 10000; i++) {
    result += _naiveVisibleWidth(ansi.replaceAll(re, ''));
  }
  if (result == 0) throw StateError('unreachable');
  return result;
}

int _benchGetWidthAnsiDartTui(String ansi) {
  var result = 0;
  for (var i = 0; i < 10000; i++) {
    result += getWidth(ansi);
  }
  if (result == 0) throw StateError('unreachable');
  return result;
}

int _benchCellIdenticalDartTui(View frame) {
  final sink = _Sink();
  final renderer = CellRenderer(
    output: sink,
    defaultAltScreen: false,
    defaultHideCursor: false,
  );
  renderer.render(frame);
  for (var i = 0; i < 1000; i++) {
    renderer.render(frame);
  }
  final checksum = sink.buffer.length;
  if (checksum == 0) throw StateError('renderer emitted no output');
  return checksum;
}

int _benchCellAlternatingDartTui(View frame, View changed) {
  final sink = _Sink();
  final renderer = CellRenderer(
    output: sink,
    defaultAltScreen: false,
    defaultHideCursor: false,
  );
  for (var i = 0; i < 1000; i++) {
    renderer.render(i.isEven ? frame : changed);
  }
  final checksum = sink.buffer.length;
  if (checksum == 0) throw StateError('renderer emitted no output');
  return checksum;
}

int _benchTextAreaNaive() {
  final value = List.generate(40, (_) => '0123456789abcdef' * 3).join('\n');
  var row = 0;
  var checksum = 0;
  for (var i = 0; i < 300; i++) {
    row = i.isEven ? 1 : 0;
    final model = TextAreaModel(
      value: value,
      width: 40,
      maxHeight: 12,
      cursorRow: row,
    );
    final view = model.view();
    checksum += view.content.length + (view.cursor?.x ?? 0);
  }
  if (checksum == 0) throw StateError('empty text area');
  return checksum;
}

int _benchTextAreaDartTui() {
  final value = List.generate(40, (_) => '0123456789abcdef' * 3).join('\n');
  var model = TextAreaModel(value: value, width: 40, maxHeight: 12);
  var checksum = 0;
  for (var i = 0; i < 300; i++) {
    model = model
        .update(
          KeyPressMsg(TeaKey(code: i.isEven ? KeyCode.down : KeyCode.up)),
        )
        .$1 as TextAreaModel;
    final view = model.view();
    checksum += view.content.length + (view.cursor?.x ?? 0);
  }
  if (model.visualLineCount == 0) throw StateError('empty text area');
  return checksum;
}

int _benchViewportSoftWrapNaive(String content) {
  var checksum = 0;
  for (var i = 0; i < 20; i++) {
    final viewport = ViewportModel(
      content: content,
      width: 80,
      height: 24,
      yOffset: i,
    );
    checksum += viewport.view().content.length;
  }
  if (checksum <= 0) throw StateError('benchmark did not render');
  return checksum;
}

int _benchViewportSoftWrapDartTui(String content) {
  var viewport = ViewportModel(
    content: content,
    width: 80,
    height: 24,
  );
  var checksum = 0;
  for (var i = 0; i < 20; i++) {
    viewport = viewport.scrollBy(1);
    checksum += viewport.view().content.length;
  }
  if (checksum <= 0) throw StateError('benchmark did not render');
  return checksum;
}

int _benchDecoderNaive(List<int> bytes) {
  var buf = <int>[...bytes];
  var checksum = 0;
  while (buf.isNotEmpty) {
    checksum += buf[0];
    buf.removeRange(0, 1);
  }
  if (checksum <= 0) throw StateError('decoder checksum must be positive');
  return checksum;
}

int _benchDecoderDartTui(List<int> bytes, int chunkSize) {
  final decoder = TerminalInputDecoder();
  var checksum = 0;
  for (var start = 0; start < bytes.length; start += chunkSize) {
    final end = min(start + chunkSize, bytes.length);
    for (final msg in decoder.feed(bytes.sublist(start, end))) {
      checksum += switch (msg) {
        KeyPressMsg(:final keyEvent) => keyEvent.text.length + 1,
        KeyReleaseMsg(:final keyEvent) => keyEvent.text.length + 2,
        PasteMsg(:final content) => content.length + 3,
        PasteStartMsg() => 4,
        PasteEndMsg() => 5,
        CapabilityMsg(:final content) => content.length + 6,
        _ => 7,
      };
    }
  }
  if (checksum <= 0) throw StateError('decoder checksum must be positive');
  return checksum;
}

int _benchViewportHighlightsDartTui() {
  final searchableContent = List.generate(
    1000,
    (i) => 'line $i ${'x' * 160}',
  ).join('\n');
  final highlights = [
    for (var i = 0; i < 1000; i++) ViewportHighlight(line: i, start: 0, end: 4),
  ];
  var viewport = ViewportModel(
    content: searchableContent,
    width: 80,
    height: 24,
    softWrap: false,
    highlights: highlights,
  );
  var checksum = 0;
  for (var i = 0; i < 20; i++) {
    viewport = viewport.scrollBy(1);
    checksum += viewport.view().content.length;
  }
  if (checksum <= 0) throw StateError('benchmark did not render');
  return checksum;
}

int _benchTokenizeDartTui(String longStyled) {
  final tokens = tokenizeAnsi(longStyled);
  if (tokens.isEmpty) throw StateError('tokenizer emitted no tokens');
  return tokens.length;
}

int _benchCanvasDartTui() {
  final canvas = Canvas(80, 4);
  canvas.paint(0, 0, '\x1b[31m${'x' * 50000}\x1b[0m');
  final output = canvas.render();
  if (output.length < 80) throw StateError('short canvas output');
  return output.length;
}

int _benchTextInputDartTui() {
  var model = TextInputModel(
    value: '0123456789abcdef' * 100,
    cursorPos: 800,
    suggestions: const ['prefix-one', 'prefix-two'],
  );
  var checksum = 0;
  for (var i = 0; i < 1200; i++) {
    model = model
        .update(
          KeyPressMsg(TeaKey(code: i.isEven ? KeyCode.left : KeyCode.right)),
        )
        .$1 as TextInputModel;
    final view = model.view();
    checksum += view.content.length + (view.cursor?.x ?? 0);
  }
  if (model.value.isEmpty) throw StateError('empty text input');
  return checksum;
}

({int medianMicros, int checksum}) _measure(
  int Function() action, {
  int sampleCount = 5,
}) {
  action();
  final timings = <int>[];
  var checksum = 0;
  for (var i = 0; i < sampleCount; i++) {
    final stopwatch = Stopwatch()..start();
    checksum = action();
    stopwatch.stop();
    timings.add(stopwatch.elapsedMicroseconds);
  }
  if (checksum <= 0) throw StateError('checksum must be positive');
  timings.sort();
  return (
    medianMicros: timings[timings.length ~/ 2],
    checksum: checksum,
  );
}

_BenchRow _pairRow(
  String name,
  int Function() naive,
  int Function() dartTui, {
  int sampleCount = 5,
}) {
  final naiveResult = _measure(naive, sampleCount: sampleCount);
  final dartTuiResult = _measure(dartTui, sampleCount: sampleCount);
  return _BenchRow(
    name: name,
    naiveMicros: naiveResult.medianMicros,
    dartTuiMicros: dartTuiResult.medianMicros,
    naiveChecksum: naiveResult.checksum,
    dartTuiChecksum: dartTuiResult.checksum,
    ratio: naiveResult.medianMicros / dartTuiResult.medianMicros,
  );
}

_BenchRow _dartTuiOnlyRow(
  String name,
  int Function() dartTui, {
  int sampleCount = 5,
}) {
  final dartTuiResult = _measure(dartTui, sampleCount: sampleCount);
  return _BenchRow(
    name: name,
    dartTuiMicros: dartTuiResult.medianMicros,
    dartTuiChecksum: dartTuiResult.checksum,
  );
}

String _formatMicros(int micros) => '$micros µs';

String _formatRatio(double ratio) => ratio >= 1
    ? '${ratio.toStringAsFixed(1)}x'
    : '${ratio.toStringAsFixed(2)}x';

String _gitHead() {
  try {
    final result = Process.runSync('git', ['rev-parse', '--short', 'HEAD']);
    if (result.exitCode == 0) {
      return (result.stdout as String).trim();
    }
  } catch (_) {}
  return 'unknown';
}

void main(List<String> args) {
  final jsonMode = args.contains('--json');

  final plain = List.filled(20, 'hello world ').join();
  final ansi = '\x1b[31m$plain\x1b[0m';
  final cellFrame = View(
    content: List.generate(
      24,
      (r) => '\x1b[38;5;${r % 16}m${'x' * 80}\x1b[0m',
    ).join('\n'),
  );
  final cellChanged = View(
    content: List.generate(
      24,
      (r) => '\x1b[38;5;${(r + 1) % 16}m${'y' * 80}\x1b[0m',
    ).join('\n'),
  );
  final wrappedContent =
      List.generate(4000, (i) => 'line $i: ${'x' * 120}').join('\n');
  final plainDecoderBytes = utf8.encode('a' * 100000);
  final longStyled = List.generate(
    2500,
    (i) => '\x1b[38;5;${i % 256}mitem$i\x1b[0m',
  ).join();

  final rows = <_BenchRow>[
    _pairRow(
      'getWidth plain x10000',
      () => _benchGetWidthPlainNaive(plain),
      () => _benchGetWidthPlainDartTui(plain),
    ),
    _pairRow(
      'getWidth ANSI x10000',
      () => _benchGetWidthAnsiNaive(ansi),
      () => _benchGetWidthAnsiDartTui(ansi),
    ),
    _pairRow(
      'textarea update+view x300',
      _benchTextAreaNaive,
      _benchTextAreaDartTui,
    ),
    _pairRow(
      'viewport soft-wrap scroll+view x20',
      () => _benchViewportSoftWrapNaive(wrappedContent),
      () => _benchViewportSoftWrapDartTui(wrappedContent),
    ),
    _pairRow(
      'decoder plain 100000 bytes',
      () => _benchDecoderNaive(plainDecoderBytes),
      () => _benchDecoderDartTui(plainDecoderBytes, plainDecoderBytes.length),
    ),
    _dartTuiOnlyRow(
      'cell identical frames x1000',
      () => _benchCellIdenticalDartTui(cellFrame),
    ),
    _dartTuiOnlyRow(
      'cell alternating frames x1000',
      () => _benchCellAlternatingDartTui(cellFrame, cellChanged),
    ),
    _dartTuiOnlyRow(
      'viewport highlights scroll+view x20',
      _benchViewportHighlightsDartTui,
    ),
    _dartTuiOnlyRow(
      'tokenize 50k styled ANSI',
      () => _benchTokenizeDartTui(longStyled),
      sampleCount: 3,
    ),
    _dartTuiOnlyRow('canvas 50k clipped line', _benchCanvasDartTui),
    _dartTuiOnlyRow('text_input navigation/view x1200', _benchTextInputDartTui),
    _dartTuiOnlyRow(
      'decoder bracketed paste',
      () => _benchDecoderDartTui(
        utf8.encode('\x1b[200~${'🙂' * 25000}\x1b[201~'),
        4096,
      ),
    ),
    _dartTuiOnlyRow(
      'decoder fragmented OSC',
      () => _benchDecoderDartTui(
        utf8.encode('\x1b]99;${'x' * 50000}\x07a'),
        1,
      ),
    ),
    _dartTuiOnlyRow(
      'decoder fragmented DCS',
      () => _benchDecoderDartTui(
        utf8.encode('\x1bP+r${'61' * 25000}\x1b\\a'),
        1,
      ),
    ),
    _dartTuiOnlyRow(
      'decoder fragmented CSI',
      () => _benchDecoderDartTui(
        utf8.encode('\x1b[${'1;' * 25000}za'),
        1,
      ),
    ),
  ];

  if (jsonMode) {
    final jsonRows = <_JsonRow>[];
    for (final row in rows) {
      if (row.naiveMicros != null) {
        jsonRows.add(
          _JsonRow(
            name: row.name,
            impl: 'naive',
            medianMicros: row.naiveMicros!,
            checksum: row.naiveChecksum!,
          ),
        );
      }
      jsonRows.add(
        _JsonRow(
          name: row.name,
          impl: 'dart_tui',
          medianMicros: row.dartTuiMicros,
          checksum: row.dartTuiChecksum,
        ),
      );
    }
    print(jsonEncode(jsonRows.map((r) => r.toJson()).toList()));
    return;
  }

  print('| Workload | Naive | dart_tui | Ratio |');
  print('| --- | ---: | ---: | ---: |');
  for (final row in rows) {
    final naiveCol =
        row.naiveMicros == null ? '—' : _formatMicros(row.naiveMicros!);
    final ratioCol = row.ratio == null ? '—' : _formatRatio(row.ratio!);
    print(
      '| ${row.name} | $naiveCol | ${_formatMicros(row.dartTuiMicros)} | $ratioCol |',
    );
  }
  print(
    '${Platform.version}, ${Platform.operatingSystem}, '
    '${DateTime.now().toUtc().toIso8601String()}, ${_gitHead()}',
  );
}
