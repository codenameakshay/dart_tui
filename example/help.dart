// Ported from charmbracelet/bubbletea examples/help
import 'package:dart_tui/dart_tui.dart';

final class _HelpKeys implements KeyMap {
  const _HelpKeys();
  static const up = KeyBinding(
    keys: ['up', 'k'],
    help: (key: '↑/k', description: 'move up'),
  );
  static const down = KeyBinding(
    keys: ['down', 'j'],
    help: (key: '↓/j', description: 'move down'),
  );
  static const left = KeyBinding(
    keys: ['left', 'h'],
    help: (key: '←/h', description: 'prev page'),
  );
  static const right = KeyBinding(
    keys: ['right', 'l'],
    help: (key: '→/l', description: 'next page'),
  );
  static const helpKey = KeyBinding(
    keys: ['?'],
    help: (key: '?', description: 'toggle help'),
  );
  static const quit = KeyBinding(
    keys: ['q', 'ctrl+c'],
    help: (key: 'q', description: 'quit'),
  );

  @override
  List<KeyBinding> get bindings => [up, down, left, right, helpKey, quit];
}

const _keys = _HelpKeys();

Future<void> main() async {
  await Program().run(HelpExampleModel());
}

final class HelpExampleModel extends TeaModel {
  HelpExampleModel({
    this.showFullHelp = false,
    this.width = 80,
    this.height = 24,
  });
  final bool showFullHelp;
  final int width;
  final int height;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is WindowSizeMsg) {
      return (
        HelpExampleModel(
          showFullHelp: showFullHelp,
          width: msg.width,
          height: msg.height,
        ),
        null,
      );
    }
    if (msg is KeyMsg) {
      switch (msg.key) {
        case 'q':
        case 'ctrl+c':
          return (this, () => quit());
        case '?':
          return (
            HelpExampleModel(
              showFullHelp: !showFullHelp,
              width: width,
              height: height,
            ),
            null,
          );
      }
    }
    return (this, null);
  }

  @override
  View view() {
    final helpModel = HelpModel.fromKeyMap(_keys);
    final b = StringBuffer();
    b.writeln(const Style().bold().render('Help Example'));
    b.writeln();
    b.writeln('This demo shows a keybinding help system.');
    b.writeln(
      'Use the keys below to navigate (nothing to navigate here, but still).',
    );
    b.writeln();
    if (showFullHelp) {
      b.writeln(const Style().bold().render('Keybindings:'));
      b.writeln();
      b.write(helpModel.view().content);
    } else {
      // Compact: show single line
      final compact = _keys.bindings
          .map((binding) => '${binding.help.key}: ${binding.help.description}')
          .join('  •  ');
      b.write(const Style().dim().render(compact));
    }
    return newView(b.toString());
  }
}
