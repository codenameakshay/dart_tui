import { blocksToHtml, parseBlocks, type Block } from "./markdown.ts";

export interface ChangelogVersion {
  version: string;
  /** Anchor id, e.g. `3-0-0` for 3.0.0. */
  slug: string;
  /** ISO date (YYYY-MM-DD) when the heading has one. */
  date?: string;
  blocks: Block[];
}

export interface ChangelogOptions {
  /** GitHub repo URL; relative links and `#123` refs resolve against it. */
  repoUrl?: string;
}

const VERSION_HEADING = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\s+[-–—]\s+(\d{4}-\d{2}-\d{2}))?$/;

export function versionSlug(version: string): string {
  return version
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
}

/**
 * Split CHANGELOG.md into versions at each top-level semantic-version heading.
 * Returns versions newest first.
 */
export function parseChangelog(
  markdown: string,
  options: ChangelogOptions = {},
): ChangelogVersion[] {
  const sections: ChangelogVersion[] = [];
  let current: ChangelogVersion | undefined;
  for (const block of parseBlocks(markdown)) {
    if (block.type === "heading" && block.level === 2) {
      const heading = VERSION_HEADING.exec(block.text);
      if (!heading) {
        current?.blocks.push(block);
        continue;
      }
      const version = block.text.replace(/\s+[-–—]\s+\d{4}-\d{2}-\d{2}$/, "");
      current = {
        version,
        slug: versionSlug(version),
        ...(heading[6] ? { date: heading[6] } : {}),
        blocks: [],
      };
      sections.push(current);
    } else if (current) {
      current.blocks.push(block);
    }
  }

  const sorted = sections.sort((a, b) => compareVersions(b.version, a.version));
  const usedSlugs = new Set<string>();
  for (const section of sorted) {
    const base = section.slug;
    let candidate = base;
    let suffix = 2;
    while (usedSlugs.has(candidate) || usedSlugs.has(`${candidate}-title`)) {
      candidate = `${base}-${suffix++}`;
    }
    section.slug = candidate;
    usedSlugs.add(candidate);
    usedSlugs.add(`${candidate}-title`);
    section.blocks = resolveBlocks(section.blocks, options);
  }
  return sorted;
}

/** Compare semver-ish strings: core numbers, then pre-release < release, then build. */
export function compareVersions(a: string, b: string): number {
  const parse = (v: string) => {
    const [main, build = ""] = v.split("+");
    const dash = main.indexOf("-");
    const core = (dash < 0 ? main : main.slice(0, dash)).split(".").map(Number);
    const pre = dash < 0 ? null : main.slice(dash + 1);
    return { core, pre, build: build.split(".").map(Number) };
  };
  const pa = parse(a);
  const pb = parse(b);
  for (let i = 0; i < 3; i++) {
    const d = (pa.core[i] || 0) - (pb.core[i] || 0);
    if (d !== 0) return d;
  }
  if (pa.pre !== pb.pre) {
    if (pa.pre === null) return 1;
    if (pb.pre === null) return -1;
    const aa = pa.pre.split(".");
    const bb = pb.pre.split(".");
    for (let i = 0; i < Math.min(aa.length, bb.length); i++) {
      const an = /^\d+$/.test(aa[i]);
      const bn = /^\d+$/.test(bb[i]);
      if (an && bn) {
        const left = aa[i].replace(/^0+(?=\d)/, "");
        const right = bb[i].replace(/^0+(?=\d)/, "");
        if (left.length !== right.length) return left.length - right.length;
        const d = left < right ? -1 : left > right ? 1 : 0;
        if (d) return d;
      } else if (an !== bn) {
        return an ? -1 : 1;
      } else {
        const d = aa[i] < bb[i] ? -1 : aa[i] > bb[i] ? 1 : 0;
        if (d) return d;
      }
    }
    return aa.length - bb.length;
  }
  for (let i = 0; i < Math.max(pa.build.length, pb.build.length); i++) {
    const d = (pa.build[i] || 0) - (pb.build[i] || 0);
    if (d !== 0) return d;
  }
  return 0;
}

