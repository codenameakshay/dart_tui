import type { DocEntry } from "./registry";

// Runtime/recipe demos. The `snippets` are injected at build time from the
// real source files in content/examples-src/<slug>.dart (see lib/examples.ts).
export const examples: DocEntry[] = [
  {
    slug: "views",
    name: "Multiple views",
    category: "examples",
    order: 1,
    featured: true,
    tagline: "Switch between screens — a task list into a download progress view.",
    description:
      "A two-view app that swaps its entire screen based on state: a task list that transitions into a download progress view. The canonical pattern for wizards, multi-step flows and screen routing.",
    gif: "views.gif",
    related: ["progress-bar", "list", "mvu-architecture"],
  },
  {
    slug: "shopping-list",
    name: "Shopping list",
    category: "examples",
    order: 2,
    featured: true,
    tagline: "The Bubble Tea shopping-list tutorial, ported to Dart.",
    description:
      "The classic Bubble Tea tutorial: a keyboard-navigable checklist you can move through and toggle. A complete, self-contained model that's a great first thing to read end-to-end.",
    gif: "shopping_list.gif",
    related: ["select-list", "multi-select", "mvu-architecture"],
  },
  {
    slug: "realtime",
    name: "Real-time updates",
    category: "examples",
    order: 3,
    featured: true,
    tagline: "Feed background async work back into the UI as messages.",
    description:
      "Kicks off background async work from `init()` and streams results back into the model as messages — the idiomatic way to integrate timers, sockets or any producer without blocking the event loop.",
    gif: "realtime.gif",
    related: ["commands", "send-msg", "spinner"],
  },
  {
    slug: "send-msg",
    name: "Program.send()",
    category: "examples",
    order: 4,
    tagline: "Inject messages into a running program from the outside.",
    description:
      "Demonstrates `Program.send()` — pushing a message into a running program from an external timer or callback. Useful for bridging non-Dart-TUI event sources into the update loop.",
    gif: "send_msg.gif",
    related: ["realtime", "commands"],
  },
  {
    slug: "sequence",
    name: "Sequenced commands",
    category: "examples",
    order: 5,
    tagline: "Run commands strictly one after another with sequence().",
    description:
      "Shows `sequence([...])` running commands strictly in order — each completing before the next begins — versus `batch([...])` which fires them concurrently.",
    gif: "sequence.gif",
    related: ["commands", "realtime"],
  },
  {
    slug: "prevent-quit",
    name: "Prevent quit",
    category: "examples",
    order: 6,
    tagline: "Intercept quit and ask for confirmation before exiting.",
    description:
      "Intercepts the quit key and asks the user to confirm before exiting — the pattern for guarding against accidental exits with unsaved work.",
    gif: "prevent_quit.gif",
    related: ["program-options", "commands"],
  },
  {
    slug: "focus-blur",
    name: "Focus & blur",
    category: "examples",
    order: 7,
    tagline: "React to the terminal gaining or losing focus.",
    description:
      "Reports terminal focus and blur events (`FocusMsg` / `BlurMsg`), enabled with `withReportFocus()`. Dim your UI when the window loses focus, or pause animations to save cycles.",
    gif: "focus_blur.gif",
    related: ["program-options"],
  },
  {
    slug: "print-key",
    name: "Print key",
    category: "examples",
    order: 8,
    tagline: "Inspect the decoded name of every key press.",
    description:
      "Shows the decoded name of each key press — handy for discovering exactly what `KeyMsg.key` string a chord produces (`ctrl+a`, `alt+left`, `shift+tab`, …) while building your keymaps.",
    gif: "print_key.gif",
    related: ["help", "text-input"],
  },
  {
    slug: "window-size",
    name: "Window size",
    category: "examples",
    order: 9,
    tagline: "Read terminal dimensions and respond to resizes.",
    description:
      "Displays the terminal's width and height and updates live on resize via `WindowSizeMsg` — the basis for any responsive, full-screen layout.",
    gif: "window_size.gif",
    related: ["program-options", "canvas"],
  },
  {
    slug: "fullscreen",
    name: "Fullscreen",
    category: "examples",
    order: 10,
    tagline: "A full-screen alt-screen app with a countdown.",
    description:
      "A full-screen program on the alternate screen buffer with a live countdown. On exit, the primary screen is restored exactly as it was — no scrollback clutter.",
    gif: "fullscreen.gif",
    related: ["altscreen-toggle", "program-options"],
  },
  {
    slug: "altscreen-toggle",
    name: "Alt-screen toggle",
    category: "examples",
    order: 11,
    tagline: "Switch between the primary and alternate screen at runtime.",
    description:
      "Toggles the alternate screen buffer on and off with the spacebar, showing how `enterAltScreen()` / `exitAltScreen()` work and how the terminal state is preserved across the switch.",
    gif: "altscreen_toggle.gif",
    related: ["fullscreen", "program-options"],
  },
  {
    slug: "set-window-title",
    name: "Set window title",
    category: "examples",
    order: 12,
    tagline: "Set the terminal window/tab title from your view.",
    description:
      "Sets the terminal window or tab title via `View.windowTitle` (OSC), so your app can reflect its current state right in the window chrome.",
    gif: "set_window_title.gif",
    related: ["program-options", "commands"],
  },
  {
    slug: "cursor-style",
    name: "Cursor style",
    category: "examples",
    order: 13,
    tagline: "Configure the real terminal cursor's shape and blink.",
    description:
      "Demonstrates the terminal cursor's shape and blink settings — block, underline or bar, steady or blinking — distinct from the in-line `CursorModel` widget.",
    gif: "cursor_style.gif",
    related: ["cursor", "program-options"],
  },
  {
    slug: "pipe",
    name: "Piped input",
    category: "examples",
    order: 14,
    tagline: "Seed a program from piped stdin.",
    description:
      "Reads piped stdin as the initial value of a text input — e.g. `echo \"hello\" | dart run example/pipe.dart` — so your TUI can compose with shell pipelines.",
    gif: "pipe.gif",
    related: ["text-input", "commands"],
  },
  {
    slug: "vanish",
    name: "Vanish",
    category: "examples",
    order: 15,
    tagline: "A single keystroke, then a clean exit with no trace.",
    description:
      "A minimal program that reads one keystroke and quits. Because it runs on the alternate screen, nothing it drew remains after it exits — the terminal is left pristine.",
    gif: "vanish.gif",
    related: ["fullscreen", "altscreen-toggle"],
  },
  {
    slug: "prompts-chain",
    name: "Chained prompts",
    category: "examples",
    order: 16,
    tagline: "Run promptSelect → promptConfirm → promptInput in sequence.",
    description:
      "Chains the one-shot prompts — `promptSelect`, then `promptConfirm`, then `promptInput` — each running its own `Program`, to build a quick scripted questionnaire without writing a model.",
    gif: "prompts_chain.gif",
    related: ["prompts", "forms"],
  },
];
