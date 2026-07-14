// Ported from charmbracelet/bubbletea examples/focus-blur
import 'package:dart_tui/dart_tui.dart';

Future<void> main() async {
  await Program().run(FocusBlurModel());
}

final class FocusBlurModel extends TeaModel {
  FocusBlurModel({this.focused = true});
  final bool focused;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is KeyMsg) {
      if (msg.key == 'q' || msg.key == 'ctrl+c') return (this, () => quit());
    }
    if (msg is FocusMsg) return (FocusBlurModel(focused: true), null);
    if (msg is BlurMsg) return (FocusBlurModel(focused: false), null);
    return (this, null);
  }

  @override
  View view() {
    final v = View();
    v.reportFocus = true;
    final statusStyle = focused
        ? const Style().foregroundColor256(82)
        : const Style().foregroundColor256(196).dim();
    final status = statusStyle.render(focused ? '● Focused' : '○ Blurred');
    v.content = 'Focus/Blur Detection\n\n'
        '$status\n\n'
        'Click on the terminal window to focus/unfocus.\n\n'
        'q: quit';
    return v;
  }
}
