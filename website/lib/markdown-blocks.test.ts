import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { blocksToHtml, parseBlocks, type Block } from "./markdown.ts";

function findBlock(blocks: Block[], predicate: (block: Block) => boolean): Block | undefined {
  for (const block of blocks) {
    if (predicate(block)) return block;
    if (block.type === "list") {
      for (const item of block.items) {
        const nested = findBlock(item, predicate);
        if (nested) return nested;
      }
    }
  }
}

test("parses a fence that starts on the list item's first line", () => {
  assert.deepEqual(
    parseBlocks(
      "- ```markdown\n  ## 9.9.9 - 2099-01-01\n  ### Still code\n  ```\n- After the example.",
    ),
    [
      {
        type: "list",
        items: [
          [
            {
              type: "code",
              lang: "markdown",
              code: "## 9.9.9 - 2099-01-01\n### Still code",
            },
          ],
          [{ type: "paragraph", text: "After the example." }],
        ],
      },
    ],
  );
});

test("keeps nested list-start fences and following siblings separate", () => {
  assert.deepEqual(
    parseBlocks(
      "- Outer\n  - ```markdown\n    ## fake\n    ```\n- Sibling",
    ),
    [
      {
        type: "list",
        items: [
          [
            { type: "paragraph", text: "Outer" },
            {
              type: "list",
              items: [
                [
                  {
                    type: "code",
                    lang: "markdown",
                    code: "## fake",
                  },
                ],
              ],
            },
          ],
          [{ type: "paragraph", text: "Sibling" }],
        ],
      },
    ],
  );
});

test("tracks untagged fences in list items and leaves following prose outside", () => {
  assert.deepEqual(
    parseBlocks("- Example\n  ```\n  code\n  ```\nOutside."),
    [
      {
        type: "list",
        items: [
          [
            { type: "paragraph", text: "Example" },
            { type: "code", lang: "text", code: "code" },
          ],
        ],
      },
      { type: "paragraph", text: "Outside." },
    ],
  );
});

test("does not treat a thematic break after a list as another list item", () => {
  assert.deepEqual(parseBlocks("- Item\n* * *"), [
    {
      type: "list",
      items: [[{ type: "paragraph", text: "Item" }]],
    },
    { type: "thematicBreak" },
  ]);
});

test("keeps fences with up to three extra spaces inside list items", () => {
  for (const extraSpaces of [1, 2, 3]) {
    const fenceIndent = " ".repeat(2 + extraSpaces);
    assert.deepEqual(
      parseBlocks(
        `- Example\n${fenceIndent}\`\`\`dart\n${fenceIndent}final value = 1;\n${fenceIndent}\`\`\`\nMore detail.`,
      ),
      [
        {
          type: "list",
          items: [
            [
              { type: "paragraph", text: "Example" },
              { type: "code", lang: "dart", code: "final value = 1;" },
            ],
          ],
        },
        { type: "paragraph", text: "More detail." },
      ],
      `fence indented ${extraSpaces} spaces beyond the list content`,
    );
  }
});

test("does not attach unindented text after a closed fence to the list item", () => {
  assert.deepEqual(
    parseBlocks("- Example\n  ```dart\n    final value = 1;\n  ```\nMore detail."),
    [
      {
        type: "list",
        items: [
          [
            { type: "paragraph", text: "Example" },
            { type: "code", lang: "dart", code: "  final value = 1;" },
          ],
        ],
      },
      { type: "paragraph", text: "More detail." },
    ],
  );
});

test("recognizes and renders thematic breaks in the real changelog", () => {
  const source = readFileSync(new URL("../../CHANGELOG.md", import.meta.url), "utf8");
  const blocks = parseBlocks(source);
  const breaks = blocks.filter((block) => block.type === "thematicBreak");
  assert.equal(breaks.length, 2);
  assert.deepEqual(blocksToHtml(breaks), "<hr /><hr />");
});

test("preserves the real changelog table cells", () => {
  const source = readFileSync(new URL("../../CHANGELOG.md", import.meta.url), "utf8");
  const blocks = parseBlocks(source);
  const table = findBlock(blocks,
    (block) => block.type === "table" && block.headers[0] === "Example",
  );
  assert.deepEqual(table, {
    type: "table",
    headers: ["Example", "What it shows"],
    rows: [
      ["`cursor_model.dart`", "`CursorModel` — all three blink modes side-by-side, toggle blink with `b`"],
      ["`multi_select.dart`", "`MultiSelectModel` — toggle, select-all, confirm, display result"],
    ],
  });

});

test("preserves the real changelog nested list items", () => {
  const source = readFileSync(new URL("../../CHANGELOG.md", import.meta.url), "utf8");
  const blocks = parseBlocks(source);
  const multiSelect = findBlock(
    blocks,
    (block) => block.type === "paragraph" && block.text.startsWith("**`MultiSelectModel`"),
  );
  assert.ok(multiSelect && multiSelect.type === "paragraph");
  const features = findBlock(blocks, (block) =>
    block.type === "list" && block.items[0]?.[0]?.type === "paragraph" &&
    block.items[0][0].text === "`wrap: bool` — cursor wraps at list boundaries",
  );
  assert.deepEqual(features, {
    type: "list",
    items: [
      [{ type: "paragraph", text: "`wrap: bool` — cursor wraps at list boundaries" }],
      [{ type: "paragraph", text: "`height` — viewport limiting" }],
      [{ type: "paragraph", text: "`showStatusBar` — `\"N/Total selected\"` footer" }],
      [{ type: "paragraph", text: "`selectedValues` getter — returns custom `value` or falls back to `label`" }],
      [{ type: "paragraph", text: "`MultiSelectStyles` for full per-element theming (Catppuccin Mocha defaults)" }],
    ],
  });
});

test("keeps exact nested-list and table structure", () => {
  assert.deepEqual(
    parseBlocks(
      "- Parent\n  - Child\n    - Grandchild\n\n| Example | What it shows |\n|---------|---------------|\n| `cursor_model.dart` | Cursor modes |",
    ),
    [
      {
        type: "list",
        items: [
          [
            { type: "paragraph", text: "Parent" },
            {
              type: "list",
              items: [
                [
                  { type: "paragraph", text: "Child" },
                  {
                    type: "list",
                    items: [[{ type: "paragraph", text: "Grandchild" }]],
                  },
                ],
              ],
            },
          ],
        ],
      },
      {
        type: "table",
        headers: ["Example", "What it shows"],
        rows: [["`cursor_model.dart`", "Cursor modes"]],
      },
    ],
  );
});

test("keeps fenced headings and trailing heading text in their proper blocks", () => {
  assert.deepEqual(
    parseBlocks(
      "## Section ### trailing words\n\n```markdown\n## 4.5.6 - 2099-01-01\n```\n\n## Next section",
    ),
    [
      { type: "heading", level: 2, text: "Section ### trailing words" },
      {
        type: "code",
        lang: "markdown",
        code: "## 4.5.6 - 2099-01-01",
      },
      { type: "heading", level: 2, text: "Next section" },
    ],
  );
});

