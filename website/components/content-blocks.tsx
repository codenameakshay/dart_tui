import Image from "next/image";
import { Info, TriangleAlert } from "lucide-react";
import type { ContentBlock } from "@/content";
import { CodeBlock } from "@/components/code-block";
import { TerminalFrame } from "@/components/terminal-frame";
import { InlineMarkdown } from "@/components/markdown";

function slugify(text: string) {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
}

export async function ContentBlocks({ blocks }: { blocks: ContentBlock[] }) {
  const rendered = await Promise.all(
    blocks.map((block, i) => renderBlock(block, i)),
  );
  return <div className="flex flex-col gap-6">{rendered}</div>;
}

async function renderBlock(block: ContentBlock, key: number) {
  switch (block.type) {
    case "heading":
      return (
        <h2
          key={key}
          id={slugify(block.text)}
          className="scroll-mt-24 pt-2 text-xl font-semibold tracking-tight"
        >
          {block.text}
        </h2>
      );

    case "prose":
      return (
        <p key={key} className="leading-relaxed text-muted-foreground">
          <InlineMarkdown text={block.md} />
        </p>
      );

    case "code":
      return (
        <CodeBlock key={key} code={block.code} lang={block.lang} />
      );

    case "gif":
      return (
        <figure key={key} className="my-1">
          <TerminalFrame>
            <Image
              src={`/gifs/${block.src}`}
              alt={block.caption ?? "dart_tui demo"}
              width={900}
              height={520}
              unoptimized
              className="h-auto w-full rounded-md"
            />
          </TerminalFrame>
          {block.caption && (
            <figcaption className="mt-2 text-center text-xs text-muted-foreground">
              {block.caption}
            </figcaption>
          )}
        </figure>
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
                {block.headers.map((h) => (
                  <th
                    key={h}
                    className="px-4 py-2.5 font-mono text-xs font-semibold uppercase tracking-wider text-muted-foreground"
                  >
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {block.rows.map((row, ri) => (
                <tr
                  key={ri}
                  className="border-b border-border/60 last:border-0"
                >
                  {row.map((cell, ci) => (
                    <td
                      key={ci}
                      className={
                        ci === 0
                          ? "px-4 py-2.5 align-top font-mono text-[0.8rem] text-foreground"
                          : "px-4 py-2.5 align-top text-muted-foreground"
                      }
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

    case "callout": {
      const warn = block.variant === "warn";
      return (
        <div
          key={key}
          className={
            warn
              ? "flex gap-3 rounded-lg border border-peach/30 bg-peach/[0.06] p-4 text-sm"
              : "flex gap-3 rounded-lg border border-sky/30 bg-sky/[0.06] p-4 text-sm"
          }
        >
          {warn ? (
            <TriangleAlert className="mt-0.5 h-4 w-4 shrink-0 text-peach" />
          ) : (
            <Info className="mt-0.5 h-4 w-4 shrink-0 text-sky" />
          )}
          <div className="leading-relaxed text-muted-foreground">
            <InlineMarkdown text={block.md} />
          </div>
        </div>
      );
    }
  }
}
