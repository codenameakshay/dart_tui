import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { buildRss, compareVersions, parseChangelog } from "./changelog.ts";

const SAMPLE = `# Changelog

## 1.1.0 - 2026-02-01

Intro paragraph that wraps
onto a second line.

### Breaking changes

- **\`View.setContent\` removed.** Assign the field instead:
  \`view.content = 'Hello';\`.
- **Ctrl+C is a key.** Handle it in \`update\`.
  \`\`\`dart
  if (msg is KeyMsg) {
    return (this, quit);
  }
  \`\`\`

### Fixes

- Fixed a hang (#15).

## 1.0.1 - 2026-01-15

- First bullet.
- Second bullet
  that wraps.
  - Nested bullet.

## 1.0.0 - 2026-01-01

Heading lookalikes inside a fence stay code:

\`\`\`markdown
## 9.9.9 - 2099-01-01
### Not a heading
\`\`\`

- After the fence.
`;

const versions = parseChangelog(SAMPLE, {
  repoUrl: "https://github.com/example/repo",
});

test("splits versions newest first with anchors and dates", () => {
  assert.deepEqual(
    versions.map((v) => [v.version, v.slug, v.date]),
    [
      ["1.1.0", "1-1-0", "2026-02-01"],
      ["1.0.1", "1-0-1", "2026-01-15"],
      ["1.0.0", "1-0-0", "2026-01-01"],
    ],
  );
});

test("parses a version with breaking changes", () => {
  const [intro, breaking, list, fixes, fixList] = versions[0].blocks;
  assert.deepEqual(intro, {
    type: "paragraph",
    text: "Intro paragraph that wraps onto a second line.",
  });
  assert.deepEqual(breaking, { type: "heading", level: 3, text: "Breaking changes" });
  assert.equal(list.type, "list");
  if (list.type !== "list") return;
  assert.equal(list.items.length, 2);
  assert.deepEqual(list.items[0], [
    {
      type: "paragraph",
      text: "**`View.setContent` removed.** Assign the field instead: `view.content = 'Hello';`.",
    },
  ]);
  assert.deepEqual(list.items[1], [
    { type: "paragraph", text: "**Ctrl+C is a key.** Handle it in `update`." },
    {
      type: "code",
      lang: "dart",
      code: "if (msg is KeyMsg) {\n  return (this, quit);\n}",
    },
  ]);
  assert.deepEqual(fixes, { type: "heading", level: 3, text: "Fixes" });
  assert.deepEqual(fixList, {
    type: "list",
    items: [
      [
        {
          type: "paragraph",
          text: "Fixed a hang ([#15](https://github.com/example/repo/issues/15)).",
        },
      ],
    ],
  });
});

test("parses a version with only bullets", () => {
  assert.deepEqual(versions[1].blocks, [
    {
      type: "list",
      items: [
        [{ type: "paragraph", text: "First bullet." }],
        [
          { type: "paragraph", text: "Second bullet that wraps." },
          {
            type: "list",
            items: [[{ type: "paragraph", text: "Nested bullet." }]],
          },
        ],
      ],
    },
  ]);
});

test('keeps "## " inside a code fence as code', () => {
  assert.equal(versions.length, 3);
  assert.deepEqual(versions[2].blocks, [
    { type: "paragraph", text: "Heading lookalikes inside a fence stay code:" },
    {
      type: "code",
      lang: "markdown",
      code: "## 9.9.9 - 2099-01-01\n### Not a heading",
    },
    {
      type: "list",
      items: [[{ type: "paragraph", text: "After the fence." }]],
    },
  ]);
});

test("orders versions by semver, not by file order", () => {
  const out = parseChangelog("## 1.0.0\n\n## 1.0.0+1\n\n## 1.10.0\n\n## 1.9.0\n");
  assert.deepEqual(
    out.map((v) => v.version),
    ["1.10.0", "1.9.0", "1.0.0+1", "1.0.0"],
  );
  assert.equal(out[2].slug, "1-0-0-1");
  assert.ok(compareVersions("2.0.0", "2.0.0-beta.1") > 0);
});

test("leaves code spans and absolute links alone when resolving links", () => {
  const [v] = parseChangelog(
    "## 1.0.0\n\nSee [doc](docs/a.md), [site](https://x.dev) and `#7`.\n",
    { repoUrl: "https://github.com/example/repo" },
  );
  assert.deepEqual(v.blocks, [
    {
      type: "paragraph",
      text: "See [doc](https://github.com/example/repo/blob/main/docs/a.md), [site](https://x.dev) and `#7`.",
    },
  ]);
});

test("builds one RSS item per version", () => {
  const xml = buildRss(versions, {
    siteUrl: "https://example.dev",
    title: "Changelog",
    description: "Release notes",
  });
  assert.equal(xml.match(/<item>/g)?.length, 3);
  assert.match(xml, /<link>https:\/\/example\.dev\/changelog#1-1-0<\/link>/);
  assert.match(xml, /<pubDate>Sun, 01 Feb 2026 00:00:00 GMT<\/pubDate>/);
  assert.match(xml, /&lt;h3&gt;Breaking changes&lt;\/h3&gt;/);
  assert.doesNotMatch(xml, /<h3>/);
});

test("parses the real CHANGELOG.md", () => {
  const source = readFileSync(new URL("../../CHANGELOG.md", import.meta.url), "utf8");
  const real = parseChangelog(source);
  assert.ok(real.length > 5);
  const slugs = real.map((v) => v.slug);
  assert.equal(new Set(slugs).size, slugs.length, "anchors are unique");
  for (const v of real) assert.ok(v.blocks.length > 0, `${v.version} has content`);
});
