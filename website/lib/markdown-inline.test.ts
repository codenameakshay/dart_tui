import assert from "node:assert/strict";
import { test } from "node:test";
import { buildRss, parseChangelog } from "./changelog.ts";
import { blocksToHtml, inlineToHtml, tokenizeInline } from "./markdown.ts";

test("preserves the four bold spans authored in the content registry", () => {
  const cases = [
    ["**Dart SDK ≥ 3.5**", "<strong>Dart SDK ≥ 3.5</strong>"],
    ["**pure function**", "<strong>pure function</strong>"],
    ["**visible terminal columns**", "<strong>visible terminal columns</strong>"],
    ["**Key properties:**", "<strong>Key properties:</strong>"],
  ];
  for (const [source, expected] of cases) {
    assert.equal(inlineToHtml(source), expected);
  }
});

test("preserves the four links authored in the content registry", () => {
  const cases = [
    [
      "[gum](https://github.com/charmbracelet/gum)",
      '<a href="https://github.com/charmbracelet/gum">gum</a>',
    ],
    [
      "[Examples](/guides/examples)",
      '<a href="/guides/examples">Examples</a>',
    ],
    [
      "[Model–Update–View](/guides/mvu-architecture)",
      '<a href="/guides/mvu-architecture">Model–Update–View</a>',
    ],
    [
      "[docs/performance.md](https://github.com/codenameakshay/dart_tui/blob/main/docs/performance.md)",
      '<a href="https://github.com/codenameakshay/dart_tui/blob/main/docs/performance.md">docs/performance.md</a>',
    ],
  ];
  for (const [source, expected] of cases) {
    assert.equal(inlineToHtml(source), expected);
  }
});

test("preserves surrounding text and adjacent code spans", () => {
  assert.equal(
    inlineToHtml("Every app is a `Program` running a `Model`."),
    "Every app is a <code>Program</code> running a <code>Model</code>.",
  );
  assert.deepEqual(tokenizeInline("`update` is a **pure function**."), [
    { type: "code", text: "update" },
    { type: "text", text: " is a " },
    { type: "strong", children: [{ type: "text", text: "pure function" }] },
    { type: "text", text: "." },
  ]);
});

test("renders code inside the changelog's bold API migration labels", () => {
  assert.equal(
    inlineToHtml("**`View.setContent` removed.** Assign the field instead:"),
    "<strong><code>View.setContent</code> removed.</strong> Assign the field instead:",
  );
});

test("renders the changelog's code-formatted documentation link label", () => {
  assert.equal(
    inlineToHtml(
      "[`docs/quality/2026-10-17-macos-3.0.0-validation.md`](docs/quality/2026-10-17-macos-3.0.0-validation.md)",
    ),
    '<a href="docs/quality/2026-10-17-macos-3.0.0-validation.md"><code>docs/quality/2026-10-17-macos-3.0.0-validation.md</code></a>',
  );
});

test("leaves whitespace-containing destinations as literal prose", () => {
  assert.equal(inlineToHtml("[doc](docs/a b.md)"), "[doc](docs/a b.md)");
  assert.equal(inlineToHtml("[doc](https://x.dev/a\nb)"), "[doc](https://x.dev/a\nb)");
  assert.equal(inlineToHtml("[doc](docs/a%20b.md)"), '<a href="docs/a%20b.md">doc</a>');
});

test("keeps code spans literal even when they contain markup and links", () => {
  assert.equal(
    inlineToHtml("`**bold** [doc](https://x.dev) <tag>`"),
    "<code>**bold** [doc](https://x.dev) &lt;tag&gt;</code>",
  );
});

test("escapes prose, code, link labels and double-quoted href attributes", () => {
  assert.equal(
    inlineToHtml('<img src=x onerror=alert(1)> & "quoted"'),
    "&lt;img src=x onerror=alert(1)&gt; &amp; &quot;quoted&quot;",
  );
  assert.equal(inlineToHtml("`<A&B>`"), "<code>&lt;A&amp;B&gt;</code>");
  assert.equal(
    inlineToHtml('[<b>&](https://x.dev/?q="<&n=1)'),
    '<a href="https://x.dev/?q=&quot;&lt;&amp;n=1">&lt;b&gt;&amp;</a>',
  );
  assert.equal(
    blocksToHtml([{ type: "code", lang: "html", code: "</code><script>x</script>" }]),
    "<pre><code>&lt;/code&gt;&lt;script&gt;x&lt;/script&gt;</code></pre>",
  );
});

test("retains safe absolute URLs, relative paths and fragment links", () => {
  for (const href of [
    "https://x.dev",
    "http://x.dev",
    "mailto:team@x.dev",
    "tel:+1234567",
    "/guides/examples",
    "docs/a.md",
    "../README.md",
    "#breaking-changes",
  ]) {
    assert.equal(inlineToHtml(`[doc](${href})`), `<a href="${href}">doc</a>`);
  }
});

test("rejects executable schemes before either renderer receives a link token", () => {
  for (const href of [
    "javascript:alert`1`",
    "JaVaScRiPt:alert`1`",
    "vbscript:msgbox`1`",
    "data:text/html,<script>alert`1`</script>",
  ]) {
    const source = `[run](${href})`;
    assert.deepEqual(tokenizeInline(source), [{ type: "text", text: "run" }], href);
    assert.equal(inlineToHtml(source), "run", href);
  }
});

test("rejects executable schemes after C0 controls are removed", () => {
  for (const href of ["java\u0001script:run", "java\u0000script:run"]) {
    const source = `[run](${href})`;
    assert.deepEqual(tokenizeInline(source), [{ type: "text", text: "run" }], href);
    assert.equal(inlineToHtml(source), "run", href);
  }
});

test("escapes entity-looking URL text without decoding it into a scheme", () => {
  assert.equal(
    inlineToHtml("[run](javascript&#58;alert`1`)"),
    '<a href="javascript&amp;#58;alert`1`">run</a>',
  );
});

test("does not turn whitespace-obfuscated schemes into links", () => {
  for (const href of ["java\nscript:run", "java\tscript:run", "\rjavascript:run"]) {
    const source = `[run](${href})`;
    assert.deepEqual(tokenizeInline(source), [{ type: "text", text: source }]);
    assert.equal(inlineToHtml(source), source);
  }
});

test("encodes RSS HTML once for HTML and once for its XML description", () => {
  const xml = buildRss(parseChangelog("## 1.0.0\n\n`<A&B>` & <img>\n"), {
    siteUrl: "https://example.dev",
    title: "Releases",
    description: "Notes",
  });
  assert.ok(
    xml.includes(
      "<description>&lt;p&gt;&lt;code&gt;&amp;lt;A&amp;amp;B&amp;gt;&lt;/code&gt; &amp;amp; &amp;lt;img&amp;gt;&lt;/p&gt;</description>",
    ),
  );
});

test("never emits executable link URLs in RSS descriptions", () => {
  const xml = buildRss(
    parseChangelog("## 1.0.0\n\n[run](javascript:alert`1`)\n", {
      repoUrl: "https://github.com/example/repo",
    }),
    { siteUrl: "https://example.dev", title: "Releases", description: "Notes" },
  );
  assert.ok(xml.includes("<description>&lt;p&gt;run&lt;/p&gt;</description>"));
});
