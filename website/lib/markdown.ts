/**
 * A small markdown parser for the subset our own docs use: headings,
 * paragraphs, `-`/`*` lists (nested, with code inside items), fenced code and
 * GitHub-style tables, plus `code`, **bold** and [links](href) inline.
 *
 * It is pure (no React, no Node APIs) so pages, the RSS feed and the tests can
 * all share it. Imports between lib files use `.ts` extensions so
 * `node --test` can load them without a bundler.
 */

export type InlineToken =
  | { type: "text"; text: string }
  | { type: "code"; text: string }
  | { type: "strong"; children: InlineToken[] }
  | { type: "link"; href: string; children: InlineToken[] };

export type Block =
  | { type: "heading"; level: number; text: string }
  | { type: "paragraph"; text: string }
  | { type: "list"; items: Block[][] }
  | { type: "code"; lang: string; code: string }
  | { type: "table"; headers: string[]; rows: string[][] };

const INLINE_PATTERN = /(`[^`]+`)|(\*\*[^*]+\*\*)|(\[[^\]]+\]\([^)\s]+\))/g;

/** Split inline markdown into `code`, **bold**, [link](href) and text. */
export function tokenizeInline(text: string): InlineToken[] {
  const tokens: InlineToken[] = [];
  const pattern = new RegExp(INLINE_PATTERN);
  let last = 0;
  let match: RegExpExecArray | null;

  while ((match = pattern.exec(text)) !== null) {
    if (match.index > last) {
      tokens.push({ type: "text", text: text.slice(last, match.index) });
    }
    const token = match[0];
    if (token.startsWith("`")) {
      tokens.push({ type: "code", text: token.slice(1, -1) });
    } else if (token.startsWith("**")) {
      tokens.push({
        type: "strong",
        children: tokenizeInline(token.slice(2, -2)),
      });
    } else {
      const close = token.indexOf("](");
      tokens.push({
        type: "link",
        href: token.slice(close + 2, -1),
        children: tokenizeInline(token.slice(1, close)),
      });
    }
    last = pattern.lastIndex;
  }
  if (last < text.length) {
    tokens.push({ type: "text", text: text.slice(last) });
  }
  return tokens;
}

