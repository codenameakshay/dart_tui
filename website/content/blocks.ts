import type { DocEntry } from "./registry";

export const blocks: DocEntry[] = [
  {
    slug: "forms",
    name: "Forms",
    category: "blocks",
    order: 1,
    featured: true,
    isNew: true,
    tagline: "huh-style typed fields, validation and wizard pages.",
    description:
      "A composable, huh-style form: typed fields grouped into (optionally conditional) wizard pages, per-field validation with inline errors, and dynamic fields whose visibility and options depend on other fields' values. Key-based and immutable — a `Form` is a `Model` you can embed, or run one-shot with `form.run()`.",
    gif: "form.gif",
    snippets: [
      {
        label: "Usage",
        lang: "dart",
        code: `final form = Form([
  Group([
    Field.input(
      key: 'name',
      title: 'Service name',
      validate: (v) => v.contains(' ') ? 'no spaces allowed' : null,
    ),
    Field.select(
      key: 'runtime',
      title: 'Runtime',
      options: ['Dart', 'Go', 'Node'],
      initial: 'Dart',
    ),
    Field.confirm(key: 'deploy', title: 'Deploy now?', initial: true),
  ], title: 'Basics'),
  Group([
    Field.multiSelect(key: 'regions', title: 'Regions',
        options: ['iad', 'fra', 'sfo']),
    Field.note(title: 'Review', description: 'Press enter to submit.'),
  ], title: 'Deploy', hidden: (v) => v.get<bool>('deploy') != true),
]);

final values = await form.run();               // FormValues? — null if cancelled
final regions = values?.get<List<String>>('regions');`,
      },
    ],
    api: {
      title: "Field types",
      rows: [
        { name: "Field.input / .password", description: "Single-line text, optionally masked." },
        { name: "Field.text", description: "Multi-line text (text area)." },
        { name: "Field.file", description: "File path via the file picker." },
        { name: "Field.select / .selectOf<T>", description: "Single choice from options." },
        { name: "Field.multiSelect / .multiSelectOf<T>", description: "Multiple choices from options." },
        { name: "Field.confirm", description: "Yes/no boolean." },
        { name: "Field.note", description: "Static, non-interactive information block." },
      ],
    },
    blocks: [
      {
        type: "callout",
        variant: "note",
        md: "Any field or `Group` accepts a `hidden` predicate, and titles/options can be computed dynamically with `titleFor` and `optionsFor` — recomputed live as other fields change.",
      },
    ],
    related: ["prompts", "text-input", "multi-select"],
  },
  {
    slug: "prompts",
    name: "Prompts",
    category: "blocks",
    order: 2,
    featured: true,
    tagline: "One-shot promptSelect / promptConfirm / promptInput.",
    description:
      "Self-contained, one-shot flows built on `Program` — no model to write. Each returns a `Future` and accepts a `options` list so it can be scripted or tested headlessly. All return `null` when cancelled with `Esc`/`Ctrl+C`.",
    gif: "prompts_chain.gif",
    snippets: [
      {
        label: "Usage",
        lang: "dart",
        code: `final choice = await promptSelect(['apple', 'banana'], title: 'Pick one');
final ok     = await promptConfirm('Continue?');
final name   = await promptInput('Name');

if (name == null) return; // user cancelled
print('Hello, \$name!');`,
      },
    ],
    api: {
      title: "Helpers",
      rows: [
        { name: "promptSelect(items, {title})", type: "Future<String?>", description: "Single-choice picker." },
        { name: "promptConfirm(message)", type: "Future<bool?>", description: "Yes/no confirmation." },
        { name: "promptInput(label)", type: "Future<String?>", description: "Single-line text prompt." },
        { name: "promptSelectSync(choices, {title, initial})", type: "String?", description: "Sync twin of `promptSelect`. Blocks until answered." },
        { name: "promptMultiSelectSync(choices, {title, initial})", type: "List<String>?", description: "Sync twin of `promptMultiSelect`." },
        { name: "promptConfirmSync(question, {defaultValue})", type: "bool?", description: "Sync twin of `promptConfirm`." },
        { name: "promptInputSync(label, {hidden, defaultValue})", type: "String?", description: "Sync twin of `promptInput`." },
      ],
    },
    blocks: [
      { type: "heading", text: "Sync prompts" },
      {
        type: "prose",
        md: "`promptSelectSync`, `promptMultiSelectSync`, `promptConfirmSync` and `promptInputSync` take the same parameters as the async prompts and return the value itself, not a `Future`. They use the same models and views, so the frames are the same. Use them in code that is already synchronous, so you can switch to dart_tui by changing only your helper functions and no call chain has to become `async`. Examples are helpers that wrap the `prompts` package (`get`, `getBool`, `choose`) or interact's `Confirm` and `Select` (`.interact()`), and mason_logger's sync prompts.",
      },
      {
        type: "prose",
        md: "For new code, use the async prompts. They run on the event loop, so timers and other work keep going while they wait. They redraw on resize, handle signals, and can be tested with `withInput` and `TuiTester`.",
      },
      {
        type: "code",
        lang: "dart",
        code: `import 'package:dart_tui/dart_tui.dart';

// A synchronous helper. Its callers do not change.
bool promptBool(String message, {bool defaultsTo = false}) =>
    promptConfirmSync(message, defaultValue: defaultsTo) ?? defaultsTo;

void main() {
  final name = promptInputSync('Project name?', defaultValue: 'my_app');
  if (name == null) return; // Esc
  final template = promptSelectSync(['cli', 'server', 'package'], title: 'Template?');
  if (template == null) return;
  if (!promptBool('Create \$name?', defaultsTo: true)) return;
}`,
      },
      {
        type: "prose",
        md: "On a terminal a sync prompt turns on raw mode, reads stdin with `readByteSync`, decodes keys the same way and repaints inline. It restores the terminal in a `finally` block: cooked mode, cursor shown. In plain mode (pipes, CI, `TERM=dumb`, `ACCESSIBLE=1` or `DART_TUI_ACCESSIBLE=1`, `withPlainMode()`) it asks the same numbered line questions and reads with `readLineSync`.",
      },
      {
        type: "table",
        headers: ["Event", "Sync prompts", "Async prompts"],
        rows: [
          ["Esc", "Returns `null`.", "Returns `null`."],
          ["Ctrl+C", "Restores the terminal, then exits the process with code 130.", "Returns `null`."],
          ["End of input in plain mode", "Returns `null`. `Logger` returns the default.", "Returns `null`. `Logger` returns the default."],
        ],
      },
      {
        type: "prose",
        md: "A lone Esc is told from the start of a key sequence by waiting 50 ms.",
      },
      { type: "heading", text: "What sync prompts cannot do" },
      {
        type: "table",
        headers: ["Limit", "Detail"],
        rows: [
          ["No event loop", "No Cmds run: only quit is understood, and the prompt models need nothing else. Timers and futures elsewhere in the program wait until the prompt returns."],
          ["No resize", "The frame is not redrawn when the terminal is resized."],
          ["Process stdin only", "`withInput(stream)` throws `ArgumentError`. `withInput(null)` returns `null` at once."],
          ["One reader at a time", "They throw `StateError` while a `Program` or an async prompt reads stdin (await it first), and under `TuiTester`."],
          ["Signals from outside", "`kill` or `SIGTERM` during a sync prompt ends the process without restoring the terminal. There is no event loop to handle it."],
          ["No stdin isolate", "They never start one."],
        ],
      },
      {
        type: "callout",
        variant: "note",
        md: "`Logger` in `package:dart_tui/cli.dart` has thin wrappers: `promptSync`, `promptAnySync`, `confirmSync`, `chooseOneSync` and `chooseAnySync`. They match mason_logger's methods, so moving from mason_logger is a rename with no `await`. Esc or Ctrl+C exits with code 130. A `Logger` built with a custom `stdin:` stream throws `StateError` from them.",
      },
      {
        type: "callout",
        variant: "warn",
        md: "On Windows the raw path is implemented, but only CI unit tests on windows-latest check it. Nobody has run it in an interactive console. The pseudo-terminal tests run on macOS and Linux only.",
      },
    ],
    related: ["forms", "gum-helpers", "migrating-from-mason-logger"],
  },
  {
    slug: "gum-helpers",
    name: "Gum helpers",
    category: "blocks",
    order: 3,
    tagline: "gum-style filter / spin / pager one-liners.",
    description:
      "Interactive one-liners inspired by Charm's [gum](https://github.com/charmbracelet/gum): fuzzy-`filter` a list, `spin` a spinner while awaiting a `Future`, or `pager` through long text. Ideal for glue scripts and quick tooling.",
    gif: "gum.gif",
    snippets: [
      {
        label: "Usage",
        lang: "dart",
        code: `// Interactive fuzzy filter over a list:
final picked = await filter(['red', 'green', 'blue']);

// Show a spinner while a Future resolves:
final result = await spin(fetchData(), label: 'Loading…');

// Scrollable viewer (q / Esc to exit):
await pager(longText);`,
      },
    ],
    api: {
      title: "Helpers",
      rows: [
        { name: "filter(items)", type: "Future<String?>", description: "Interactive fuzzy filter; returns the chosen item." },
        { name: "spin(future, {label})", type: "Future<T>", description: "Spinner while the future resolves; returns its value." },
        { name: "pager(text)", type: "Future<void>", description: "Scrollable full-screen viewer." },
      ],
    },
    related: ["prompts", "viewport", "spinner"],
  },
  {
    slug: "canvas",
    name: "Canvas compositing",
    category: "blocks",
    order: 4,
    tagline: "Paint styled blocks at (x, y) with z-index layering.",
    description:
      "Paint styled text blocks at arbitrary `(x, y)` positions with z-index layering. Higher `zIndex` draws on top of lower ones at overlapping cells — perfect for dashboards, HUDs and overlapping panels.",
    gif: "canvas.gif",
    snippets: [
      {
        label: "Usage",
        lang: "dart",
        code: `final canvas = Canvas(72, 22);
canvas.paint(2, 2, leftPanel.render(content), zIndex: 1);
canvas.paint(38, 2, rightPanel.render(content), zIndex: 1);
canvas.paint(18, 14, bannerStyle.render(banner), zIndex: 2);

return newView(canvas.render());`,
      },
    ],
    api: {
      title: "Canvas",
      rows: [
        { name: "Canvas(width, height)", description: "Create a compositing surface of the given size." },
        { name: "paint(x, y, block, {zIndex})", description: "Draw a (possibly multi-line, styled) block at a position." },
        { name: "render()", description: "Flatten all layers into a single styled string." },
      ],
    },
    related: ["styling", "showcase"],
  },
  {
    slug: "package-manager",
    name: "Package manager",
    category: "blocks",
    order: 5,
    tagline: "Multi-step spinner + progress flow.",
    description:
      "A worked example composing a `SpinnerModel` and a `ProgressModel` into a realistic multi-step install flow — the kind of layered, stateful UI dart_tui is built for. Study it to see how child components are embedded and advanced through their own updates.",
    gif: "package_manager.gif",
    snippets: [
      {
        label: "Run it",
        lang: "bash",
        code: `dart run example/package_manager.dart`,
      },
    ],
    blocks: [
      {
        type: "prose",
        md: "The full source lives in `example/package_manager.dart`. It advances through a list of steps, showing a spinner while each 'downloads' and a progress bar for the overall install — a compact template for any long-running, multi-phase task.",
      },
    ],
    related: ["spinner", "progress-bar", "showcase"],
  },
  {
    slug: "showcase",
    name: "Showcase gallery",
    category: "blocks",
    order: 6,
    tagline: "The full-featured component gallery.",
    description:
      "A single program that puts the whole library through its paces — styling, borders, gradients, components and animation together. It's the demo at the top of the README and the fastest way to feel what dart_tui can render.",
    gif: "showcase.gif",
    snippets: [
      {
        label: "Run it",
        lang: "bash",
        code: `# JIT (source)
dart run example/showcase.dart

# Or the pre-built kernel snapshot (~3× faster startup)
make kernel EXAMPLE=showcase && dart run tool/bin/showcase.dill`,
      },
    ],
    blocks: [
      {
        type: "prose",
        md: "See also `example/all_features.dart` for a component-integration demo, and the [Examples](/guides/examples) guide for the full catalogue of 60 runnable programs.",
      },
    ],
    related: ["canvas", "styling"],
  },
];
