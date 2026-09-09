// ignore_for_file: avoid_print

import 'package:dart_tui/dart_tui.dart';

void main() {
  final wrappedContent =
      List.generate(4000, (i) => 'line $i: ${'x' * 120}').join('\n');
  final wrapped = _bench(() {
    var viewport = ViewportModel(
      content: wrappedContent,
      width: 80,
      height: 24,
    );
    var checksum = 0;
    for (var i = 0; i < 20; i++) {
      viewport = viewport.scrollBy(1);
      checksum += viewport.view().content.length;
    }
    return checksum;
  });

  final searchableContent = List.generate(
    1000,
    (i) => 'line $i ${'x' * 160}',
  ).join('\n');
  final highlights = [
    for (var i = 0; i < 1000; i++) ViewportHighlight(line: i, start: 0, end: 4),
  ];
  final horizontal = _bench(() {
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
    return checksum;
  });

  print('viewport soft-wrap scroll+view x20: ${wrapped.elapsedMicros} µs '
      '(checksum ${wrapped.checksum})');
  print('viewport horizontal/highlights scroll+view x20: '
      '${horizontal.elapsedMicros} µs (checksum ${horizontal.checksum})');
}

_BenchResult _bench(int Function() fn) {
  fn();
  final times = <int>[];
  var checksum = 0;
  for (var run = 0; run < 5; run++) {
    final watch = Stopwatch()..start();
    checksum = fn();
    watch.stop();
    times.add(watch.elapsedMicroseconds);
  }
  if (checksum <= 0) throw StateError('benchmark did not render');
  times.sort();
  return _BenchResult(times[times.length ~/ 2], checksum);
}

final class _BenchResult {
  const _BenchResult(this.elapsedMicros, this.checksum);

  final int elapsedMicros;
  final int checksum;
}
