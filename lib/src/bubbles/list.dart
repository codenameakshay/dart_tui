import '../cmd.dart';
import '../model.dart';
import '../msg.dart';
import '../view.dart';
import 'style.dart';

/// A single item in a [ListModel].
final class ListItem {
  const ListItem({
    required this.title,
    this.description = '',
    this.filterValue = '',
  });

  /// Primary label displayed in the list.
  final String title;

  /// Optional secondary text shown below [title].
  final String description;

  /// Custom value used for fuzzy filtering. Defaults to [title] when empty.
  final String filterValue;

  String get _filterKey => filterValue.isNotEmpty ? filterValue : title;
}

/// Style configuration for [ListModel].
final class FullListStyles {
  const FullListStyles({
    this.title = const Style(),
    this.selectedTitle = const Style(),
    this.normalTitle = const Style(),
    this.description = const Style(),
    this.cursor = const Style(),
    this.filterPrompt = const Style(),
    this.filterInput = const Style(),
    this.statusBar = const Style(),
    this.noResults = const Style(),
  });

  /// Applied to the list header/title.
  final Style title;

  /// Applied to the selected item's title.
  final Style selectedTitle;

  /// Applied to unselected items' titles.
  final Style normalTitle;

  /// Applied to item description lines.
  final Style description;

  /// Applied to the cursor character (`›`).
  final Style cursor;

  /// Applied to the `/` filter prompt prefix.
  final Style filterPrompt;

  /// Applied to the filter input text.
  final Style filterInput;

  /// Applied to the status bar (`x/y` count line).
  final Style statusBar;

  /// Applied when no items match the filter.
  final Style noResults;

  /// Beautiful defaults using the Catppuccin Mocha palette.
  static const FullListStyles defaults = FullListStyles(
    title: Style(
      foregroundRgb: RgbColor(205, 214, 244),
      isBold: true,
    ),
    selectedTitle: Style(
      foregroundRgb: RgbColor(30, 30, 46),
      backgroundRgb: RgbColor(203, 166, 247), // Mauve
      isBold: true,
    ),
    normalTitle: Style(
      foregroundRgb: RgbColor(205, 214, 244),
    ),
    description: Style(
      foregroundRgb: RgbColor(166, 173, 200), // Subtext0
      isDim: true,
    ),
    cursor: Style(
      foregroundRgb: RgbColor(203, 166, 247), // Mauve
      isBold: true,
    ),
    filterPrompt: Style(
      foregroundRgb: RgbColor(137, 180, 250), // Blue
      isBold: true,
    ),
    filterInput: Style(
      foregroundRgb: RgbColor(205, 214, 244),
    ),
    statusBar: Style(
      foregroundRgb: RgbColor(88, 91, 112), // Surface2
      isDim: true,
    ),
    noResults: Style(
      foregroundRgb: RgbColor(166, 173, 200),
      isDim: true,
    ),
  );
}

/// A scrollable list with keyboard navigation and incremental text filtering.
///
/// Keyboard shortcuts:
/// - `↑` / `k`: move cursor up
/// - `↓` / `j`: move cursor down
/// - `/`: enter filter mode
/// - `Esc` or `ctrl+c` in filter mode: clear filter and exit filter mode
/// - Backspace in filter mode: delete last filter character
/// - Any printable key in filter mode: append to filter
/// - `Enter`: (propagated to parent model for selection handling)
///
/// Typical embedding:
/// ```dart
/// (TeaModel, Cmd?) update(Msg msg) {
///   final (nextList, cmd) = listModel.update(msg);
///   listModel = nextList as ListModel;
///   if (msg is KeyMsg && msg.key == 'enter') {
///     handleSelection(listModel.selected);
///   }
///   return (this.copyWith(list: listModel), cmd);
/// }
/// ```
final class ListModel extends TeaModel {
  ListModel({
    required this.items,
    this.cursor = 0,
    this.title = '',
    this.height = 10,
    this.filter = '',
    this.filterMode = false,
    this.styles = FullListStyles.defaults,
    this.showStatusBar = true,
    this.showDescription = true,
  });

  /// The full list of items (unfiltered).
  final List<ListItem> items;

  /// Cursor position within [filteredItems].
  final int cursor;

  /// Optional list title displayed above the item list.
  final String title;

  /// Maximum number of item rows to show at once (viewport height).
  final int height;

  /// Current filter query string.
  final String filter;

  /// Whether the user is currently typing a filter query.
  final bool filterMode;

  final FullListStyles styles;

  /// Whether to render the status bar (`x/y items`).
  final bool showStatusBar;

  /// Whether to render item descriptions.
  final bool showDescription;

  // ── Derived state ──────────────────────────────────────────────────────────

  /// Items that match the current [filter] query (fuzzy, case-insensitive).
  List<ListItem> get filteredItems {
    if (filter.isEmpty) return items;
    final q = filter.toLowerCase();
    return items.where((item) {
      return _fuzzyMatch(item._filterKey.toLowerCase(), q);
    }).toList();
  }

