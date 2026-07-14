import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { CATEGORY_META, getEntries, type Category } from "@/content";
import { ComponentCard } from "@/components/component-card";

export function CategoryIndex({ category }: { category: Category }) {
  const meta = CATEGORY_META[category];
  const entries = getEntries(category);

  return (
    <div>
      <header className="mb-10">
        <p className="font-mono text-xs font-semibold uppercase tracking-wider text-mauve">
          {meta.label}
        </p>
        <h1 className="mt-2 text-3xl font-bold tracking-tight sm:text-4xl">
          {meta.title}
        </h1>
        <p className="mt-3 max-w-2xl text-lg leading-relaxed text-muted-foreground">
          {meta.blurb}
        </p>
        <p className="mt-4 font-mono text-sm text-muted-foreground">
          {entries.length} {entries.length === 1 ? "entry" : "entries"}
        </p>
      </header>

      {category === "guides" ? (
        <ul className="flex flex-col gap-2">
          {entries.map((entry) => (
            <li key={entry.slug}>
              <Link
                href={`/guides/${entry.slug}`}
                className="group flex items-center justify-between gap-4 rounded-lg border border-border bg-card p-4 transition-colors hover:border-mauve/40"
              >
                <div>
                  <h3 className="font-semibold tracking-tight">{entry.name}</h3>
                  <p className="mt-0.5 text-sm text-muted-foreground">
                    {entry.tagline}
                  </p>
                </div>
                <ArrowRight className="h-4 w-4 shrink-0 text-muted-foreground transition-transform group-hover:translate-x-0.5 group-hover:text-foreground" />
              </Link>
            </li>
          ))}
        </ul>
      ) : (
        <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          {entries.map((entry) => (
            <ComponentCard key={entry.slug} entry={entry} />
          ))}
        </div>
      )}
    </div>
  );
}
