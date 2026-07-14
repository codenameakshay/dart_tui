import type { Highlighter } from "shiki";
import { createHighlighter } from "shiki";

const THEMES = ["catppuccin-latte", "catppuccin-mocha"] as const;
const LANGS = ["dart", "bash", "yaml", "typescript", "tsx", "text"] as const;

let highlighterPromise: Promise<Highlighter> | null = null;

function getHighlighter() {
  if (!highlighterPromise) {
    highlighterPromise = createHighlighter({
      themes: [...THEMES],
      langs: [...LANGS],
    });
  }
  return highlighterPromise;
}

const langAlias: Record<string, (typeof LANGS)[number]> = {
  dart: "dart",
  sh: "bash",
  bash: "bash",
  shell: "bash",
  yaml: "yaml",
  yml: "yaml",
  ts: "typescript",
  typescript: "typescript",
  tsx: "tsx",
  text: "text",
  txt: "text",
};

/**
 * Render a code string to dual-theme HTML. The output carries `--shiki-light`
 * and `--shiki-dark` CSS vars per token; globals.css picks the right one based
 * on the `.dark` class on <html>.
 */
export async function highlight(code: string, lang = "dart"): Promise<string> {
  const highlighter = await getHighlighter();
  const resolved = langAlias[lang] ?? "text";
  return highlighter.codeToHtml(code.trimEnd(), {
    lang: resolved,
    themes: { light: "catppuccin-latte", dark: "catppuccin-mocha" },
    defaultColor: false,
  });
}