function resolveBlocks(blocks: Block[], options: ChangelogOptions): Block[] {
  const { repoUrl } = options;
  if (!repoUrl) return blocks;
  const fix = (text: string) => resolveInline(text, repoUrl);
  return blocks.map((b): Block => {
    switch (b.type) {
      case "heading":
      case "paragraph":
        return { ...b, text: fix(b.text) };
      case "list":
        return { ...b, items: b.items.map((item) => resolveBlocks(item, options)) };
      case "table":
        return { ...b, headers: b.headers.map(fix), rows: b.rows.map((r) => r.map(fix)) };
      case "code":
      case "thematicBreak":
        return b;
    }
  });
}

const INLINE_SPANS = /(`[^`]+`|\[[^\]]+\]\([^)\s]+\))/;

/**
 * Point repo-relative links at GitHub and turn `#123` into issue links.
 * Code spans are left alone.
 */
function resolveInline(text: string, repoUrl: string): string {
  return text
    .split(INLINE_SPANS)
    .map((part, i) => {
      if (i % 2 === 0) {
        return part.replace(/(^|[\s(])#(\d+)\b/g, `$1[#$2](${repoUrl}/issues/$2)`);
      }
      if (part.startsWith("`")) return part;
      return part.replace(/\]\(([^)\s]+)\)$/, (_, href: string) => {
        const absolute =
          /^[a-z][a-z0-9+.-]*:/i.test(href) || href.startsWith("#") || href.startsWith("//");
        if (absolute) return `](${href})`;
        return `](${repoUrl}/blob/main/${href.replace(/^\.?\//, "")})`;
      });
    })
    .join("");
}

export interface RssOptions {
  siteUrl: string;
  title: string;
  description: string;
}

function escapeXml(text: string): string {
  const valid = Array.from(text)
    .map((character) => {
      const code = character.codePointAt(0)!;
      const isValid =
        code === 0x9 ||
        code === 0xa ||
        code === 0xd ||
        (code >= 0x20 && code <= 0xd7ff) ||
        (code >= 0xe000 && code <= 0xfffd) ||
        (code >= 0x10000 && code <= 0x10ffff);
      return isValid ? character : "\uFFFD";
    })
    .join("");
  return valid
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&apos;");
}

function rfc822(date: string): string {
  return new Date(`${date}T00:00:00Z`).toUTCString();
}

/** RSS 2.0 feed with one item per version. */
export function buildRss(versions: ChangelogVersion[], options: RssOptions): string {
  const pageUrl = `${options.siteUrl}/changelog`;
  const latestDate = versions.find((v) => v.date)?.date;
  const items = versions
    .map((v) => {
      const link = `${pageUrl}#${v.slug}`;
      return [
        "    <item>",
        `      <title>${escapeXml(v.version)}</title>`,
        `      <link>${escapeXml(link)}</link>`,
        `      <guid isPermaLink="true">${escapeXml(link)}</guid>`,
        ...(v.date ? [`      <pubDate>${rfc822(v.date)}</pubDate>`] : []),
        `      <description>${escapeXml(blocksToHtml(v.blocks))}</description>`,
        "    </item>",
      ].join("\n");
    })
    .join("\n");

  return [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">',
    "  <channel>",
    `    <title>${escapeXml(options.title)}</title>`,
    `    <link>${escapeXml(pageUrl)}</link>`,
    `    <description>${escapeXml(options.description)}</description>`,
    "    <language>en</language>",
    `    <atom:link href="${escapeXml(`${pageUrl}/rss.xml`)}" rel="self" type="application/rss+xml"/>`,
    ...(latestDate ? [`    <lastBuildDate>${rfc822(latestDate)}</lastBuildDate>`] : []),
    items,
    "  </channel>",
    "</rss>",
    "",
  ].join("\n");
}
