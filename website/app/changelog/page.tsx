import type { Metadata } from "next";
import { Rss } from "lucide-react";
import { getChangelog } from "@/lib/changelog-source";
import { MarkdownBlocks } from "@/components/markdown-blocks";
import { siteConfig } from "@/lib/utils";

const description = `Every ${siteConfig.name} release, newest first: breaking changes, fixes and new features.`;

export const metadata: Metadata = {
  title: "Changelog",
  description,
  alternates: {
    canonical: "/changelog",
    types: {
      "application/rss+xml": [
        { url: "/changelog/rss.xml", title: `${siteConfig.name} releases` },
      ],
    },
  },
};

function formatDate(date: string): string {
  return new Date(`${date}T00:00:00Z`).toLocaleDateString("en-US", {
    year: "numeric",
    month: "long",
    day: "numeric",
    timeZone: "UTC",
  });
}

export default function ChangelogPage() {
  const versions = getChangelog();

  return (
    <div className="container flex gap-10">
      <aside className="sticky top-16 hidden h-[calc(100vh-4rem)] w-60 shrink-0 overflow-y-auto py-10 md:block">
        <p className="mb-2 px-2 font-mono text-xs font-semibold uppercase tracking-wider text-muted-foreground">
          Versions
        </p>
        <ul className="flex flex-col gap-0.5 border-l border-border text-sm">
          {versions.map((v) => (
            <li key={v.slug}>
              <a
                href={`#${v.slug}`}
                className="-ml-px flex items-baseline justify-between gap-2 border-l-2 border-transparent py-1.5 pl-3 pr-2 text-muted-foreground transition-colors hover:border-border hover:text-foreground"
              >
                <span className="font-mono">{v.version}</span>
                {v.date && (
                  <span className="font-mono text-xs text-muted-foreground/70">
                    {v.date}
                  </span>
                )}
              </a>
            </li>
          ))}
        </ul>
      </aside>

      <article className="mx-auto min-w-0 max-w-3xl flex-1 py-10">
        <header className="mb-10">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <h1 className="text-3xl font-bold tracking-tight sm:text-4xl">
              Changelog
            </h1>
            <a
              href="/changelog/rss.xml"
              className="inline-flex h-9 items-center gap-2 rounded-md border border-border bg-card px-3 text-sm text-muted-foreground transition-colors hover:border-mauve/40 hover:text-foreground"
            >
              <Rss className="h-4 w-4 text-peach" />
              RSS
            </a>
          </div>
          <p className="mt-3 text-lg leading-relaxed text-muted-foreground">
            {description}
          </p>
          <nav
            aria-label="Versions"
            className="mt-6 flex flex-wrap gap-2 md:hidden"
          >
            {versions.map((v) => (
              <a
                key={v.slug}
                href={`#${v.slug}`}
                className="rounded-full border border-border bg-card px-3 py-1 font-mono text-xs text-muted-foreground transition-colors hover:border-mauve/40 hover:text-foreground"
              >
                {v.version}
              </a>
            ))}
          </nav>
        </header>

        <div className="flex flex-col">
          {versions.map((v, i) => (
            <section
              key={v.slug}
              id={v.slug}
              aria-labelledby={`${v.slug}-title`}
              className="scroll-mt-24 border-t border-border py-10 first:border-t-0 first:pt-0"
            >
              <div className="mb-5 flex flex-wrap items-baseline gap-x-3 gap-y-1">
                <h2
                  id={`${v.slug}-title`}
                  className="font-mono text-2xl font-semibold tracking-tight"
                >
                  <a href={`#${v.slug}`} className="group">
                    {v.version}
                    <span
                      aria-hidden
                      className="ml-2 text-muted-foreground/0 transition-colors group-hover:text-muted-foreground/60"
                    >
                      #
                    </span>
                  </a>
                </h2>
                {v.date && (
                  <time
                    dateTime={v.date}
                    className="text-sm text-muted-foreground"
                  >
                    {formatDate(v.date)}
                  </time>
                )}
                {i === 0 && (
                  <span className="rounded-full bg-green/15 px-2.5 py-1 font-mono text-[11px] font-semibold uppercase tracking-wide text-green">
                    Latest
                  </span>
                )}
              </div>
              <MarkdownBlocks blocks={v.blocks} />
            </section>
          ))}
        </div>
      </article>
    </div>
  );
}
