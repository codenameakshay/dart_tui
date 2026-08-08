import 'dart:io';

import 'view.dart';

/// Applies terminal-wide state declared by a [View].
///
/// This state is separate from frame content: a view can change terminal
/// colors or native progress while its text remains identical.
final class TerminalViewState {
  int? _foregroundColor;
  int? _backgroundColor;
  (ProgressBarState, int)? _progress;

  void apply(IOSink output, View view) {
    _applyColor(
      output,
      next: view.foregroundColor,
      previous: _foregroundColor,
      osc: 10,
      resetOsc: 110,
    );
    _foregroundColor = view.foregroundColor;

    _applyColor(
      output,
      next: view.backgroundColor,
      previous: _backgroundColor,
      osc: 11,
      resetOsc: 111,
    );
    _backgroundColor = view.backgroundColor;

    final nextProgress = _normalizeProgress(view.progressBar);
    if (nextProgress != _progress) {
      output.write(_progressSequence(nextProgress));
      _progress = nextProgress;
    }
  }

  void reset(IOSink output) {
    if (_foregroundColor != null) output.write('\x1b]110\x07');
    if (_backgroundColor != null) output.write('\x1b]111\x07');
    if (_progress != null) output.write('\x1b]9;4;0\x07');
    _foregroundColor = null;
    _backgroundColor = null;
    _progress = null;
  }

  static void _applyColor(
    IOSink output, {
    required int? next,
    required int? previous,
    required int osc,
    required int resetOsc,
  }) {
    if (next == previous) return;
    if (next == null) {
      output.write('\x1b]$resetOsc\x07');
      return;
    }
    final hex = (next & 0xffffff).toRadixString(16).padLeft(6, '0');
    output.write('\x1b]$osc;#$hex\x07');
  }

  static (ProgressBarState, int)? _normalizeProgress(ProgressBar? progress) {
    if (progress == null || progress.state == ProgressBarState.none) {
      return null;
    }
    final value = progress.value.clamp(0, 100);
    return (progress.state, value);
  }

  static String _progressSequence((ProgressBarState, int)? progress) {
    if (progress == null) return '\x1b]9;4;0\x07';
    final (state, value) = progress;
    return switch (state) {
      ProgressBarState.none => '\x1b]9;4;0\x07',
      ProgressBarState.normal => '\x1b]9;4;1;$value\x07',
      ProgressBarState.error => '\x1b]9;4;2;$value\x07',
      ProgressBarState.indeterminate => '\x1b]9;4;3\x07',
      ProgressBarState.warning => '\x1b]9;4;4;$value\x07',
    };
  }
}
