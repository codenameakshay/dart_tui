import '../cmd.dart';
import '../model.dart';
import '../msg.dart';
import '../view.dart';
import 'key_map.dart';

typedef HelpEntry = ({String key, String description});

final class HelpModel extends TeaModel {
  HelpModel({
    required this.entries,
    this.title = 'Help',
    this.showBorder = false,
  });

  /// Construct a [HelpModel] from a [KeyMap], pulling help text from enabled
  /// bindings only.
  factory HelpModel.fromKeyMap(
    KeyMap map, {
    String title = 'Help',
    bool showBorder = false,
  }) {
    final entries = map.bindings
        .where((b) => b.enabled)
        .map((b) => b.help)
        .toList();
    return HelpModel(entries: entries, title: title, showBorder: showBorder);
  }

  final List<HelpEntry> entries;
  final String title;
  final bool showBorder;

  @override
  (TeaModel, Cmd?) update(Msg msg) => (this, null);

  @override
  View view() {
    final b = StringBuffer();
    if (showBorder) {
      b.writeln('┌─ $title ─');
    } else {
      b.writeln(title);
    }
    for (final entry in entries) {
      b.writeln('  ${entry.key.padRight(12)} ${entry.description}');
    }
    if (showBorder) {
      b.write('└${'─' * 24}');
    }
    return newView(b.toString());
  }
}
