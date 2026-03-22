import '../cmd.dart';
import '../model.dart';
import '../msg.dart';
import '../view.dart';
import 'key_map.dart';
import 'style.dart';

typedef HelpEntry = ({String key, String description});

/// Style configuration for [HelpModel].
final class HelpStyles {
  const HelpStyles({
    this.title = const Style(),
    this.key = const Style(),
    this.description = const Style(),
    this.separator = const Style(),
  });

  /// Applied to the title / header.
  final Style title;

  /// Applied to key binding labels.
  final Style key;

  /// Applied to key binding descriptions.
  final Style description;

  /// Applied to border separator lines (when [HelpModel.showBorder] is true).
  final Style separator;

  /// Beautiful defaults using the Catppuccin Mocha palette.
  static const HelpStyles defaults = HelpStyles(
    title: Style(
      foregroundRgb: RgbColor(203, 166, 247), // Mauve
      isBold: true,
    ),
    key: Style(
      foregroundRgb: RgbColor(203, 166, 247), // Mauve
      isBold: true,
    ),
    description: Style(
      foregroundRgb: RgbColor(166, 173, 200), // Subtext0
      isDim: true,
    ),
    separator: Style(
      foregroundRgb: RgbColor(88, 91, 112), // Surface2
    ),
  );
}

final class HelpModel extends TeaModel {
  HelpModel({
    required this.entries,
    this.title = 'Help',
    this.showBorder = false,
    this.styles = HelpStyles.defaults,
  });

  /// Construct a [HelpModel] from a [KeyMap], pulling help text from enabled
  /// bindings only.
  factory HelpModel.fromKeyMap(
    KeyMap map, {
    String title = 'Help',
    bool showBorder = false,
    HelpStyles styles = HelpStyles.defaults,
  }) {
    final entries =
        map.bindings.where((b) => b.enabled).map((b) => b.help).toList();
    return HelpModel(
      entries: entries,
      title: title,
      showBorder: showBorder,
      styles: styles,
    );
  }

  final List<HelpEntry> entries;
  final String title;
  final bool showBorder;
  final HelpStyles styles;

  @override
  (TeaModel, Cmd?) update(Msg msg) => (this, null);

  @override
  View view() {
    final b = StringBuffer();
    if (showBorder) {
      b.writeln(styles.separator.render('┌─ ${styles.title.render(title)} ─'));
    } else {
      b.writeln(styles.title.render(title));
    }
    for (final entry in entries) {
      final keyStr = styles.key.render(entry.key.padRight(12));
      final descStr = styles.description.render(entry.description);
      b.writeln('  $keyStr  $descStr');
    }
    if (showBorder) {
      b.write(styles.separator.render('└${'─' * 24}'));
    }
    return newView(b.toString());
  }
}
