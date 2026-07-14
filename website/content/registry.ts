export type Category = "components" | "blocks" | "guides";

export interface CodeSnippet {
  /** Tab label, e.g. "Usage", "Setup". Defaults to "Code". */
  label?: string;
  lang: string;
  code: string;
}

export interface ApiRow {
  name: string;
  type?: string;
  description: string;
}

export interface KeyRow {
  keys: string;
  action: string;
}

export type ContentBlock =
  | { type: "prose"; md: string }
  | { type: "heading"; text: string }
  | { type: "code"; lang: string; code: string; label?: string }
  | { type: "gif"; src: string; caption?: string }
  | { type: "table"; headers: string[]; rows: string[][] }
  | { type: "callout"; variant?: "note" | "warn"; md: string };

export interface DocEntry {
  slug: string;
  name: string;
  category: Category;
  /** Short one-liner for cards and the page subtitle. */
  tagline: string;
  /** Longer intro paragraph (supports minimal inline markdown). */
  description: string;
  /** GIF filename in /public/gifs (with extension). */
  gif?: string;
  /** Code shown in the preview/code tabs (or standalone when there is no gif). */
  snippets?: CodeSnippet[];
  api?: { title?: string; rows: ApiRow[] };
  keybindings?: KeyRow[];
  /** Extra long-form body rendered after the preview. Guides use this heavily. */
  blocks?: ContentBlock[];
  related?: string[];
  isNew?: boolean;
  featured?: boolean;
  /** Sort order within its category. */
  order?: number;
}

export const CATEGORY_META: Record<
  Category,
  { title: string; label: string; blurb: string }
> = {
  components: {
    title: "Components",
    label: "Components",
    blurb:
      "Drop-in, stateful widgets — spinners, tables, trees, inputs and more. Each is a TeaModel you embed in your own update/view loop.",
  },
  blocks: {
    title: "Blocks",
    label: "Blocks",
    blurb:
      "Higher-level building blocks — full forms, one-shot prompts, gum-style helpers, canvas compositing and styling primitives.",
  },
  guides: {
    title: "Guides",
    label: "Guides",
    blurb:
      "Learn the Model–Update–View architecture, commands, program options, styling and the runtime internals.",
  },
};