const FENCE_OPEN = /^(\s*)(`{3,}|~{3,})\s*([^\s`]*)/;
const HEADING = /^(#{1,6})\s+(.*?)(?:\s+#+)?\s*$/;
const LIST_ITEM = /^([-*])(\s+)(.*)$/;
const TABLE_DELIMITER = /^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$/;

function isBlank(line: string): boolean {
  return line.trim() === "";
}

function indentOf(line: string): number {
  return line.length - line.trimStart().length;
}

/** Remove up to `n` leading spaces. */
function dedent(line: string, n: number): string {
  let i = 0;
  while (i < n && i < line.length && line[i] === " ") i++;
  return line.slice(i);
}

/** True when `line` closes a fence opened with `marker`. */
export function closesFence(line: string, marker: string): boolean {
  const trimmed = line.trim();
  return (
    trimmed.length >= marker.length &&
    trimmed[0] === marker[0] &&
    /^(`+|~+)$/.test(trimmed)
  );
}

function startsTable(lines: string[], i: number): boolean {
  return (
    lines[i].trimStart().startsWith("|") &&
    i + 1 < lines.length &&
    lines[i + 1].includes("-") &&
    TABLE_DELIMITER.test(lines[i + 1])
  );
}

function startsBlock(lines: string[], i: number): boolean {
  const line = lines[i];
  return (
    FENCE_OPEN.test(line) ||
    HEADING.test(line) ||
    LIST_ITEM.test(line) ||
    startsTable(lines, i)
  );
}

/** Split a table row on `|`, ignoring pipes inside code spans or escaped. */
function splitRow(line: string): string[] {
  let row = line.trim();
  if (row.startsWith("|")) row = row.slice(1);
  if (row.endsWith("|") && !row.endsWith("\\|")) row = row.slice(0, -1);

  const cells: string[] = [];
  let cell = "";
  let inCode = false;
  for (let i = 0; i < row.length; i++) {
    const ch = row[i];
    if (ch === "\\" && row[i + 1] === "|") {
      cell += "|";
      i++;
    } else if (ch === "`") {
      inCode = !inCode;
      cell += ch;
    } else if (ch === "|" && !inCode) {
      cells.push(cell.trim());
      cell = "";
    } else {
      cell += ch;
    }
  }
  cells.push(cell.trim());
  return cells;
}

/** Parse block-level markdown into a flat list of blocks. */
export function parseBlocks(source: string | string[]): Block[] {
  const lines = typeof source === "string" ? source.split(/\r?\n/) : source;
  const blocks: Block[] = [];
  let i = 0;

  while (i < lines.length) {
    const line = lines[i];

    if (isBlank(line)) {
      i++;
      continue;
    }

    const fence = FENCE_OPEN.exec(line);
    if (fence) {
      const indent = fence[1].length;
      const marker = fence[2];
      const body: string[] = [];
      i++;
      while (i < lines.length && !closesFence(lines[i], marker)) {
        body.push(dedent(lines[i], indent));
        i++;
      }
      i++; // closing fence (or end of input)
      blocks.push({ type: "code", lang: fence[3] || "text", code: body.join("\n") });
      continue;
    }

    const heading = HEADING.exec(line);
    if (heading) {
      blocks.push({
        type: "heading",
        level: heading[1].length,
        text: heading[2],
      });
      i++;
      continue;
    }

    if (LIST_ITEM.test(line)) {
      const [list, next] = parseList(lines, i);
      blocks.push(list);
      i = next;
      continue;
    }

    if (startsTable(lines, i)) {
      const headers = splitRow(line);
      const rows: string[][] = [];
      i += 2;
      while (i < lines.length && lines[i].trimStart().startsWith("|")) {
        rows.push(splitRow(lines[i]));
        i++;
      }
      blocks.push({ type: "table", headers, rows });
      continue;
    }

    const para: string[] = [line.trim()];
    i++;
    while (i < lines.length && !isBlank(lines[i]) && !startsBlock(lines, i)) {
      para.push(lines[i].trim());
      i++;
    }
    blocks.push({ type: "paragraph", text: para.join(" ") });
  }

  return blocks;
}

/**
 * Parse the list that starts at `lines[start]`. Returns the list and the
 * index of the first line after it.
 */
function parseList(lines: string[], start: number): [Block, number] {
  const items: Block[][] = [];
  let i = start;

  while (i < lines.length) {
    const m = LIST_ITEM.exec(lines[i]);
    if (!m) break;

    const contentIndent = m[1].length + m[2].length;
    const itemLines = [m[3]];
    let fenceMarker: string | null = null;
    i++;

    while (i < lines.length) {
      const line = lines[i];

      if (fenceMarker) {
        itemLines.push(dedent(line, contentIndent));
        if (closesFence(line, fenceMarker)) fenceMarker = null;
        i++;
        continue;
      }

      if (isBlank(line)) {
        // A blank line keeps the item open only if indented content follows.
        let j = i;
        while (j < lines.length && isBlank(lines[j])) j++;
        if (j < lines.length && indentOf(lines[j]) >= contentIndent) {
          for (; i < j; i++) itemLines.push("");
          continue;
        }
        break;
      }

      if (indentOf(line) >= contentIndent) {
        const inner = dedent(line, contentIndent);
        const open = FENCE_OPEN.exec(inner);
        if (open && open[1] === "") fenceMarker = open[2];
        itemLines.push(inner);
        i++;
        continue;
      }

      // Lazy continuation of the item's paragraph.
      const previous = itemLines[itemLines.length - 1];
      if (!isBlank(previous) && !startsBlock(lines, i)) {
        itemLines.push(line.trim());
        i++;
        continue;
      }
      break;
    }

    items.push(parseBlocks(itemLines));

    // Blank lines between items do not end the list.
    let j = i;
    while (j < lines.length && isBlank(lines[j])) j++;
    if (j < lines.length && LIST_ITEM.test(lines[j])) {
      i = j;
      continue;
    }
    break;
  }

  return [{ type: "list", items }, i];
}

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

export function inlineToHtml(text: string): string {
  return tokensToHtml(tokenizeInline(text));
}

function tokensToHtml(tokens: InlineToken[]): string {
  return tokens
    .map((t) => {
      switch (t.type) {
        case "text":
          return escapeHtml(t.text);
        case "code":
          return `<code>${escapeHtml(t.text)}</code>`;
        case "strong":
          return `<strong>${tokensToHtml(t.children)}</strong>`;
        case "link":
          return `<a href="${escapeHtml(t.href)}">${tokensToHtml(t.children)}</a>`;
      }
    })
    .join("");
}

/** Render blocks to plain HTML (for feeds; pages use React components). */
export function blocksToHtml(blocks: Block[]): string {
  return blocks
    .map((b) => {
      switch (b.type) {
        case "heading":
          return `<h${b.level}>${inlineToHtml(b.text)}</h${b.level}>`;
        case "paragraph":
          return `<p>${inlineToHtml(b.text)}</p>`;
        case "list":
          return `<ul>${b.items
            .map((item) => `<li>${blocksToHtml(item)}</li>`)
            .join("")}</ul>`;
        case "code":
          return `<pre><code>${escapeHtml(b.code)}</code></pre>`;
        case "table": {
          const head = b.headers.map((h) => `<th>${inlineToHtml(h)}</th>`).join("");
          const body = b.rows
            .map(
              (r) => `<tr>${r.map((c) => `<td>${inlineToHtml(c)}</td>`).join("")}</tr>`,
            )
            .join("");
          return `<table><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table>`;
        }
      }
    })
    .join("");
}
