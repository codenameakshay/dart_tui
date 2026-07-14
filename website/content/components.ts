import type { DocEntry } from "./registry";

export const components: DocEntry[] = [
  {
    slug: "spinner",
    name: "Spinner",
    category: "components",
    order: 1,
    featured: true,
    tagline: "Animated indeterminate activity indicator.",
    description:
      "An indeterminate activity indicator driven by `TickMsg`. Supply any list of `frames` — Braille dots, a line spinner, moons, clocks — and forward ticks to advance it.",
    gif: "spinner.gif",
    snippets: [
      {
        label: "Usage",
        lang: "dart",
        code: `import 'package:dart_tui/dart_tui.dart';

const dots = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];

final class LoadingModel extends TeaModel {
  LoadingModel({SpinnerModel? spinner})
      : spinner = spinner ?? SpinnerModel(frames: dots, prefix: 'Loading ');

  final SpinnerModel spinner;

  // Kick off the animation.
  @override
  Cmd? init() => tick(const Duration(milliseconds: 100), (_) => TickMsg());

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is TickMsg) {
      final (next, _) = spinner.update(msg);
      return (
        LoadingModel(spinner: next as SpinnerModel),
        tick(const Duration(milliseconds: 100), (_) => TickMsg()),
      );
    }
    return (this, null);
  }

  @override
  View view() => newView(spinner.view().content);
}`,
      },
    ],
    api: {
      title: "SpinnerModel",
      rows: [
        { name: "frames", type: "List<String>", description: "Animation frames cycled on each TickMsg. Defaults to the Braille dot set." },
        { name: "index", type: "int", description: "Current frame index." },
        { name: "prefix", type: "String", description: "Text rendered before the spinner glyph." },
        { name: "suffix", type: "String", description: "Text rendered after the spinner glyph." },
        { name: "styles", type: "SpinnerStyles", description: "Foreground styling for the spinner and its label." },
      ],
    },
    related: ["progress-bar", "timer"],
  },
  {
    slug: "progress-bar",
    name: "Progress bar",
    category: "components",
    order: 2,
    featured: true,
    tagline: "Determinate 0.0–1.0 progress with a filled/empty bar.",
    description:
      "A determinate progress bar. Set `fraction` between 0 and 1; it renders a `█`/`░` bar of the given `width` with a trailing percentage. Pair it with `Spring` for buttery-smooth easing between values.",
    gif: "progress_bar.gif",
    snippets: [
      {
        label: "Usage",
        lang: "dart",
        code: `final bar = ProgressModel(
  fraction: 0.65,
  width: 40,
  label: 'Downloading',
);

// Renders:  Downloading ████████████████████████░░░░░░░░░░░░ 65%
newView(bar.view().content);`,
      },
    ],
    api: {
      title: "ProgressModel",
      rows: [
        { name: "fraction", type: "double", description: "Progress from 0.0 to 1.0 (asserted in range)." },
        { name: "width", type: "int", description: "Bar width in columns. Defaults to 40." },
        { name: "label", type: "String", description: "Optional label rendered before the bar." },
        { name: "styles", type: "ProgressStyles", description: "Styling for filled cells, empty cells, label and percentage." },
      ],
    },
    related: ["spinner", "spring"],
  },
  {
    slug: "text-input",
    name: "Text input",
    category: "components",
    order: 3,
    featured: true,
    tagline: "Single-line input with cursor, validation and suggestions.",
    description:
      "A single-line text field with a visible cursor, character limit, password `EchoMode`, on-submit validation, and Tab-completion suggestions. Understands emacs/readline editing keys.",
    gif: "textinput.gif",
    snippets: [
      {
        label: "Usage",
        lang: "dart",
        code: `TextInputModel(
  placeholder: 'Type something…',
  label: 'Name',
  charLimit: 80,
  validate: (value) => value.trim().isNotEmpty,
);

// Password field:
TextInputModel(placeholder: 'Password', echoMode: EchoMode.password);`,
      },
    ],
    api: {
      title: "TextInputModel",
      rows: [
        { name: "value", type: "String", description: "Current text content." },
        { name: "cursorPos", type: "int", description: "Cursor index within value." },
        { name: "placeholder", type: "String", description: "Shown when the value is empty." },
        { name: "label", type: "String", description: "Label rendered before the field." },
        { name: "echoMode", type: "EchoMode", description: "normal or password (masked)." },
        { name: "charLimit", type: "int", description: "Max characters. 0 = unlimited." },
        { name: "validate", type: "bool Function(String)?", description: "Called on Enter; return false to reject and emit ValidationFailedMsg." },
        { name: "suggestions", type: "List<String>", description: "Tab-completion candidates." },
      ],
    },
    keybindings: [
      { keys: "ctrl+a / ctrl+e", action: "Jump to start / end of line" },
      { keys: "ctrl+b / ctrl+f", action: "Move one character left / right" },
      { keys: "alt+← / alt+→", action: "Move one word left / right" },
      { keys: "ctrl+w / alt+backspace", action: "Delete the previous word" },
    ],
    related: ["text-area", "forms"],
  },
  {
    slug: "text-area",
    name: "Text area",
    category: "components",
    order: 4,
    tagline: "Multi-line editor with scroll and word movement.",
    description:
      "A multi-line text editor with vertical scrolling, line-kill (`Ctrl+K`), word movement and the full readline binding set. Great for commit messages, notes, or any longform input.",
    gif: "textarea.gif",
    snippets: [
      {
        label: "Usage",
        lang: "dart",
        code: `TextAreaModel(
  placeholder: 'Write your message…',
  width: 60,
  maxHeight: 10,
);`,
      },
    ],
    api: {
      title: "TextAreaModel",
      rows: [
        { name: "value", type: "String", description: "Current multi-line content." },
        { name: "cursorRow / cursorCol", type: "int", description: "Cursor position." },
        { name: "width", type: "int", description: "Editor width in columns. Defaults to 60." },
        { name: "maxHeight", type: "int", description: "Visible rows before scrolling. Defaults to 10." },
        { name: "charLimit", type: "int", description: "Max characters. 0 = unlimited." },
        { name: "placeholder", type: "String", description: "Shown when empty." },
      ],
    },
    keybindings: [
      { keys: "ctrl+a / ctrl+e", action: "Start / end of line" },
      { keys: "ctrl+k", action: "Kill to end of line" },
      { keys: "alt+← / alt+→", action: "Word left / right" },
      { keys: "ctrl+w", action: "Delete previous word" },
    ],
    related: ["text-input"],
  },
  {
    slug: "select-list",
    name: "Select list",
    category: "components",
    order: 5,
    tagline: "Vertical single-choice list with a keyboard cursor.",
    description:
      "A lightweight single-selection list. Navigate with `↑↓` or `j`/`k`; optionally `wrap` the cursor at the boundaries. Embed it in a parent model to build menus and pickers.",
    gif: "list_default.gif",
    snippets: [
      {
        label: "Usage",
        lang: "dart",
        code: `SelectListModel(
  items: ['Option A', 'Option B', 'Option C'],
  title: 'Choose one',
  wrap: true,
);

// The current choice:
final choice = list.items[list.cursor];`,
      },
    ],
    api: {
      title: "SelectListModel",
      rows: [
        { name: "items", type: "List<String>", description: "Non-empty list of options." },
        { name: "cursor", type: "int", description: "Index of the highlighted item." },
        { name: "title", type: "String", description: "Optional heading above the list." },
        { name: "wrap", type: "bool", description: "Wrap the cursor past the first/last item." },
        { name: "styles", type: "ListStyles", description: "Styling for the cursor, selected and normal rows." },
      ],
    },
    keybindings: [
      { keys: "↑ / k", action: "Move up" },
      { keys: "↓ / j", action: "Move down" },
      { keys: "enter", action: "Select the highlighted item" },
    ],
    related: ["list", "multi-select"],
  },
  {
    slug: "list",
    name: "List (fuzzy filter)",
    category: "components",
    order: 6,
    featured: true,
    isNew: true,
    tagline: "Full list with incremental fuzzy filtering and descriptions.",
    description:
      "A full-featured list: incremental fuzzy/subsequence filtering, item descriptions, a status bar, viewport scrolling and per-element styling. Press `/` to filter, type to narrow, `Esc` to clear.",
    gif: "list_filter.gif",
    snippets: [
      {
        label: "Usage",
        lang: "dart",
        code: `ListModel(
  items: [
    ListItem(title: 'Apple', description: 'A crisp red fruit'),
    ListItem(title: 'Banana', description: 'A yellow tropical fruit'),
    ListItem(title: 'Cherry', description: 'A small stone fruit'),
  ],
  title: 'Fruit Picker',
  height: 8,
  showDescription: true,
  showStatusBar: true,
);`,
      },
    ],
    api: {
      title: "ListModel",
      rows: [
        { name: "items", type: "List<ListItem>", description: "Full (unfiltered) item list. Each ListItem has a title and description." },
        { name: "title", type: "String", description: "Heading shown above the list." },
        { name: "height", type: "int", description: "Visible rows (viewport height). Defaults to 10." },
        { name: "filter", type: "String", description: "Active filter query." },
        { name: "filterMode", type: "bool", description: "Whether the filter input is focused." },
        { name: "showDescription", type: "bool", description: "Render each item's description line." },
        { name: "showStatusBar", type: "bool", description: "Show the count / filter status bar." },
      ],
    },
    keybindings: [
      { keys: "↑ / k, ↓ / j", action: "Move cursor" },
      { keys: "/", action: "Enter filter mode" },
      { keys: "esc", action: "Clear filter" },
      { keys: "enter", action: "Select the highlighted item" },
    ],
    related: ["select-list", "multi-select"],
  },
  {
    slug: "tabs",
    name: "Tabs",
    category: "components",
    order: 7,
    tagline: "Tabbed interface with styled labels and a content area.",
    description:
      "A tabbed view. Provide a list of `(label, content)` records and navigate with `←`/`→`, `h`/`l` or `Tab`/`Shift+Tab`. Customise active/inactive labels, the divider and the content area via `TabsStyles`.",
    gif: "tabs.gif",
    snippets: [
      {
        label: "Usage",
        lang: "dart",
        code: `TabsModel(tabs: [
  ('Home',     'Welcome content here'),
  ('Profile',  'Name: Alice\\nEmail: alice@example.com'),
  ('Settings', 'Theme: Dark\\nFont: 14px'),
]);`,
      },
    ],
    api: {
      title: "TabsModel",
      rows: [
        { name: "tabs", type: "List<(String, String)>", description: "Non-empty list of (label, content) records." },
        { name: "activeTab", type: "int", description: "Index of the selected tab." },
        { name: "styles", type: "TabsStyles", description: "Styling for active/inactive labels, divider and content." },
      ],
    },
    keybindings: [
      { keys: "← / h, → / l", action: "Previous / next tab" },
      { keys: "tab / shift+tab", action: "Cycle tabs" },
    ],
    related: ["paginator", "viewport"],
  },
  {
    slug: "table",
    name: "Table",
    category: "components",
    order: 8,
    featured: true,
    tagline: "Scrollable data table with per-cell styling.",
    description:
      "A scrollable data table with configurable columns, fixed widths, a row cursor and per-row/per-cell styling via a `styleFunc`. Handles more rows than fit by scrolling within a fixed `height`.",
    gif: "table.gif",
    snippets: [
      {
        label: "Usage",
        lang: "dart",
        code: `TableModel(
  columns: [
    TableColumn('City', 20),
    TableColumn('Population', 12),
  ],
  rows: const [
    ['Tokyo', '37,400,068'],
    ['Delhi', '28,514,000'],
    ['Shanghai', '25,582,000'],
  ],
  height: 10,
  styles: TableStyles(
    header: const Style(isBold: true, isUnderline: true),
  ),
);`,
      },
    ],
    api: {
      title: "TableModel",
      rows: [
        { name: "columns", type: "List<TableColumn>", description: "Column definitions — each a (title, width)." },
        { name: "rows", type: "List<List<String>>", description: "Row data; one inner list per row." },
        { name: "cursor", type: "int", description: "Index of the highlighted row." },
        { name: "height", type: "int", description: "Visible rows before scrolling. Defaults to 10." },
        { name: "styles", type: "TableStyles", description: "Header style plus a styleFunc(row, col) for per-cell styling." },
      ],
    },
    keybindings: [
      { keys: "↑ / k, ↓ / j", action: "Move row cursor" },
    ],
    related: ["tree", "list"],
  },
  {
    slug: "tree",
    name: "Tree",
    category: "components",
    order: 9,
    tagline: "Hierarchical, expandable list with box-drawing connectors.",
    description:
      "A hierarchical, expandable tree rendered with Unicode box-drawing connectors. Navigate with `↑↓`/`jk`, toggle with `Enter`/`Space`, and expand/collapse with `→l`/`←h`.",
    gif: "tree.gif",
    snippets: [
      {
        label: "Usage",
        lang: "dart",
        code: `TreeModel(
  root: TreeNode(
    label: 'Languages',
    isExpanded: true,
    children: [
      TreeNode(label: 'Dart', children: [TreeNode(label: 'Flutter')]),
      TreeNode(label: 'Go', children: [TreeNode(label: 'Bubble Tea')]),
    ],
  ),
  height: 20,
);`,
      },
    ],
    api: {
      title: "TreeModel",
      rows: [
        { name: "root", type: "TreeNode", description: "Root node. Each node has a label, isExpanded flag and children." },
        { name: "cursor", type: "int", description: "Index into the flattened visible node list." },
        { name: "height", type: "int", description: "Visible rows before scrolling. Defaults to 20." },
        { name: "styles", type: "TreeStyles", description: "Styling for the cursor, labels and connectors." },
      ],
    },
    keybindings: [
      { keys: "↑ / k, ↓ / j", action: "Move cursor" },
      { keys: "→ / l", action: "Expand node" },
      { keys: "← / h", action: "Collapse node" },
      { keys: "enter / space", action: "Toggle node" },
    ],
    related: ["table", "file-picker"],
  },
  {
    slug: "multi-select",
    name: "Multi-select",
    category: "components",
    order: 10,
    isNew: true,
    tagline: "Scrollable checkbox list with select-all.",
    description:
      "A scrollable checkbox list supporting multiple concurrent selections. Navigate with `↑↓`/`jk`, toggle with `Space`/`x`, select all/none with `a`, and confirm with `Enter`.",
    gif: "multi_select.gif",
    snippets: [
      {
        label: "Usage",
        lang: "dart",
        code: `final multi = MultiSelectModel(
  title: 'Pick your languages',
  items: const [
    MultiSelectItem(label: 'Dart', value: 'dart'),
    MultiSelectItem(label: 'Go', value: 'go'),
    MultiSelectItem(label: 'Rust', value: 'rust'),
  ],
  height: 10,
  showStatusBar: true, // shows "N/Total selected"
  wrap: true,
);

// After the user presses Enter, read the checked items:
final chosen = multi.items
    .where((item) => item.selected)
    .map((item) => item.value)
    .toList();`,
      },
    ],
    api: {
      title: "MultiSelectModel",
      rows: [
        { name: "items", type: "List<MultiSelectItem>", description: "Options; each has a label, value and selected flag." },
        { name: "title", type: "String", description: "Heading above the list." },
        { name: "height", type: "int", description: "Visible rows before scrolling. Defaults to 10." },
        { name: "showStatusBar", type: "bool", description: "Show the 'N/Total selected' status bar." },
        { name: "wrap", type: "bool", description: "Wrap the cursor at list boundaries." },
      ],
    },
    keybindings: [
      { keys: "↑ / k, ↓ / j", action: "Move cursor" },
      { keys: "space / x", action: "Toggle item" },
      { keys: "a", action: "Select all / none" },
      { keys: "enter", action: "Confirm selection" },
    ],
    related: ["list", "select-list", "forms"],
  },
  {
    slug: "cursor",
    name: "Cursor",
    category: "components",
    order: 11,
    tagline: "In-line blinking cursor for custom editors.",
    description:
      "An in-line blinking cursor widget — a visible insertion point that isn't tied to the real terminal cursor. Perfect for building text editors, prompts, or any UI that needs its own caret. Choose `block`, `underline` or `bar`.",
    gif: "cursor_model.gif",
    snippets: [
      {
        label: "Usage",
        lang: "dart",
        code: `final cursor = CursorModel(
  mode: CursorMode.block, // block █, underline _, or bar |
  blink: true,            // toggles on every TickMsg
);

// Forward TickMsg to make it blink, then embed in your view:
final rendered = 'hello\${cursor.view().content}world'; // → hello█world`,
      },
    ],
    api: {
      title: "CursorModel",
      rows: [
        { name: "mode", type: "CursorMode", description: "block, underline or bar." },
        { name: "blink", type: "bool", description: "Toggle visibility on each TickMsg." },
        { name: "visible", type: "bool", description: "Current on/off state of the blink." },
        { name: "focused", type: "bool", description: "When false, the cursor renders steady." },
      ],
    },
    related: ["text-input", "text-area"],
  },
  {
    slug: "viewport",
    name: "Viewport",
    category: "components",
    order: 12,
    tagline: "Scrollable content pane with soft-wrap.",
    description:
      "A scrollable content pane with optional soft-wrapping — ideal for long text, logs or file content. Also powers the one-shot `pager()` helper.",
    gif: "pager.gif",
    snippets: [
      {
        label: "Usage",
        lang: "dart",
        code: `ViewportModel(
  content: longText,
  width: 80,
  height: 20,
  softWrap: true,
);`,
      },
    ],
    api: {
      title: "ViewportModel",
      rows: [
        { name: "content", type: "String", description: "Text to display." },
        { name: "width", type: "int", description: "Viewport width in columns. Defaults to 80." },
        { name: "height", type: "int", description: "Viewport height in rows. Defaults to 24." },
        { name: "yOffset / xOffset", type: "int", description: "Current scroll position." },
        { name: "softWrap", type: "bool", description: "Wrap long lines to the viewport width." },
      ],
    },
    keybindings: [
      { keys: "↑ / ↓, k / j", action: "Scroll line" },
      { keys: "pgup / pgdn", action: "Scroll page" },
    ],
    related: ["pager", "text-area"],
  },
  {
    slug: "timer",
    name: "Timer",
    category: "components",
    order: 13,
    tagline: "Countdown timer with start/stop/reset.",
    description:
      "A countdown timer. Give it a `duration`; drive it with `TickMsg`. Read `remaining` and `finished` to react when it hits zero.",
    gif: "timer.gif",
    snippets: [
      {
        label: "Usage",
        lang: "dart",
        code: `var timer = TimerModel(duration: const Duration(minutes: 5));

// Start it, then forward ticks in update():
timer = timer.start();
final (next, cmd) = timer.update(tickMsg);

if (timer.finished) {
  // countdown complete
}`,
      },
    ],
    api: {
      title: "TimerModel",
      rows: [
        { name: "duration", type: "Duration", description: "Total countdown length." },
        { name: "elapsed", type: "Duration", description: "Time elapsed so far." },
        { name: "running", type: "bool", description: "Whether the timer is currently ticking." },
      ],
    },
    related: ["stopwatch", "spinner"],
  },
  {
    slug: "stopwatch",
    name: "Stopwatch",
    category: "components",
    order: 14,
    tagline: "Elapsed-time stopwatch with start/stop/reset.",
    description:
      "An elapsed-time stopwatch that counts up. Call `.start()`, `.stop()` and `.reset()`, and forward `TickMsg` to advance `elapsed`.",
    gif: "stopwatch.gif",
    snippets: [
      {
        label: "Usage",
        lang: "dart",
        code: `var watch = StopwatchModel();
watch = watch.start();

// each TickMsg:
final (next, cmd) = watch.update(tickMsg);
print(next.elapsed); // Duration since start`,
      },
    ],
    api: {
      title: "StopwatchModel",
      rows: [
        { name: "elapsed", type: "Duration", description: "Accumulated elapsed time." },
        { name: "running", type: "bool", description: "Whether the stopwatch is running." },
      ],
    },
    related: ["timer"],
  },
  {
    slug: "paginator",
    name: "Paginator",
    category: "components",
    order: 15,
    tagline: "Compact page indicator (dots or numeric).",
    description:
      "A compact page indicator for multi-page flows — render it as dots or a numeric `n/total` via a custom `labelBuilder`. Navigate with `←`/`→`, `h`/`l` or `PgUp`/`PgDn`.",
    gif: "paginator.gif",
    snippets: [
      {
        label: "Usage",
        lang: "dart",
        code: `PaginatorModel(
  page: 0,
  totalPages: 5,
  // Optional custom label, e.g. "3 / 5"
  labelBuilder: (page, total) => '\${page + 1} / \$total',
);`,
      },
    ],
    api: {
      title: "PaginatorModel",
      rows: [
        { name: "page", type: "int", description: "Current page index." },
        { name: "totalPages", type: "int", description: "Total number of pages (> 0)." },
        { name: "labelBuilder", type: "String Function(int, int)?", description: "Custom renderer; defaults to dots." },
      ],
    },
    keybindings: [
      { keys: "← / h / pgup", action: "Previous page" },
      { keys: "→ / l / pgdn", action: "Next page" },
    ],
    related: ["tabs"],
  },
  {
    slug: "help",
    name: "Help",
    category: "components",
    order: 16,
    tagline: "Compact / full keybinding reference from a KeyMap.",
    description:
      "A keybinding reference panel built from a `KeyMap`. Renders a compact single-line summary or a full multi-column view, so users can always see what keys do what.",
    gif: "help.gif",
    snippets: [
      {
        label: "Usage",
        lang: "dart",
        code: `final keyMap = KeyMap([
  KeyBinding(['↑', 'k'], 'move up'),
  KeyBinding(['↓', 'j'], 'move down'),
  KeyBinding(['enter'], 'select'),
  KeyBinding(['q'], 'quit'),
]);

final help = HelpModel.fromKeyMap(keyMap);`,
      },
    ],
    api: {
      title: "HelpModel",
      rows: [
        { name: "entries", type: "List<HelpEntry>", description: "Key/description pairs. Build from a KeyMap with HelpModel.fromKeyMap." },
        { name: "title", type: "String", description: "Panel title. Defaults to 'Help'." },
        { name: "showBorder", type: "bool", description: "Draw a border around the panel." },
      ],
    },
    related: ["select-list"],
  },
  {
    slug: "file-picker",
    name: "File picker",
    category: "components",
    order: 17,
    tagline: "Async directory browser with extension filtering.",
    description:
      "An async directory browser with keyboard navigation and an optional allowed-extensions filter. Loads directory entries lazily and reports the chosen path via `selected`.",
    gif: "file_picker.gif",
    snippets: [
      {
        label: "Usage",
        lang: "dart",
        code: `FilePickerModel(
  currentDir: Directory.current,
  allowedExtensions: const ['.dart', '.yaml'],
  showHidden: false,
  height: 15,
);`,
      },
    ],
    api: {
      title: "FilePickerModel",
      rows: [
        { name: "currentDir", type: "Directory", description: "Directory currently being browsed." },
        { name: "allowedExtensions", type: "List<String>", description: "Only show files with these extensions (empty = all)." },
        { name: "showHidden", type: "bool", description: "Include dotfiles." },
        { name: "height", type: "int", description: "Visible rows before scrolling. Defaults to 15." },
        { name: "selected", type: "String?", description: "Chosen path once the user confirms." },
      ],
    },
    keybindings: [
      { keys: "↑ / k, ↓ / j", action: "Move cursor" },
      { keys: "enter", action: "Open directory or select file" },
    ],
    related: ["tree", "list"],
  },
  {
    slug: "spring",
    name: "Spring",
    category: "components",
    order: 18,
    tagline: "Harmonica-style damped-spring easing for any scalar.",
    description:
      "A damped-harmonic-oscillator for smooth, eased motion of any scalar — a progress value, a scroll offset, a cursor position. Pure math with no terminal I/O; drive it one frame per `TickMsg`. `damping < 1` overshoots, `1` is critical, `> 1` never overshoots.",
    gif: "spring.gif",
    snippets: [
      {
        label: "Usage",
        lang: "dart",
        code: `final spring = Spring(fps: 60, frequency: 6, damping: 1);
var (pos, vel) = (0.0, 0.0);
const target = 1.0;

// each TickMsg, ease toward the target:
(pos, vel) = spring.update(pos, vel, target);`,
      },
    ],
    api: {
      title: "Spring",
      rows: [
        { name: "fps", type: "int", description: "Frame rate the spring is driven at." },
        { name: "frequency", type: "double", description: "Angular frequency — higher is snappier." },
        { name: "damping", type: "double", description: "< 1 overshoots, 1 is critical, > 1 is over-damped." },
        { name: "update(pos, vel, target)", type: "(double, double)", description: "Advance one frame; returns the new (position, velocity)." },
      ],
    },
    related: ["progress-bar"],
  },
];
