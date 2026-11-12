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

test("returns no versions for an empty changelog", () => {
  assert.deepEqual(parseChangelog(""), []);
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

test("orders prerelease identifiers according to semver", () => {
  assert.ok(compareVersions("1.0.0-alpha", "1.0.0-alpha.1") < 0);
  assert.ok(compareVersions("1.0.0-1", "1.0.0-alpha") < 0);
  assert.ok(compareVersions("1.0.0-Z", "1.0.0-a") < 0);
  assert.ok(
    compareVersions("1.0.0-9007199254740992", "1.0.0-9007199254740993") < 0,
  );
});

test("accepts ATX closing hashes on version headings", () => {
  const out = parseChangelog("## 1.0.0 ###\n\nFirst.\n");
  assert.deepEqual(out.map((v) => v.version), ["1.0.0"]);
});

test("keeps anchors unique when distinct versions normalize to the same slug", () => {
  const out = parseChangelog(
    "## 1.0.0-a+b\n\nFirst.\n\n## 1.0.0-a-b\n\nSecond.\n",
  );
  assert.equal(new Set(out.map((v) => v.slug)).size, 2);
});

test("keeps release anchors distinct from release title IDs", () => {
  const out = parseChangelog(
    "## 1.0.0\n\nReleased.\n\n## 1.0.0-title\n\nPrerelease.\n",
  );
  assert.deepEqual(out.map((v) => v.slug), ["1-0-0", "1-0-0-title-2"]);
  const ids = out.flatMap((v) => [v.slug, `${v.slug}-title`]);
  assert.equal(new Set(ids).size, ids.length);
});

test("does not treat non-version headings as releases", () => {
  assert.deepEqual(parseChangelog("## Notes\n\nNot a release.\n"), []);
});

test("keeps non-version level-two headings inside the current release", () => {
  const [version] = parseChangelog(
    "## 1.0.0\n\nRelease intro.\n\n## Migration notes\n\nDetails stay with the release.\n",
  );
  assert.deepEqual(version.blocks, [
    { type: "paragraph", text: "Release intro." },
    { type: "heading", level: 2, text: "Migration notes" },
    { type: "paragraph", text: "Details stay with the release." },
  ]);
});

test("ignores a fenced version-like heading when the fence starts in a list item", () => {
  const out = parseChangelog(
    "## 1.0.0\n\n- ```markdown\n  ## 9.9.9 - 2099-01-01\n  ```\n\n## 0.9.0\n\nOlder release.\n",
  );
  assert.deepEqual(out.map((v) => v.version), ["1.0.0", "0.9.0"]);
});

test("preserves releases and siblings after a deeply nested list fence", () => {
  const out = parseChangelog(
    "## 1.0.0\n\n- Outer\n  - Middle\n    - ```markdown\n      ## 9.9.9\n      ```\n- Sibling\n\n## 0.9.0\n\nOlder release.\n",
  );
  assert.deepEqual(out.map((v) => v.version), ["1.0.0", "0.9.0"]);
  assert.deepEqual(out[0].blocks, [
    {
      type: "list",
      items: [
        [
          { type: "paragraph", text: "Outer" },
          {
            type: "list",
            items: [
              [
                { type: "paragraph", text: "Middle" },
                {
                  type: "list",
                  items: [[{ type: "code", lang: "markdown", code: "## 9.9.9" }]],
                },
              ],
            ],
          },
        ],
        [{ type: "paragraph", text: "Sibling" }],
      ],
    },
  ]);
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

test("preserves protocol-relative links", () => {
  const [v] = parseChangelog(
    "## 1.0.0\n\nSee [cdn](//cdn.example/x).\n",
    { repoUrl: "https://github.com/example/repo" },
  );
  assert.deepEqual(v.blocks, [
    {
      type: "paragraph",
      text: "See [cdn](//cdn.example/x).",
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
  assert.match(xml, /<guid isPermaLink="true">https:\/\/example\.dev\/changelog#1-1-0<\/guid>/);
  assert.match(xml, /<atom:link href="https:\/\/example\.dev\/changelog\/rss\.xml" rel="self" type="application\/rss\+xml"\/>/);
  assert.match(xml, /<description>Release notes<\/description>/);
  assert.match(xml, /<language>en<\/language>/);
  assert.match(xml, /<pubDate>Sun, 01 Feb 2026 00:00:00 GMT<\/pubDate>/);
  assert.match(xml, /&lt;h3&gt;Breaking changes&lt;\/h3&gt;/);
  assert.doesNotMatch(xml, /<h3>/);
});

test("builds a valid channel for an empty changelog", () => {
  const xml = buildRss([], {
    siteUrl: "https://example.dev",
    title: "Changelog",
    description: "Release notes",
  });
  assert.match(xml, /<rss version="2\.0"/);
  assert.match(xml, /<channel>[\s\S]*<\/channel>/);
  assert.doesNotMatch(xml, /<item>/);
});

test("omits publication dates for undated versions", () => {
  const xml = buildRss(
    [{ version: "1.0.0", slug: "1-0-0", blocks: [] }],
    { siteUrl: "https://example.dev", title: "Changelog", description: "Release notes" },
  );
  assert.match(xml, /<item>[\s\S]*<\/item>/);
  assert.doesNotMatch(xml, /<pubDate>/);
  assert.doesNotMatch(xml, /<lastBuildDate>/);
});

test("RSS escapes XML text and replaces characters forbidden by XML 1.0", () => {
  const xml = buildRss(
    [{
      version: '1.0.0 & <release>',
      slug: "1-0-0",
      blocks: [{ type: "paragraph", text: "Keep & <tags>; drop \u0001 and \u000b. [link](https://example.dev/?a=1&b=2)" }],
    }],
    {
      siteUrl: "https://example.dev",
      title: 'A "title" & release',
      description: "Release notes",
    },
  );
  assert.match(xml, /<title>1\.0\.0 &amp; &lt;release&gt;<\/title>/);
  assert.match(xml, /<title>A &quot;title&quot; &amp; release<\/title>/);
  assert.match(xml, /Keep &amp;amp; &amp;lt;tags&amp;gt;; drop \uFFFD and \uFFFD\./);
  assert.match(xml, /&amp;amp;b=2/);
  assert.doesNotMatch(xml, /[\u0001\u000b]/);
});

test("RSS serialization does not synthesize executable schemes from invalid XML characters", () => {
  for (const invalid of ["\uFFFE", "\uFFFF", "\uD800", "\uDC00"]) {
    const xml = buildRss(
      parseChangelog(`## 1.0.0\n\n[run](java${invalid}script:alert\`1\`)\n`),
      { siteUrl: "https://example.dev", title: "Releases", description: "Notes" },
    );
    assert.ok(
      xml.includes(
        '<description>&lt;p&gt;&lt;a href=&quot;java\uFFFDscript:alert`1`&quot;&gt;run&lt;/a&gt;&lt;/p&gt;</description>',
      ),
    );
    assert.doesNotMatch(xml, /href=&quot;javascript:/);
  }
});

test("parses the real CHANGELOG.md", () => {
  const source = readFileSync(new URL("../../CHANGELOG.md", import.meta.url), "utf8");
  const real = parseChangelog(source);
  assert.ok(real.length > 5);
  assert.deepEqual(real.map((v) => v.version), [
    "3.0.0", "2.1.0", "2.0.0", "1.4.0", "1.3.0", "1.2.0", "1.1.0", "1.0.0+1", "1.0.0", "0.1.0",
  ]);
  assert.deepEqual(real.map((v) => v.date), [
    "2026-10-17", "2026-09-10", "2026-08-08", undefined, undefined, undefined, undefined, undefined, undefined, undefined,
  ]);
  const slugs = real.map((v) => v.slug);
  assert.equal(new Set(slugs).size, slugs.length, "anchors are unique");
  for (const v of real) assert.ok(v.blocks.length > 0, `${v.version} has content`);
});
