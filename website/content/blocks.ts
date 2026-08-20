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
      "Self-contained, one-shot flows built on `Program` — no model to write. Each returns a `Future` and accepts an `options` list so it can be scripted or tested headlessly. All return `null` when cancelled with `Esc`/`Ctrl+C`. Implicit default stdin supports one `Program` lifecycle per process; keep multi-step interaction inside one `Program`/`Form`, or pass an explicit stream with `withInput(...)`.",
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
      ],
    },
    related: ["forms", "gum-helpers"],
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

# Or the pre-built kernel snapshot (~2× faster startup)
make kernel EXAMPLE=showcase && dart run tool/bin/showcase.dill`,
      },
    ],
    blocks: [
      {
        type: "prose",
        md: "See also `example/all_features.dart` for a component-integration demo, and the [Examples](/guides/examples) guide for the full catalogue of 60+ runnable programs.",
      },
    ],
    related: ["canvas", "styling"],
  },
];
