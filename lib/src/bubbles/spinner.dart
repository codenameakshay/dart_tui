import '../cmd.dart';
import '../model.dart';
import '../msg.dart';
import '../view.dart';

/// Indeterminate spinner driven by [TickMsg].
final class SpinnerModel extends TeaModel {
  SpinnerModel({
    this.frames = const ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'],
    this.index = 0,
    this.prefix = '',
    this.suffix = '',
  });

  final List<String> frames;
  final int index;
  final String prefix;
  final String suffix;

  @override
  (TeaModel, Cmd?) update(Msg msg) {
    if (msg is TickMsg && frames.isNotEmpty) {
      return (
        SpinnerModel(
          frames: frames,
          index: (index + 1) % frames.length,
          prefix: prefix,
          suffix: suffix,
        ),
        null,
      );
    }
    return (this, null);
  }

  @override
  View view() {
    if (frames.isEmpty) return newView('$prefix $suffix');
    return newView('$prefix${frames[index]}$suffix');
  }
}
