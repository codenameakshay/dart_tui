import '../cmd.dart';
import '../model.dart';
import '../msg.dart' show Msg;

/// Simple determinate progress bar (0.0–1.0).
final class ProgressModel extends TeaModel {
  ProgressModel({
    required this.fraction,
    this.width = 40,
    this.label = '',
  }) : assert(fraction >= 0 && fraction <= 1, 'fraction must be 0..1');

  final double fraction;
  final int width;
  final String label;

  @override
  (TeaModel, Cmd?) update(Msg msg) => (this, null);

  @override
  String view() {
    final filled = (fraction * width).round().clamp(0, width);
    final bar = '${'#' * filled}${'.' * (width - filled)}';
    final pct = (fraction * 100).round();
    return '${label.isEmpty ? '' : '$label '}$bar $pct%';
  }
}