  /// The currently highlighted item, or null if the list is empty.
  ListItem? get selected {
    final fi = filteredItems;
    if (fi.isEmpty) return null;
    return fi[cursor.clamp(0, fi.length - 1)];
  }

  int get _safeCursor {
    final fi = filteredItems;
    if (fi.isEmpty) return 0;
    return cursor.clamp(0, fi.length - 1);
  }

  // ── Update ─────────────────────────────────────────────────────────────────

  @override
  (TeaModel, Cmd?) update(Msg msg) {
    if (msg is! KeyMsg) return (this, null);
    final fi = filteredItems;

    if (filterMode) {
      return _updateFilterMode(msg, fi);
    }

    switch (msg.key) {
      case 'up':
      case 'k':
        final cur = _safeCursor;
        return (_copy(cursor: cur > 0 ? cur - 1 : 0), null);
      case 'down':
      case 'j':
        final cur = _safeCursor;
        return (
          _copy(cursor: cur < fi.length - 1 ? cur + 1 : fi.length - 1),
          null,
        );
      case '/':
        return (_copy(filterMode: true), null);
      case 'esc':
      case 'ctrl+c':
        if (filter.isNotEmpty) {
          return (_copy(filter: '', filterMode: false, cursor: 0), null);
        }
        return (this, null);
      default:
        return (this, null);
    }
  }

  (TeaModel, Cmd?) _updateFilterMode(KeyMsg msg, List<ListItem> fi) {
    switch (msg.key) {
      case 'esc':
        return (_copy(filterMode: false, filter: '', cursor: 0), null);
      case 'backspace':
        if (filter.isEmpty) {
          return (_copy(filterMode: false), null);
        }
        final newFilter = filter.substring(0, filter.length - 1);
        return (
          _copy(filter: newFilter, cursor: 0, filterMode: true),
          null,
        );
      case 'enter':
        return (_copy(filterMode: false), null);
      default:
        // Append printable characters to filter
        final key = msg.key;
        if (key.length == 1 && !key.startsWith('\x1b')) {
          final newFilter = filter + key;
          return (_copy(filter: newFilter, cursor: 0, filterMode: true), null);
        }
        return (this, null);
    }
  }

  ListModel _copy({
    int? cursor,
    String? filter,
    bool? filterMode,
  }) {
    return ListModel(
      items: items,
      cursor: cursor ?? _safeCursor,
      title: title,
      height: height,
      filter: filter ?? this.filter,
      filterMode: filterMode ?? this.filterMode,
      styles: styles,
      showStatusBar: showStatusBar,
      showDescription: showDescription,
    );
  }

  // ── View ───────────────────────────────────────────────────────────────────

  @override
  View view() {
    final b = StringBuffer();
    final fi = filteredItems;
    final cur = _safeCursor;

    // Title
    if (title.isNotEmpty) {
      b.writeln(styles.title.render(title));
      b.writeln();
    }

    // Filter bar
    if (filterMode || filter.isNotEmpty) {
      final prompt = styles.filterPrompt.render('/');
      final input = styles.filterInput.render(filter);
      final caret = filterMode ? '█' : '';
      b.writeln('$prompt $input$caret');
      b.writeln();
    }

    // Items (paginated viewport)
    if (fi.isEmpty) {
      b.writeln(styles.noResults.render('  No results'));
    } else {
      // Determine viewport scroll offset
      final viewportStart = _viewportStart(cur, fi.length, height);
      final viewportEnd =
          (viewportStart + height).clamp(0, fi.length);

      for (var i = viewportStart; i < viewportEnd; i++) {
        final item = fi[i];
        if (i == cur) {
          b.write('${styles.cursor.render('›')} ');
          b.writeln(styles.selectedTitle.render(item.title));
          if (showDescription && item.description.isNotEmpty) {
            b.writeln('  ${styles.description.render(item.description)}');
          }
        } else {
          b.write('  ');
          b.writeln(styles.normalTitle.render(item.title));
          if (showDescription && item.description.isNotEmpty) {
            b.writeln('  ${styles.description.render(item.description)}');
          }
        }
      }
    }

    // Status bar
    if (showStatusBar) {
      final total = items.length;
      final shown = fi.length;
      final label = filter.isNotEmpty
          ? '$shown/$total items'
          : '$total items';
      b.write(styles.statusBar.render(label));
    }

    return newView(b.toString());
  }

  /// Returns the viewport's starting index to keep [cursor] visible.
  static int _viewportStart(int cursor, int total, int height) {
    if (total <= height) return 0;
    // Center the cursor in the viewport when possible
    final ideal = cursor - height ~/ 2;
    return ideal.clamp(0, total - height);
  }
}

// ── Fuzzy matching ─────────────────────────────────────────────────────────────

/// Returns `true` if all characters of [query] appear in [text] in order
/// (case-insensitive subsequence match — the same algorithm used by most fuzzy
/// finders).
bool _fuzzyMatch(String text, String query) {
  if (query.isEmpty) return true;
  var ti = 0;
  var qi = 0;
  while (ti < text.length && qi < query.length) {
    if (text[ti] == query[qi]) {
      qi++;
    }
    ti++;
  }
  return qi == query.length;
}
