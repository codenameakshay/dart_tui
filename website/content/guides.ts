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
        code: `dependencies:\n  dart_tui: ^3.0.0`,
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
    related: ["styling", "text-and-layout", "colour-and-terminals"],
  },
  {
    slug: "colour-and-terminals",
    name: "Colour and terminals",
    category: "guides",
    order: 6.5,
    tagline: "Detect the colour profile and the light or dark background.",
    description:
      "A `Program` finds out how many colours the terminal supports and whether its background is light or dark. Every `Style` follows both, with no code in your model.",
    gif: "color_profile.gif",
    blocks: [
      { type: "heading", text: "What the Program does" },
      {
        type: "prose",
        md: "When a `Program` writes to the real stdout, it calls `detectColorProfile()` at startup and sets `Style.defaultProfile` for the run. Each `Style` without its own `profile` uses that value, so RGB colours step down to 256 colours, to 16 colours, or to no colour. This includes border, margin and underline colours, and `gradientText` / `gradientBackground`. Bold, italic and underline stay. Your model also gets the value as `ColorProfileMsg`. When the run ends, the previous value comes back, also when `update` throws or SIGTERM stops the program.",
      },
      { type: "heading", text: "Detection rules" },
      {
        type: "prose",
        md: "The first rule that matches wins. The rules follow [charmbracelet/colorprofile](https://github.com/charmbracelet/colorprofile), plus `FORCE_COLOR` and `TERM_PROGRAM`.",
      },
      {
        type: "table",
        headers: ["Environment", "Profile"],
        rows: [
          ["`FORCE_COLOR=1` (or any non-zero value)", "at least `ansi`, also when output is not a terminal"],
          ["`FORCE_COLOR=2` / `FORCE_COLOR=3`", "at least `ansi256` / `trueColor`"],
          ["`NO_COLOR` set to any non-empty value", "`noColor`"],
          ["`CLICOLOR_FORCE` (same levels as `FORCE_COLOR`)", "forces colour, but `NO_COLOR` wins"],
          ["Output is not a terminal, or `TERM=dumb`", "`noColor`"],
          ["`COLORTERM=truecolor` or `24bit`", "`trueColor`"],
          ["kitty, Ghostty, WezTerm, Alacritty, iTerm2, VS Code, Windows Terminal (`WT_SESSION`)", "`trueColor`"],
          ["`TERM` ending in `256color`, tmux, screen, Apple Terminal", "`ansi256`"],
          ["Anything else", "`ansi`"],
        ],
      },
      {
        type: "callout",
        variant: "note",
        md: "`FORCE_COLOR` sets a minimum. `FORCE_COLOR=1` in a true-colour terminal still gives `trueColor`. `FORCE_COLOR=0` and `false` do not force anything.",
      },
      { type: "heading", text: "Light and dark backgrounds" },
      {
        type: "prose",
        md: "`AdaptiveColor` picks its `light` or `dark` value. It uses the style's own background when the style has one. If not, it uses `Style.hasDarkBackground`. That value starts from `COLORFGBG` (for example `15;0` is dark) and is otherwise dark. The `Program` asks the terminal for its background colour at startup (OSC 11). When the reply arrives as `BackgroundColorMsg`, the `Program` updates `Style.hasDarkBackground` before your `update` sees the message, so the next frame uses the correct variant.",
      },
      {
        type: "code",
        lang: "dart",
        code: `const accent = Style(
  adaptiveForeground: AdaptiveColor(
    light: RgbColor(30, 30, 160), // navy on a light terminal
    dark: RgbColor(255, 220, 120), // gold on a dark terminal
  ),
);`,
      },
      { type: "heading", text: "Override the profile" },
      {
        type: "prose",
        md: "Pin a profile for the whole run with `withColorProfile`, or for one style with `Style(profile: ...)`. A style's own profile always wins.",
      },
      {
        type: "code",
        lang: "dart",
        code: `await Program(options: [
  withColorProfile(ColorProfile.ansi256),
]).run(MyModel());

final plain = Style(profile: ColorProfile.noColor).bold();`,
      },
      {
        type: "prose",
        md: "Outside a `Program`, styles use `trueColor`, or `noColor` when `NO_COLOR` is set. A script that prints styled text can opt in to detection:",
      },
      {
        type: "code",
        lang: "dart",
        code: `Style.defaultProfile = detectColorProfile();
print(const Style().foregroundColorRgb(107, 80, 255).render('Hello'));`,
      },
      { type: "heading", text: "Pin a profile in tests" },
      {
        type: "prose",
        md: "A `Program` that writes to a custom sink (`withOutput`) does not detect anything. It uses `trueColor`, so golden frames do not change with the machine that runs them. To test another profile, add `withColorProfile`. To test detection itself, call `detectColorProfile` with an explicit environment:",
      },
      {
        type: "code",
        lang: "dart",
        code: `expect(
  detectColorProfile(
    environment: {'TERM': 'xterm-256color'},
    isTerminal: true,
  ),
  ColorProfile.ansi256,
);

await Program(options: [
  withOutput(sink),
  withColorProfile(ColorProfile.noColor),
]).run(MyModel());`,
      },
      {
        type: "callout",
        variant: "note",
        md: "`Style.defaultProfile` and `Style.hasDarkBackground` are shared by the whole isolate. A test that sets them must restore them, for example in `addTearDown`. Programs that overlap in one isolate share them too.",
      },
    ],
    related: ["colors-and-gradients", "styling", "program-options"],
  },
  {
    slug: "plain-mode",
    name: "Plain mode: CI, pipes, screen readers and agents",
    category: "guides",
    order: 6.6,
    tagline: "Line questions and plain text, with no escape codes.",
    description:
      "In plain mode the one-shot helpers and `Form.run` ask plain line questions and write no escape codes. Use it for pipes, CI, screen readers and AI agents.",
    gif: "plain_mode.gif",
    blocks: [
      { type: "heading", text: "What plain mode does" },
      {
        type: "prose",
        md: "In plain mode, `promptSelect`, `promptConfirm`, `promptInput`, `filter`, `spin`, `pager` and `Form.run` do not draw a terminal UI. They write a question, read one line, and go on. They write no escape codes at all. The output is plain text that a log, a screen reader or an AI agent can read.",
      },
      { type: "heading", text: "When it turns on" },
      {
        type: "prose",
        md: "The first rule that matches wins.",
      },
      {
        type: "table",
        headers: ["Rule", "Result"],
        rows: [
          ["`withPlainMode()`", "plain mode on"],
          ["`withPlainMode(false)`", "plain mode off, over everything else"],
          ["`DART_TUI_ACCESSIBLE` or `ACCESSIBLE` set to a true value (for example `1`)", "plain mode on"],
          ["The helper uses the real stdin and stdout, and either is not a terminal", "plain mode on"],
          ["The helper uses the real stdin and stdout, and `TERM=dumb`", "plain mode on"],
          ["The helper has `withInput` or `withOutput`", "terminal UI, unless you force plain mode"],
        ],
      },
      {
        type: "callout",
        variant: "note",
        md: "`0`, `false` and an empty value do not count as true. The environment comes from `withEnvironment`, or from the process environment. The `TERM=dumb` rule is the same rule that colour detection uses. Existing tests that pass `withInput` or `withOutput` do not change.",
      },
      { type: "heading", text: "What each helper writes" },
      {
        type: "table",
        headers: ["Helper", "Output and input"],
        rows: [
          ["`promptSelect`, `filter`", "The title, then `1. a`, `2. b` ... lines, then `Enter a number: `. A wrong answer prints `Enter a number from 1 to N.` and asks again. `filter` also takes text that matches exactly one option."],
          ["`promptConfirm`", "`Ship? (y/N) `. The capital letter is the default, no. Empty input takes it. `y`, `yes`, `n` and `no` work."],
          ["`promptInput`", "The label, then one line. Empty input gives an empty string."],
          ["`spin`", "`Working…` at the start, then `✓ Working` or `✗ Working: <error>`. It returns the value or throws again."],
          ["`pager`", "The content, as it is."],
        ],
      },
      { type: "heading", text: "Forms" },
      {
        type: "prose",
        md: "`Form.run` shows group titles as headings and notes as text. It skips hidden fields. Input fields show `Name [default]: ` or `Name (placeholder): `. Select fields show numbered options and `Enter a number [2]: `, and empty input keeps the current choice. Multi-select fields take numbers with commas, and empty input keeps the defaults. Confirm fields show `Title (Y/n) ` or `Title (y/N) ` based on the current value; empty input keeps that value. A failed validator prints `✗ message` and asks again. Dynamic titles and options follow the answers so far. A multi-line text field takes one line. A file field takes a path. A password input does not echo on a terminal. The values are the same as the terminal form gives for the same answers.",
      },
      { type: "heading", text: "Pipe the answers" },
      {
        type: "prose",
        md: "When the input is not a terminal, the helper writes each answer to the output. A log then reads like a transcript.",
      },
      {
        type: "code",
        lang: "bash",
        code: `printf '2\\ny\\nAkshay\\n' | dart run example/prompts_chain.dart

# stdout is a pipe: the form is plain, and you type the answers
dart run example/form.dart | cat`,
      },
      { type: "heading", text: "Force it on or off" },
      {
        type: "code",
        lang: "dart",
        code: `final pick = await promptSelect(
  ['apple', 'banana'],
  title: 'Pick one',
  options: [withPlainMode()], // withPlainMode(false) keeps the terminal UI
);`,
      },
      {
        type: "prose",
        md: "Or set the variable for the whole process: `DART_TUI_ACCESSIBLE=1 dart run app.dart`.",
      },
      {
        type: "callout",
        variant: "warn",
        md: "End of input cancels. When stdin closes, a helper returns `null`, like `Esc`, and `Form.run` returns `null`. It does not hang and it does not loop. Check for `null` in scripts.",
      },
      { type: "heading", text: "Custom programs" },
      {
        type: "prose",
        md: "A custom `Program` is in plain mode when you pass `withPlainMode()`, or when it uses the default stdin and its real stdout is not a terminal. It then writes no cursor, erase or query codes while it runs. It prints `println` lines as plain text at once. On exit it writes the final frame once, as plain text. Input is read as usual.",
      },
      {
        type: "prose",
        md: "Plain prompts read through the same stdin owner as `Program`. A plain prompt and a full `Program` can run one after the other in one process. Input that the first reader did not use goes to the next reader.",
      },
      { type: "heading", text: "Test plain mode" },
      {
        type: "code",
        lang: "dart",
        code: `final choice = await promptSelect(
  ['a', 'b'],
  options: [
    withPlainMode(),
    withInput(Stream.value(utf8.encode('2\\n'))),
    withOutput(sink),
  ],
);
expect(choice, 'b');`,
      },
    ],
    related: ["colour-and-terminals", "program-options", "examples"],
  },
  {
    slug: "testing",
    name: "Testing your app",
    category: "guides",
    order: 6.7,
    tagline: "Press keys, read the screen, compare with golden files.",
    description:
      "`package:dart_tui/testing.dart` runs your model in a real `Program`, headless, so a test can press keys, wait for the screen and compare it with a golden file. It is the dart_tui answer to Bubble Tea's teatest and Textual's snapshot tests.",
    gif: "testing.gif",
    blocks: [
      { type: "heading", text: "What the tester does" },
      {
        type: "prose",
        md: "`TuiTester(model)` runs the real `Program`, so commands, batches, sequences and quitting behave as they do in your app. Each program gets a fixed size (80x24 by default, also sent as the first `WindowSizeMsg`), an empty environment, plain mode off, no renderer and no stdin. The colour profile is pinned to `noColor` (pass `profile: ColorProfile.trueColor` for colour), and `Style.defaultProfile` and `Style.hasDarkBackground` are restored when the run ends, also when your model throws.",
      },
      {
        type: "prose",
        md: "The library imports no test framework. It returns plain values and throws `TuiTestFailure`, so it works with `package:test` or any other runner. It is not exported from `dart_tui.dart`.",
      },
      { type: "heading", text: "Test a counter" },
      {
        type: "code",
        lang: "dart",
        code: `import 'package:dart_tui/dart_tui.dart';
import 'package:dart_tui/testing.dart';
import 'package:test/test.dart';

final class CounterModel extends Model {
  CounterModel([this.count = 0]);
  final int count;

  @override
  (Model, Cmd?) update(Msg msg) => switch (msg) {
        KeyMsg(key: 'up') => (CounterModel(count + 1), null),
        KeyMsg(key: 'q') => (this, () => quit()),
        _ => (this, null),
      };

  @override
  View view() => newView('Count: $count');
}

void main() {
  test('up counts, q quits', () async {
    final t = TuiTester(CounterModel());
    addTearDown(t.dispose);

    await t.press('up');
    await t.press('up');
    expect(t.screen, 'Count: 2');

    await t.press('q');
    final result = await t.done();
    expect((result.model! as CounterModel).count, 2);
  });
}`,
      },
      {
        type: "table",
        headers: ["Call", "What it does"],
        rows: [
          ["`press('enter')`", "One key by its keystroke name: `ctrl+c`, `shift+tab`, `alt+left`, `pgdown`, `f5`, `space`, `a`. It goes through the real input decoder, so your model gets the same `KeyPressMsg` as from a keyboard."],
          ["`type('héllo👋')`", "One key per Unicode scalar, as a terminal sends text."],
          ["`paste(text)`", "A bracketed paste: `PasteStartMsg`, `PasteMsg`, `PasteEndMsg`."],
          ["`send(msg)`, `resize(w, h)`", "Any message, or a `WindowSizeMsg`."],
          ["`screen`, `styledScreen`, `model`", "The current view as plain text (escape codes removed, trailing spaces trimmed), with its escape codes, and the current model."],
          ["`waitFor(test, timeout:)`", "Waits until `test(screen)` is true (default 2 s). On timeout it throws with the last screen."],
          ["`quit()`, `done()`", "End the run (or wait for it to end) and return the final model, screen and outcome."],
        ],
      },
      {
        type: "callout",
        variant: "note",
        md: "Each input call completes once the program has handled the message, so `screen` is current right after `await t.press(...)`. Commands still run asynchronously: use `waitFor` for what they send back.",
      },
      { type: "heading", text: "Test a form or a prompt" },
      {
        type: "prose",
        md: "A `Form` is a model, so `TuiTester(form)` works and `(await t.done()).outcome` is its `FormValues`. For code that makes its own `Program`, such as `promptSelect`, `filter` or `Form.run`, use `TuiTester.run`: it drives programs constructed inside the body, and `(await t.done()).value` is what the body returns. Construct the `Program` inside the body rather than reusing one created earlier.",
      },
      {
        type: "code",
        lang: "dart",
        code: `test('the signup form', () async {
  final t = TuiTester(Form([
    Group([
      Field.input(key: 'name', title: 'Name'),
      Field.confirm(key: 'ok', title: 'Subscribe?', initial: true),
    ]),
  ]));
  addTearDown(t.dispose);

  await t.type('Ada');
  await t.press('tab');
  expectScreen(t.screen, 'test/goldens/signup.txt');
  await t.press('enter');

  final values = (await t.done()).outcome as FormValues;
  expect(values.get<String>('name'), 'Ada');
});

test('promptSelect', () async {
  final t = TuiTester.run(() => promptSelect(['a', 'b', 'c']));
  addTearDown(t.dispose);
  await t.press('down');
  await t.press('enter');
  expect((await t.done()).value, 'b');
});`,
      },
      { type: "heading", text: "Golden files" },
      {
        type: "prose",
        md: "`expectScreen(t.screen, 'test/goldens/name.txt')` compares the screen with a file. A missing file throws a `TuiTestFailure` that names the path. A different file throws one that names the first differing line, with the expected and actual text. Pass `t.styledScreen` to keep the colours in the golden.",
      },
      {
        type: "code",
        lang: "text",
        code: `TuiTestFailure: screen does not match golden file example/test/goldens/simple_start.txt
first difference at line 3 (expected 3 lines, got 3):
  expected: "Press q to quit."
  actual:   "Press q to stop."
Run with DART_TUI_UPDATE_GOLDENS=1 to accept the new screen.`,
      },
      { type: "heading", text: "Update golden files" },
      {
        type: "prose",
        md: "When a screen changes on purpose, write the new files, read the diff and commit them:",
      },
      {
        type: "code",
        lang: "bash",
        code: `DART_TUI_UPDATE_GOLDENS=1 dart test
git diff test/goldens`,
      },
      { type: "heading", text: "Timers and spinners" },
      {
        type: "callout",
        variant: "warn",
        md: "There is no fake clock. Ticks and `tick()` commands run in real time. Give the program a short `withTickInterval` through `options`, and wait for the screen to change with `waitFor`.",
      },
      {
        type: "code",
        lang: "dart",
        code: `final t = TuiTester(SpinnerApp(),
    options: [withTickInterval(const Duration(milliseconds: 5))]);
final first = t.screen;
await t.waitFor((screen) => screen != first);`,
      },
      { type: "heading", text: "Run it in CI" },
      {
        type: "prose",
        md: "The tester needs no terminal, so a plain `dart test` step is enough. Goldens are compared with `\\n` line endings, so a Windows checkout with CRLF still matches. A missing golden fails unless updates are enabled. Keep `DART_TUI_UPDATE_GOLDENS` unset in CI, or pass `update: false` to prevent writes.",
      },
      {
        type: "code",
        lang: "yaml",
        code: `- uses: dart-lang/setup-dart@v1
- run: dart pub get
- run: dart test`,
      },
      {
        type: "callout",
        variant: "note",
        md: "`Style` defaults are process-wide, so run one tester at a time in an isolate (the default within one test file) and always `addTearDown(t.dispose)`. `CaptureSink` is an in-memory `IOSink` for tests that pass `withOutput`.",
      },
    ],
    related: ["plain-mode", "program-options", "examples"],
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
        md: "The default renderer diffs line by line; the opt-in cell-level renderer (`withCellRenderer()`) writes only changed cells, which reduces flicker. `Synchronized updates (CSI ?2026)` are used automatically where the terminal supports them.",
      },
    ],
    related: ["mvu-architecture", "program-options"],
  },
  {
    slug: "examples",
    name: "Examples",
    category: "guides",
    order: 11,
    tagline: "60 runnable programs, each with a recorded GIF.",
    description:
      "The package ships 60 runnable examples, each with a recorded GIF. Clone the repo and run any of them.",
    blocks: [
      { type: "heading", text: "Running an example" },
      {
        type: "code",
        lang: "bash",
        code: `# JIT (source, slower first run)
dart run example/simple.dart

# Kernel snapshot (~3× faster startup)
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
        md: "Plus more: `window_size`, `fullscreen`, `cursor_style`, `pipe`, `send_msg`, `realtime`, `prevent_quit`, `sequence`, `focus_blur`, `vanish`, `print_key`, `views`, `set_window_title`, `altscreen_toggle`, `prompts_chain`, `shopping_list`, `package_manager`, `composable_views`, `color_profile`, `result`, `isbn_form`.",
      },
    ],
    related: ["installation", "showcase"],
  },
  {
    slug: "performance",
    name: "Performance",
    category: "guides",
    order: 12,
    featured: true,
    tagline:
      "Measure naive Dart vs dart_tui hot paths, plus kernel and AOT startup.",
    description:
      "Diffing renderers, grapheme width, and cached component models beat reprinting the whole screen every frame. Run the benches locally to see naive Dart vs dart_tui, and kernel/AOT first-visible startup.",
    blocks: [
      { type: "heading", text: "Why not print every frame" },
      {
        type: "prose",
        md: "Reprint-the-screen loops pay for every cell on every tick. dart_tui writes only the lines that changed (or only the cells, with the cell renderer), measures grapheme width without reallocating on every call, and keeps cached row models in components like TextArea and Viewport so update/view work stays cheap.",
      },
      { type: "heading", text: "Run the benches" },
      {
        type: "code",
        lang: "bash",
        code: `make bench-hotpath
make bench-startup-pty`,
      },
      {
        type: "table",
        headers: ["Workload", "Naive", "dart_tui", "Ratio"],
        rows: [
          ["getWidth plain x10000", "30080 µs", "2511 µs", "12.0x"],
          ["getWidth ANSI x10000", "33792 µs", "3353 µs", "10.1x"],
          ["textarea update+view x300", "19733 µs", "3752 µs", "5.3x"],
          ["viewport soft-wrap scroll+view x20", "338586 µs", "17266 µs", "19.6x"],
          ["decoder plain 100000 bytes", "6445149 µs", "3686 µs", "1748.5x"],
        ],
      },
      { type: "heading", text: "Startup (first visible frame)" },
      {
        type: "table",
        headers: ["Mode", "Median first visible"],
        rows: [
          ["JIT source", "553 ms"],
          ["Kernel snapshot", "158 ms"],
          ["AOT executable", "11 ms"],
        ],
      },
      {
        type: "callout",
        variant: "note",
        md: "Microbench ratios are host-specific. Clone the repo and run `make bench-hotpath` on your machine rather than treating any published number as a guarantee.",
      },
      {
        type: "prose",
        md: "For the full audit vs `e00de92`, see [docs/performance.md](https://github.com/codenameakshay/dart_tui/blob/main/docs/performance.md).",
      },
    ],
    related: ["installation", "architecture"],
  },
];
