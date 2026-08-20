import type { DocEntry } from "./registry";

export const guides: DocEntry[] = [
  {
    slug: "installation",
    name: "Installation",
    category: "guides",
    order: 1,
    featured: true,
    tagline: "Add dart_tui to your project and render your first view.",
    description:
      "dart_tui is a pure-Dart package on pub.dev with no native build step. Add it, import it, and run a `Program`.",
    blocks: [
      { type: "heading", text: "Add the dependency" },
      { type: "prose", md: "Add dart_tui to your `pubspec.yaml`:" },
      {
        type: "code",
        lang: "yaml",
        code: `dependencies:\n  dart_tui: ^2.0.0`,
      },
      { type: "prose", md: "Then fetch it:" },
      { type: "code", lang: "bash", code: `dart pub get` },
      { type: "prose", md: "Or add it in one command:" },
      { type: "code", lang: "bash", code: `dart pub add dart_tui` },
      { type: "heading", text: "Requirements" },
      {
        type: "prose",
        md: "dart_tui targets the **Dart SDK ≥ 3.5**. It runs on macOS, Linux and Windows terminals (Windows console mode is handled via `kernel32`).",
      },
      { type: "heading", text: "Quick start" },
      {
        type: "prose",
        md: "Every app is a `Program` running a `Model`. Here's a self-contained counter that ticks once a second and quits at 5:",
      },
      {
        type: "code",
        lang: "dart",
        code: `import 'package:dart_tui/dart_tui.dart';

void main() async {
  await Program(
    options: [withAltScreen()],
  ).run(CounterModel());
}

final class CounterModel extends Model {
  CounterModel({this.count = 0});
  final int count;

  @override
  Cmd? init() => tick(const Duration(seconds: 1), (_) => _TickMsg());

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is _TickMsg) {
      if (count >= 5) return (this, () => quit());
      return (CounterModel(count: count + 1),
          tick(const Duration(seconds: 1), (_) => _TickMsg()));
    }
    if (msg is KeyMsg && (msg.key == 'q' || msg.key == 'ctrl+c')) {
      return (this, () => quit());
    }
    return (this, null);
  }

  @override
  View view() => newView('Count: $count\\n\\nPress q to quit.');
}

final class _TickMsg extends Msg {}`,
      },
      {
        type: "callout",
        variant: "note",
        md: "Next: learn how `Model`, `update` and `view` fit together in the [Model–Update–View](/guides/mvu-architecture) guide.",
      },
    ],
    related: ["mvu-architecture", "commands"],
  },
  {
    slug: "mvu-architecture",
    name: "Model–Update–View",
    category: "guides",
    order: 2,
    featured: true,
    tagline: "The Elm-style architecture at the heart of dart_tui.",
    description:
      "dart_tui uses the same architecture as Elm and Bubble Tea: immutable state, a pure update function, and a pure view. This makes UIs predictable and trivially testable.",
    blocks: [
      { type: "heading", text: "The loop" },
      {
        type: "code",
        lang: "text",
        code: `┌──────────────┐   Msg    ┌──────────────┐
│    Model     │ ──────▶  │    update    │
│  (your state)│          │  (pure fn)   │
└──────────────┘          └──────┬───────┘
        ▲                        │ (Model, Cmd?)
        │                        ▼
        │                 ┌──────────────┐
        └──── render ───  │     view     │
                          │  (pure fn)   │
                          └──────────────┘`,
      },
      { type: "heading", text: "The pieces" },
      {
        type: "table",
        headers: ["Concept", "Description"],
        rows: [
          ["Model", "Immutable state. Implement init(), update(Msg) and view()."],
          ["Msg", "A tagged event: key press, window resize, tick or custom data."],
          ["Cmd", "FutureOr<Msg?> Function() — an async side-effect that delivers one message back."],
          ["View", "Declared output string plus optional cursor position, mouse mode and window title."],
          ["Program", "Owns the event loop, terminal raw mode, renderer and signal handling."],
        ],
      },
      {
        type: "prose",
        md: "`update` is a **pure function**: given the current model and a message, it returns a new model and an optional command. It never mutates state or touches the terminal directly — that's what makes it testable.",
      },
      { type: "heading", text: "Returning a value (prompt-style)" },
      {
        type: "prose",
        md: "A model can implement `OutcomeModel<T>` to return a value when it exits — the basis for prompts:",
      },
      {
        type: "code",
        lang: "dart",
        code: `abstract class OutcomeModel<T> implements Model {
  T? get outcome; // non-null → program exits and returns this value
}

final String? result = await Program().runForResult<String>(MyPromptModel());`,
      },
      {
        type: "callout",
        variant: "note",
        md: "Implicit default stdin supports one `Program` lifecycle per process. Keep multi-step interaction inside one `Program` / `Form`, or pass an explicit stream with `withInput(...)` when you manage input yourself.",
      },
      {
        type: "callout",
        variant: "note",
        md: "Because `update` is pure, you can unit-test your UI by feeding it messages and asserting on the returned model — no terminal required.",
      },
    ],
    related: ["installation", "commands", "architecture"],
  },
  {
    slug: "commands",
    name: "Commands",
    category: "guides",
    order: 3,
    tagline: "Run async work and control the terminal with Cmd.",
    description:
      "A `Cmd` is a `FutureOr<Msg?> Function()` — fire-and-forget async work whose result arrives back as the next message. Commands are how you do timers, HTTP, subprocesses and terminal control without breaking purity.",
    blocks: [
      { type: "heading", text: "Built-in helpers" },
      {
        type: "code",
        lang: "dart",
        code: `Msg quit()
Msg interrupt()
Cmd tick(Duration d, Msg Function(DateTime) fn)       // one-shot delay
Cmd every(Duration d, Msg Function(DateTime) fn)      // repeating, wall-clock aligned
Cmd? batch(List<Cmd?> cmds)                           // concurrent
Cmd? sequence(List<Cmd?> cmds)                        // sequential
Cmd execProcess(String exe, List<String> args, {...}) // external process
Cmd requestBackgroundColor()                          // fire OSC 11 query manually`,
      },
      { type: "heading", text: "Terminal control" },
      {
        type: "code",
        lang: "dart",
        code: `Msg enterAltScreen()       // switch to alt screen buffer
Msg exitAltScreen()        // return to primary screen
Msg hideCursor()           // hide terminal cursor
Msg showCursor()           // show terminal cursor
Cmd setWindowTitle(title)  // set window/tab title via OSC
Msg clearScrollArea()      // clear screen and scrollback
Cmd scrollUp([int n = 1])  // scroll viewport up n lines
Cmd scrollDown([int n = 1])// scroll viewport down n lines`,
      },
      {
        type: "callout",
        variant: "note",
        md: "Commands are fire-and-forget: dart_tui runs them off the event loop and enqueues their returned `Msg` when they complete. Return `batch([...])` to run several at once, or `sequence([...])` to chain them.",
      },
    ],
    related: ["mvu-architecture", "program-options"],
  },
  {
    slug: "program-options",
    name: "Program options",
    category: "guides",
    order: 4,
    tagline: "Configure the runtime — alt screen, mouse, FPS, focus and more.",
    description:
      "Configure a `Program` with one composable `options` list for renderer behavior, input tracking and message filtering.",
    blocks: [
      { type: "heading", text: "Configuring a Program" },
      {
        type: "code",
        lang: "dart",
        code: `Program(
  options: [
    withFps(60),              // default 60, max 120
    withCellRenderer(),       // cell-level diff (less flicker on older terminals)
    withAltScreen(),          // enter alternate screen buffer
    withHideCursor(),         // hide terminal cursor
    withTickInterval(const Duration(milliseconds: 100)), // global tick rate
    withMouseCellMotion(),    // enable button-event mouse tracking
    withMouseAllMotion(),     // enable all-motion mouse tracking
    withReportFocus(),        // enable focus/blur reporting (FocusMsg / BlurMsg)
    withWindowSize(120, 40),  // inject a fixed window size (useful in tests)
    withLogFile(File('debug.log')), // append renderer output to a file
    withFilter((model, msg) { // intercept / transform messages
      if (msg is QuitMsg) return null; // suppress
      return msg;
    }),
  ],
).run(MyModel());`,
      },
      {
        type: "table",
        headers: ["Option", "Effect"],
        rows: [
          ["withFps(n)", "Cap screen output frame rate (default 60, max 120)."],
          ["withCellRenderer()", "Use the cell-level diff renderer for older terminals."],
          ["withAltScreen()", "Render on the alternate screen buffer."],
          ["withHideCursor()", "Hide the terminal cursor."],
          ["withTickInterval(duration)", "Deliver TickMsg values on a fixed interval."],
          ["withMouseCellMotion() / withMouseAllMotion()", "Enable mouse tracking."],
          ["withReportFocus()", "Deliver FocusMsg / BlurMsg on focus changes."],
          ["withWindowSize(w, h)", "Inject a fixed window size (handy in tests)."],
          ["withLogFile(file)", "Append renderer output to a file."],
          ["withFilter(fn)", "Intercept, transform or suppress messages globally."],
        ],
      },
    ],
    related: ["commands", "architecture"],
  },
  {
    slug: "styling",
    name: "Styling",
    category: "guides",
    order: 5,
    featured: true,
    tagline: "Lipgloss-inspired, composable, immutable text styling.",
    description:
      "All styling is composable and immutable, inspired by Lipgloss. Compose a `Style` with colors, attributes, borders, padding, width and alignment, then `.render(text)`.",
    gif: "border_style.gif",
    blocks: [
      { type: "heading", text: "A styled block" },
      {
        type: "code",
        lang: "dart",
        code: `// True-color foreground, bold, 40-char centered block
final title = const Style(
  foregroundRgb: RgbColor(203, 166, 247), // Catppuccin Mauve
  isBold: true,
  width: 40,
  align: Align.center,
).render('Hello, dart_tui!');

// Borders + padding + title
final box = const Style(
  border: Border.rounded,
  borderForeground: RgbColor(137, 180, 250),
  borderTitle: ' My Box ',
  borderTitleAlignment: Align.center,
  padding: EdgeInsets.symmetric(vertical: 0, horizontal: 1),
  width: 40,
).render(content);`,
      },
      { type: "heading", text: "Border styles" },
      {
        type: "prose",
        md: "Seven border variants, plus per-character coloring, an embedded title and per-side visibility flags:",
      },
      {
        type: "code",
        lang: "dart",
        code: `Border.box      // ┌─┐ └─┘ │
Border.rounded  // ╭─╮ ╰─╯ │
Border.thick    // ┏━┓ ┗━┛ ┃
Border.double   // ╔═╗ ╚═╝ ║
Border.normal   // +--+ | (ASCII-only)
Border.hidden   // space-padded (preserves geometry)
Border.none     // no border

// Draw only specific sides
style.withBorderSides(top: true, bottom: true);
Border.rounded.topOnly;
Border.rounded.sidesOnly;`,
      },
      { type: "heading", text: "SGR text attributes" },
      {
        type: "code",
        lang: "dart",
        code: `const Style(isBold: true)          // bold
const Style(isDim: true)           // dim / faint
const Style(isItalic: true)        // italic
const Style(isUnderline: true)     // underline
const Style(isStrikethrough: true) // strikethrough
const Style(isReverse: true)       // swap fg/bg
const Style(isBlink: true)         // blinking text
const Style(isOverline: true)      // overline decoration`,
      },
      { type: "gif", src: "sgr_attrs.gif", caption: "SGR attributes and Style.inherit()" },
      { type: "heading", text: "Style inheritance" },
      {
        type: "prose",
        md: "`child.inherit(parent)` fills any unset fields on the child from the parent — set fields on the child win.",
      },
      {
        type: "code",
        lang: "dart",
        code: `const base = Style(
  foregroundRgb: RgbColor(203, 166, 247),
  isBold: true,
  isItalic: true,
);
const child = Style(
  foregroundRgb: RgbColor(166, 227, 161), // overrides fg
);
final resolved = child.inherit(base); // green + bold + italic`,
      },
      { type: "heading", text: "Layout helpers" },
      {
        type: "code",
        lang: "dart",
        code: `final ui  = joinHorizontal(AlignVertical.top, [leftPane, rightPane]);
final mid = place(termWidth, termHeight, Align.center, AlignVertical.middle, content);`,
      },
    ],
    related: ["colors-and-gradients", "text-and-layout", "canvas"],
  },
  {
    slug: "colors-and-gradients",
    name: "Colors & gradients",
    category: "guides",
    order: 6,
    tagline: "True-color text, per-character gradients and background detection.",
    description:
      "dart_tui speaks 24-bit true color. Paint per-character gradients across any number of stops, fill gradient backgrounds, and branch your palette on the terminal's detected background.",
    gif: "gradient.gif",
    blocks: [
      { type: "heading", text: "Gradient text & backgrounds" },
      {
        type: "code",
        lang: "dart",
        code: `// Per-character true-color gradient across any number of colors
final rainbow = gradientText('dart_tui', [
  const RgbColor(203, 166, 247), // mauve
  const RgbColor(116, 199, 236), // sky
  const RgbColor(166, 227, 161), // green
]);

// Gradient background fill
final banner = gradientBackground('  Welcome!  ', [
  const RgbColor(30, 30, 46),
  const RgbColor(49, 50, 68),
], foreground: const Style(foregroundRgb: RgbColor(205, 214, 244)));`,
      },
      { type: "heading", text: "Light / dark background detection" },
      {
        type: "prose",
        md: "`Program` sends an OSC 11 query at startup; the reply arrives automatically as `BackgroundColorMsg` in your `update()`. Branch your styles with `isDarkRgb()`:",
      },
      {
        type: "code",
        lang: "dart",
        code: `case BackgroundColorMsg(:final rgb):
  final dark = isDarkRgb(rgb);
  return (MyModel(darkTheme: dark), null);`,
      },
      {
        type: "callout",
        variant: "note",
        md: "`CompleteColor` lets you specify one color per profile (true-color / 256 / ANSI) so output degrades gracefully on limited terminals.",
      },
    ],
    related: ["styling", "text-and-layout"],
  },
  {
    slug: "text-and-layout",
    name: "Text & layout",
    category: "guides",
    order: 7,
    tagline: "Word wrap, width measurement, truncation and tab expansion.",
    description:
      "Utilities for measuring and shaping text that respect ANSI escape codes and double-wide characters — so your layouts line up no matter what's in the string.",
    gif: "word_wrap.gif",
    blocks: [
      { type: "heading", text: "Word wrap" },
      {
        type: "code",
        lang: "dart",
        code: `const Style(
  wordWrap: true,
  width: 40,
  border: Border.rounded,
  borderTitle: ' Notes ',
).render(longText);`,
      },
      { type: "heading", text: "Measuring & truncating" },
      {
        type: "prose",
        md: "These helpers count **visible terminal columns**, stripping ANSI codes and accounting for wide glyphs:",
      },
      {
        type: "code",
        lang: "dart",
        code: `getWidth('hello')              // → 5  (visible columns)
getWidth('\\x1b[31mhi\\x1b[0m')   // → 2  (ANSI stripped)
getHeight('line1\\nline2')       // → 2

truncate('hello world', 5)      // → 'hello'   (drop right)
truncateLeft('hello world', 5)  // → 'world'   (drop left)`,
      },
      { type: "heading", text: "Tab width & margin background" },
      {
        type: "code",
        lang: "dart",
        code: `const Style(tabWidth: 4)                              // expand \\t to 4 spaces
const Style(marginBackground: RgbColor(30, 30, 46))  // tint the margin area`,
      },
    ],
    related: ["styling", "colors-and-gradients"],
  },
  {
    slug: "readline-keys",
    name: "Readline keys",
    category: "guides",
    order: 8,
    tagline: "Emacs-style editing bindings in text input & text area.",
    description:
      "`TextInputModel` and `TextAreaModel` understand the common emacs/readline bindings, so power users feel at home immediately.",
    blocks: [
      {
        type: "table",
        headers: ["Key", "Action"],
        rows: [
          ["ctrl+a / ctrl+e", "Jump to start / end of line"],
          ["ctrl+b / ctrl+f", "Move one character left / right"],
          ["alt+← / alt+→", "Move one word left / right"],
          ["ctrl+w / alt+backspace", "Delete the previous word"],
          ["ctrl+k", "Kill to end of line (text area)"],
        ],
      },
    ],
    related: ["text-input", "text-area"],
  },
  {
    slug: "file-logging",
    name: "File logging",
    category: "guides",
    order: 9,
    tagline: "Write diagnostics to a file without corrupting the UI.",
    description:
      "A running `Program` owns stdout, so `print()` corrupts the rendered UI. Write diagnostics to a file with `FileLog` and `tail -f` it in another terminal.",
    gif: "file_log.gif",
    blocks: [
      {
        type: "code",
        lang: "dart",
        code: `final log = FileLog('debug.log');
log('got message: $msg');

// on shutdown:
await log.close();`,
      },
      {
        type: "callout",
        variant: "note",
        md: "`FileLog.none()` returns a logger that silently discards everything — handy for toggling diagnostics off without changing call sites.",
      },
    ],
    related: ["program-options"],
  },
  {
    slug: "architecture",
    name: "Architecture notes",
    category: "guides",
    order: 10,
    tagline: "How the event loop and renderers actually work.",
    description:
      "A look under the hood: how input becomes messages, how the loop drains and renders, and the two renderer strategies.",
    blocks: [
      { type: "heading", text: "Event loop" },
      {
        type: "code",
        lang: "text",
        code: `stdin bytes
    │
    ▼
TerminalInputDecoder
    │ (KeyPressMsg, WindowSizeMsg, BackgroundColorMsg, …)
    ▼
Queue<Msg>
    │
    ▼  drain all pending messages first
for msg in queue:
    model = model.update(msg)
    fire cmd (unawaited — result enqueues next message)
    │
    ▼  render once per batch (FPS-throttled)
renderer.render(model.view())`,
      },
      {
        type: "prose",
        md: "**Key properties:** all pending messages are drained before each render, so rapid key presses never block each other. Commands are fire-and-forget; their result arrives as the next message. The FPS cap only throttles screen output, not message processing.",
      },
      { type: "heading", text: "Renderers" },
      {
        type: "table",
        headers: ["Renderer", "Strategy", "When to use"],
        rows: [
          ["AnsiRenderer (default)", "Line-level diff", "Most terminals"],
          ["CellRenderer", "Cell-level diff (per grapheme)", "Terminals without ?2026 sync"],
        ],
      },
      {
        type: "prose",
        md: "The cell-level diff renderer writes only changed cells, giving zero flicker. `Synchronized updates (CSI ?2026)` are used automatically where the terminal supports them.",
      },
    ],
    related: ["mvu-architecture", "program-options"],
  },
  {
    slug: "examples",
    name: "Examples",
    category: "guides",
    order: 11,
    tagline: "60+ runnable programs covering every feature.",
    description:
      "The package ships 60+ runnable examples — one per feature, each with a recorded GIF. Clone the repo and run any of them.",
    blocks: [
      { type: "heading", text: "Running an example" },
      {
        type: "code",
        lang: "bash",
        code: `# JIT (source, slower first run)
dart run example/simple.dart

# Kernel snapshot (~2× faster startup)
make kernel EXAMPLE=simple
dart run tool/bin/simple.dill`,
      },
      { type: "heading", text: "The catalogue" },
      {
        type: "table",
        headers: ["Example", "What it shows"],
        rows: [
          ["simple.dart", "Tick-driven countdown, minimal model"],
          ["textinput.dart", "Single-line text input"],
          ["textinputs.dart", "Multi-field form with Tab focus"],
          ["textarea.dart", "Multi-line editor"],
          ["readline.dart", "Readline editing keys"],
          ["autocomplete.dart", "Tab-completion suggestions"],
          ["list_filter.dart", "ListModel with fuzzy filtering"],
          ["list_mutation.dart", "Add / remove list items live"],
          ["multi_select.dart", "Checkbox list with toggle-all"],
          ["table.dart", "City data table"],
          ["tree.dart", "Expandable language/framework tree"],
          ["cursor_model.dart", "Blinking block/underline/bar cursor"],
          ["spinner.dart / spinners.dart", "One spinner / all frame styles"],
          ["progress_bar.dart / progress_animated.dart", "Interactive / auto-incrementing progress"],
          ["spring.dart", "Harmonica-style eased motion"],
          ["gum.dart", "filter / spin / pager helpers"],
          ["file_picker.dart", "Directory browser"],
          ["help.dart", "HelpModel + KeyMap"],
          ["timer.dart / stopwatch.dart", "Countdown / elapsed time"],
          ["paginator.dart", "Page dot indicator"],
          ["gradient.dart", "Per-character gradient text"],
          ["canvas.dart", "Canvas compositing with z-index"],
          ["tabs.dart", "TabsModel tabbed interface"],
          ["border_style.dart", "All Border variants + titles + colors"],
          ["word_wrap.dart", "Style.wordWrap at multiple widths"],
          ["sgr_attrs.dart", "SGR text attributes + Style.inherit()"],
          ["mouse.dart", "Mouse click / scroll events"],
          ["exec_cmd.dart", "External editor via execProcess"],
          ["http.dart", "HTTP fetch with spinner"],
          ["file_log.dart", "Write diagnostics to a file, not the UI"],
          ["form.dart", "huh-style fields, validation, wizard, dynamic pages"],
          ["showcase.dart / all_features.dart", "Full-featured galleries"],
        ],
      },
      {
        type: "prose",
        md: "Plus more: `window_size`, `fullscreen`, `cursor_style`, `pipe`, `send_msg`, `realtime`, `prevent_quit`, `sequence`, `focus_blur`, `vanish`, `print_key`, `views`, `set_window_title`, `altscreen_toggle`, `shopping_list`, `package_manager`, `composable_views`, `color_profile`, `result`, `isbn_form`.",
      },
    ],
    related: ["installation", "showcase"],
  },
];
