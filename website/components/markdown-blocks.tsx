import { TriangleAlert } from "lucide-react";
import type { Block } from "@/lib/markdown.ts";
import { CodeBlock } from "@/components/code-block";
import { InlineMarkdown } from "@/components/markdown";
import { cn } from "@/lib/utils";

/** Server component: renders parsed markdown blocks in the site's styles. */
export async function MarkdownBlocks({
  blocks,
  className,
}: {
  blocks: Block[];
  className?: string;
}) {
  const rendered = await Promise.all(blocks.map(renderBlock));
  return (
    <div className={cn("flex flex-col gap-4 break-words", className)}>
      {rendered}
    </div>
  );
}

async function renderBlock(block: Block, key: number) {
  switch (block.type) {
    case "heading": {
      const breaking = /^breaking changes/i.test(block.text);
      return (
        <h3
          key={key}
          className={cn(
            "flex items-center gap-2 pt-4 text-base font-semibold tracking-tight",
            breaking && "text-peach",
          )}
        >
          {breaking && <TriangleAlert className="h-4 w-4 shrink-0" />}
          <InlineMarkdown text={block.text} />
        </h3>
      );
    }

    case "paragraph":
      return (
        <p key={key} className="leading-relaxed text-muted-foreground">
          <InlineMarkdown text={block.text} />
        </p>
      );

    case "list": {
      const items = await Promise.all(
        block.items.map(async (item, i) => (
          <li key={i} className="pl-1 marker:text-muted-foreground/60">
            <MarkdownBlocks blocks={item} className="gap-3" />
          </li>
        )),
      );
      return (
        <ul key={key} className="flex list-disc flex-col gap-2.5 pl-5">
          {items}
        </ul>
      );
    }

    case "code":
      return (
        <CodeBlock
          key={key}
          code={block.code}
          lang={block.lang}
          showChrome={false}
        />
      );

    case "table":
      return (
        <div
          key={key}
          className="overflow-x-auto rounded-lg border border-border"
        >
          <table className="w-full border-collapse text-sm">
            <thead>
              <tr className="border-b border-border bg-muted/40 text-left">
                {block.headers.map((h, i) => (
                  <th
                    key={i}
                    className="px-4 py-2.5 font-mono text-xs font-semibold uppercase tracking-wider text-muted-foreground"
                  >
                    <InlineMarkdown text={h} />
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {block.rows.map((row, ri) => (
                <tr key={ri} className="border-b border-border/60 last:border-0">
                  {row.map((cell, ci) => (
                    <td
                      key={ci}
                      className="px-4 py-2.5 align-top text-muted-foreground"
                    >
                      <InlineMarkdown text={cell} />
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      );
  }
}
