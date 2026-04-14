import '../cmd.dart';
import '../model.dart';
import '../msg.dart';
import '../view.dart';
import 'style.dart';

/// Style configuration for [TabsModel].
final class TabsStyles {
  const TabsStyles({
    this.activeTab = const Style(),
    this.inactiveTab = const Style(),
    this.divider = const Style(),
    this.content = const Style(),
  });

  /// Applied to the currently active tab label.
  final Style activeTab;

  /// Applied to inactive tab labels.
  final Style inactiveTab;

  /// Applied to the divider character between tabs (`│`).
  final Style divider;

  /// Applied to the content area below the tab bar.
  final Style content;

  /// Beautiful defaults using the Catppuccin Mocha palette.
  static const TabsStyles defaults = TabsStyles(
    activeTab: Style(
      foregroundRgb: RgbColor(203, 166, 247), // Mauve
      isBold: true,
      isUnderline: true,
    ),
    inactiveTab: Style(
      foregroundRgb: RgbColor(166, 173, 200), // Subtext0
      isDim: true,
    ),
    divider: Style(
      foregroundRgb: RgbColor(88, 91, 112), // Surface2
    ),
    content: Style(
      foregroundRgb: RgbColor(205, 214, 244), // Text
    ),
  );
}

/// A tabbed-interface component.
///
/// [tabs] is a list of `(label, content)` pairs. Navigate with `←/→`, `h/l`,
/// or `Tab`. The parent model should render [view] and forward [update] for all
/// key events.
///
/// Example:
/// ```dart
/// TabsModel(tabs: [
///   ('Home', 'Welcome!'),
///   ('Settings', 'Config here'),
/// ])
/// ```
final class TabsModel extends TeaModel {
  TabsModel({
    required this.tabs,
    this.activeTab = 0,
    this.styles = TabsStyles.defaults,
  }) : assert(tabs.isNotEmpty, 'tabs must not be empty');

  final List<(String label, String content)> tabs;
  final int activeTab;
  final TabsStyles styles;

  int get _safeActive => activeTab.clamp(0, tabs.length - 1);

  @override
  (TeaModel, Cmd?) update(Msg msg) {
    if (msg is! KeyMsg) return (this, null);
    final cur = _safeActive;
    switch (msg.key) {
      case 'left':
      case 'h':
        final next = cur > 0 ? cur - 1 : 0;
        return (TabsModel(tabs: tabs, activeTab: next, styles: styles), null);
      case 'right':
      case 'l':
        final next = cur < tabs.length - 1 ? cur + 1 : tabs.length - 1;
        return (TabsModel(tabs: tabs, activeTab: next, styles: styles), null);
      case 'tab':
        final next = (cur + 1) % tabs.length;
        return (TabsModel(tabs: tabs, activeTab: next, styles: styles), null);
      case 'shift+tab':
        final next = (cur - 1 + tabs.length) % tabs.length;
        return (TabsModel(tabs: tabs, activeTab: next, styles: styles), null);
      default:
        return (this, null);
    }
  }

  /// Returns the rendered tab bar string.
  String tabBar() {
    final b = StringBuffer();
    final cur = _safeActive;
    for (var i = 0; i < tabs.length; i++) {
      final (label, _) = tabs[i];
      if (i == cur) {
        b.write(' ${styles.activeTab.render(label)} ');
      } else {
        b.write(' ${styles.inactiveTab.render(label)} ');
      }
      if (i < tabs.length - 1) {
        b.write(styles.divider.render('│'));
      }
    }
    return b.toString();
  }

  /// Returns the content for the active tab.
  String activeContent() {
    final cur = _safeActive;
    final (_, content) = tabs[cur];
    return content;
  }

  @override
  View view() {
    final divider = '─' * 40;
    return newView('${tabBar()}\n$divider\n\n${activeContent()}');
  }
}
