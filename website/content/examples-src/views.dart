// Two-view app: task list → download progress.
// Run: fvm dart run example/views.dart

import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  await Program(
    options: const ProgramOptions(altScreen: true),
  ).run(_ViewsModel());
}

enum _Phase { list, progress, done }

final class _TickMsg extends Msg {}

const _items = [
  'package-a v1.2.3',
  'package-b v0.9.0',
  'package-c v2.0.1',
  'package-d v3.1.4',
];

final class _ViewsModel extends TeaModel {
  _ViewsModel({
    this.phase = _Phase.list,
    this.cursor = 0,
    this.fraction = 0.0,
  });

  final _Phase phase;
  final int cursor;
  final double fraction;

  _ViewsModel _copyWith({
    _Phase? phase,
    int? cursor,
    double? fraction,
  }) =>
      _ViewsModel(
        phase: phase ?? this.phase,
        cursor: cursor ?? this.cursor,
        fraction: fraction ?? this.fraction,
      );

  @override
  (Model, Cmd?) update(Msg msg) {
    switch (phase) {
      case _Phase.list:
        return _updateList(msg);
      case _Phase.progress:
        return _updateProgress(msg);
      case _Phase.done:
        return _updateDone(msg);
    }
  }

  (Model, Cmd?) _updateList(Msg msg) {
    if (msg is! KeyMsg) return (this, null);
    switch (msg.key) {
      case 'up':
      case 'k':
        return (_copyWith(cursor: cursor > 0 ? cursor - 1 : 0), null);
      case 'down':
      case 'j':
        return (
          _copyWith(
            cursor: cursor < _items.length - 1 ? cursor + 1 : _items.length - 1,
          ),
          null,
        );
      case 'enter':
        return (
          _copyWith(phase: _Phase.progress, fraction: 0.0),
          tick(const Duration(milliseconds: 80), (_) => _TickMsg()),
        );
      case 'q':
      case 'ctrl+c':
        return (this, () => quit());
    }
    return (this, null);
  }

  (Model, Cmd?) _updateProgress(Msg msg) {
    if (msg is _TickMsg) {
      final next = fraction + 0.025;
      if (next >= 1.0) {
        return (_copyWith(phase: _Phase.done, fraction: 1.0), null);
      }
      return (
        _copyWith(fraction: next),
        tick(const Duration(milliseconds: 80), (_) => _TickMsg()),
      );
    }
    if (msg is KeyMsg) {
      if (msg.key == 'q' || msg.key == 'ctrl+c') {
        return (this, () => quit());
      }
    }
    return (this, null);
  }

  (Model, Cmd?) _updateDone(Msg msg) {
    if (msg is! KeyMsg) return (this, null);
    if (msg.key == 'q' || msg.key == 'ctrl+c') {
      return (this, () => quit());
    }
    return (this, null);
  }

  @override
  View view() {
    switch (phase) {
      case _Phase.list:
        return _listView();
      case _Phase.progress:
        return _progressView();
      case _Phase.done:
        return _doneView();
    }
  }

  View _listView() {
    final b = StringBuffer();
    b.writeln('Select a package to download:\n');
    for (var i = 0; i < _items.length; i++) {
      final mark = i == cursor ? '>' : ' ';
      b.writeln('  $mark ${_items[i]}');
    }
    b.writeln('\nUp/Down to navigate · Enter to start download · q to quit');
    return newView(b.toString());
  }

  View _progressView() {
    final name = _items[cursor];
    final bar = ProgressModel(fraction: fraction, width: 40, label: name)
        .view()
        .content;
    return newView('''
Downloading $name...

$bar

Press q to quit.
''');
  }

  View _doneView() {
    return newView('''
Download complete!

${ProgressModel(fraction: 1.0, width: 40, label: _items[cursor]).view().content}

Done! Press q to quit.
''');
  }
}
