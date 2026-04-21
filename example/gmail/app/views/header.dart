import '../../util/theme.dart';
import '../../util/width.dart';
import '../tabs.dart';

/// Rendered header: title on left, tabs inline, custom-search badge.
/// Returns 2 lines (title row + tab row). Tab bounds are tracked in [outBounds]
/// so the model can do mouse hit-testing: `[(x0, x1, tabIndex), …]`.
String renderHeader({
  required int width,
  required int activeTab,
  required String customQuery,
  required List<(int, int, int)> outBounds,
}) {
  outBounds.clear();
  const title = '  $iMail  Gmail TUI  ';
  final lead = sTitleBar.render(title);
  final tabs = StringBuffer();
  var x = displayWidth(title);
  for (var i = 0; i < kTabs.length; i++) {
    final t = kTabs[i];
    final isActive = i == activeTab;
    final chip = ' ${t.hotkey} ${t.label} ';
    final rendered =
        isActive ? sTabActive.render(chip) : sTabInactive.render(chip);
    outBounds.add((x, x + displayWidth(chip), i));
    tabs.write(rendered);
    x += displayWidth(chip);
  }

  // Custom search badge (-1 = synthetic tab for search results).
  if (activeTab == -1 && customQuery.isNotEmpty) {
    final chip = ' $iSearch ${_truncate(customQuery, 30)} ';
    outBounds.add((x, x + displayWidth(chip), -1));
    tabs.write(sTabActive.render(chip));
    x += displayWidth(chip);
  }

  final pad = (width - x).clamp(0, 9999);
  final line1 = lead + tabs.toString() + ' ' * pad;
  final line2 = sBorder.render('─' * width);
  return '$line1\n$line2';
}

String _truncate(String s, int w) {
  if (displayWidth(s) <= w) return s;
  return fitRight(s, w);
}
