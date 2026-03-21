// Run: fvm dart run example/package_manager.dart
// Simulated package installer: spinner + progress bar, one package at a time.

import 'package:dart_tui/dart_tui.dart';

const _packages = [
  'dart_tui',
  'characters',
  'async',
  'collection',
  'meta',
  'path',
  'http',
];

Future<void> main() async {
  await Program().run(PackageManagerModel());
}

final class _InstallMsg extends Msg {}

final class PackageManagerModel extends TeaModel {
  PackageManagerModel({
    this.currentIndex = 0,
    this.done = false,
    SpinnerModel? spinner,
  }) : spinner = spinner ?? SpinnerModel(suffix: ' Installing...');

  final int currentIndex;
  final bool done;
  final SpinnerModel spinner;

  bool get _installing => currentIndex < _packages.length && !done;

  @override
  Cmd? init() => _installing
      ? tick(const Duration(milliseconds: 120), (_) => TickMsg(DateTime.now()))
      : null;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is KeyMsg) {
      if (msg.key == 'ctrl+c' || msg.key == 'q') {
        return (this, () => quit());
      }
    }

    if (msg is _InstallMsg) {
      final next = currentIndex + 1;
      if (next >= _packages.length) {
        return (
          PackageManagerModel(currentIndex: next, done: true),
          println('All packages installed!'),
        );
      }
      return (
        PackageManagerModel(currentIndex: next),
        sequence([
          println('  ✓ installed ${_packages[currentIndex]}'),
          tick(const Duration(milliseconds: 120),
              (_) => TickMsg(DateTime.now())),
        ]),
      );
    }

    if (msg is TickMsg) {
      final (newSpinner, _) = spinner.update(msg);
      final nextSpinner = newSpinner as SpinnerModel;

      // Advance to next package every ~10 ticks (~1.2s)
      if (nextSpinner.index == 0 && _installing) {
        return (
          PackageManagerModel(
            currentIndex: currentIndex,
            spinner: nextSpinner,
          ),
          sequence([
            println('  ✓ installed ${_packages[currentIndex]}'),
            () => _InstallMsg(),
          ]),
        );
      }

      return (
        PackageManagerModel(
          currentIndex: currentIndex,
          spinner: nextSpinner,
        ),
        tick(const Duration(milliseconds: 120), (_) => TickMsg(DateTime.now())),
      );
    }

    return (this, null);
  }

  @override
  View view() {
    if (done) {
      return newView(
          'All ${_packages.length} packages installed.\n\nPress q to quit.');
    }

    final fraction = currentIndex / _packages.length;
    final progress = ProgressModel(
      fraction: fraction,
      width: 30,
      label: '',
    );

    final b = StringBuffer('Installing packages...\n\n');
    b.writeln(
        '  ${spinner.view().content} ${_packages[currentIndex > _packages.length - 1 ? _packages.length - 1 : currentIndex]}');
    b.writeln();
    b.writeln('  ${progress.view().content}');
    b.writeln('  $currentIndex/${_packages.length} packages');
    b.writeln('\nPress q to quit.');
    return newView(b.toString());
  }
}
