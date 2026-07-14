import Image from "next/image";
import Link from "next/link";
import { ArrowLeft, ArrowRight, ArrowUpRight } from "lucide-react";
import {
  CATEGORY_META,
  getEntryBySlug,
  getSiblings,
  type DocEntry,
} from "@/content";
import { CodeBlock } from "@/components/code-block";
import { TerminalFrame } from "@/components/terminal-frame";
import { PreviewTabs, type PreviewTab } from "@/components/preview-tabs";
import { ContentBlocks } from "@/components/content-blocks";
import { CopyButton } from "@/components/copy-button";
import { InlineMarkdown } from "@/components/markdown";

export async function DocPage({ entry }: { entry: DocEntry }) {
  const meta = CATEGORY_META[entry.category];
  const { prev, next } = getSiblings(entry.category, entry.slug);
  const hasGif = Boolean(entry.gif);
  const snippets = entry.snippets ?? [];

  // Build the Preview/Code tab set when there's a GIF to show.
  let previewTabs: PreviewTab[] | null = null;
  if (hasGif) {
    const tabs: PreviewTab[] = [
      {
        id: "preview",
        label: "Preview",
        content: (
          <TerminalFrame title={`${entry.name.toLowerCase()} · dart_tui`}>
            <Image
              src={`/gifs/${entry.gif}`}
              alt={`${entry.name} demo`}
              width={900}
              height={520}
              unoptimized
              priority
              className="h-auto w-full rounded-md"
            />
          </TerminalFrame>
        ),
      },
    ];
    for (const [i, s] of snippets.entries()) {
      tabs.push({
        id: `code-${i}`,
        label: snippets.length > 1 ? (s.label ?? `Code ${i + 1}`) : "Code",
        content: <CodeBlock code={s.code} lang={s.lang} showChrome={false} />,
      });
    }
    previewTabs = tabs;
  }

  const isDocCategory =
    entry.category === "components" || entry.category === "blocks";

  return (
    <article className="mx-auto max-w-3xl">
      {/* Header */}
      <div className="mb-8">
        <div className="mb-3 flex items-center gap-2 text-sm">
          <Link
            href={`/${entry.category}`}
            className="text-muted-foreground transition-colors hover:text-foreground"
          >
            {meta.label}
          </Link>
          <span className="text-muted-foreground/50">/</span>
          <span className="text-foreground">{entry.name}</span>
        </div>
        <div className="flex flex-wrap items-center gap-3">
          <h1 className="text-3xl font-bold tracking-tight sm:text-4xl">
            {entry.name}
          </h1>
          {entry.isNew && (
            <span className="rounded-full bg-green/15 px-2.5 py-1 font-mono text-[11px] font-semibold uppercase tracking-wide text-green">
              New
            </span>
          )}
        </div>
        <p className="mt-3 text-lg leading-relaxed text-muted-foreground">
          <InlineMarkdown text={entry.description} />
        </p>
      </div>

      {/* Install hint for components & blocks */}
      {isDocCategory && (
        <div className="mb-8 flex flex-col gap-2 rounded-lg border border-border bg-card p-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <p className="text-sm font-medium">Install the package</p>
            <p className="text-xs text-muted-foreground">
              Every component ships in the single <code className="font-mono text-mauve">dart_tui</code> package.
            </p>
          </div>
          <div className="flex items-center gap-2 rounded-md border border-border bg-background px-3 py-2 font-mono text-sm">
            <span className="text-muted-foreground">$</span>
            <span>dart pub add dart_tui</span>
            <CopyButton value="dart pub add dart_tui" className="ml-1" />
          </div>
        </div>
      )}

      {/* Preview + code */}
      {previewTabs ? (
        <PreviewTabs tabs={previewTabs} />
      ) : (
        snippets.length > 0 && (
          <div className="flex flex-col gap-4">
            {snippets.map((s, i) => (
              <CodeBlock key={i} code={s.code} lang={s.lang} />
            ))}
          </div>
        )
      )}

      {/* Long-form body */}
      {entry.blocks && entry.blocks.length > 0 && (
        <div className="mt-10">
          <ContentBlocks blocks={entry.blocks} />
        </div>
      )}

      {/* API reference */}
      {entry.api && (
        <section className="mt-12">
          <h2 className="mb-4 text-xl font-semibold tracking-tight">
            {entry.api.title ?? "API"}
          </h2>
          <div className="overflow-x-auto rounded-lg border border-border">
            <table className="w-full border-collapse text-sm">
              <thead>
                <tr className="border-b border-border bg-muted/40 text-left">
                  <th className="px-4 py-2.5 font-mono text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                    Property
                  </th>
                  <th className="px-4 py-2.5 font-mono text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                    Type
                  </th>
                  <th className="px-4 py-2.5 font-mono text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                    Description
                  </th>
                </tr>
              </thead>
              <tbody>
                {entry.api.rows.map((row) => (
                  <tr
                    key={row.name}
                    className="border-b border-border/60 last:border-0"
                  >
                    <td className="whitespace-nowrap px-4 py-2.5 align-top font-mono text-[0.8rem] text-mauve">
                      {row.name}
                    </td>
                    <td className="whitespace-nowrap px-4 py-2.5 align-top font-mono text-[0.78rem] text-muted-foreground">
                      {row.type ?? "—"}
                    </td>
                    <td className="px-4 py-2.5 align-top text-muted-foreground">
                      {row.description}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}

      {/* Keybindings */}
      {entry.keybindings && entry.keybindings.length > 0 && (
        <section className="mt-12">
          <h2 className="mb-4 text-xl font-semibold tracking-tight">
            Keybindings
          </h2>
          <div className="overflow-hidden rounded-lg border border-border">
            {entry.keybindings.map((kb, i) => (
              <div
                key={i}
                className="flex items-center gap-4 border-b border-border/60 px-4 py-2.5 last:border-0"
              >
                <kbd className="shrink-0 rounded border border-border bg-muted px-2 py-1 font-mono text-xs text-foreground">
                  {kb.keys}
                </kbd>
                <span className="text-sm text-muted-foreground">
                  {kb.action}
                </span>
              </div>
            ))}
          </div>
        </section>
      )}

      {/* Related */}
      {entry.related && entry.related.length > 0 && (
        <section className="mt-12">
          <h2 className="mb-4 text-xl font-semibold tracking-tight">
            Related
          </h2>
          <div className="flex flex-wrap gap-2">
            {entry.related.map((slug) => {
              const rel = getEntryBySlug(slug);
              if (!rel) return null;
              return (
                <Link
                  key={slug}
                  href={`/${rel.category}/${rel.slug}`}
                  className="inline-flex items-center gap-1.5 rounded-full border border-border bg-card px-3 py-1.5 text-sm text-muted-foreground transition-colors hover:border-mauve/40 hover:text-foreground"
                >
                  {rel.name}
                  <ArrowUpRight className="h-3.5 w-3.5" />
                </Link>
              );
            })}
          </div>
        </section>
      )}

      {/* Prev / next */}
      <nav className="mt-16 flex items-stretch justify-between gap-4 border-t border-border pt-8">
        {prev ? (
          <Link
            href={`/${prev.category}/${prev.slug}`}
            className="group flex flex-1 flex-col items-start gap-1 rounded-lg border border-border bg-card p-4 transition-colors hover:border-mauve/40"
          >
            <span className="flex items-center gap-1 text-xs text-muted-foreground">
              <ArrowLeft className="h-3.5 w-3.5" /> Previous
            </span>
            <span className="font-medium text-foreground">{prev.name}</span>
          </Link>
        ) : (
          <span className="flex-1" />
        )}
        {next ? (
          <Link
            href={`/${next.category}/${next.slug}`}
            className="group flex flex-1 flex-col items-end gap-1 rounded-lg border border-border bg-card p-4 text-right transition-colors hover:border-mauve/40"
          >
            <span className="flex items-center gap-1 text-xs text-muted-foreground">
              Next <ArrowRight className="h-3.5 w-3.5" />
            </span>
            <span className="font-medium text-foreground">{next.name}</span>
          </Link>
        ) : (
          <span className="flex-1" />
        )}
      </nav>
    </article>
  );
}
