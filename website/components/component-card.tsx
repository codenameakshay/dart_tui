import Image from "next/image";
import Link from "next/link";
import type { DocEntry } from "@/content";

export function ComponentCard({ entry }: { entry: DocEntry }) {
  return (
    <Link
      href={`/${entry.category}/${entry.slug}`}
      className="group flex flex-col overflow-hidden rounded-xl border border-border bg-card transition-all hover:border-mauve/40 hover:shadow-lg hover:shadow-black/10"
    >
      <div className="relative aspect-[16/10] overflow-hidden border-b border-border bg-term-bg">
        {entry.gif ? (
          <Image
            src={`/gifs/${entry.gif}`}
            alt={`${entry.name} preview`}
            fill
            unoptimized
            sizes="(max-width: 768px) 100vw, 33vw"
            className="object-cover object-top transition-transform duration-500 group-hover:scale-[1.03]"
          />
        ) : (
          <div className="flex h-full items-center justify-center font-mono text-sm text-term-fg/40">
            ❯ {entry.slug}
          </div>
        )}
        {entry.isNew && (
          <span className="absolute right-3 top-3 rounded-full bg-green/90 px-2 py-0.5 font-mono text-[10px] font-semibold uppercase text-[#11111b]">
            new
          </span>
        )}
      </div>
      <div className="flex flex-1 flex-col p-4">
        <h3 className="font-semibold tracking-tight text-foreground">
          {entry.name}
        </h3>
        <p className="mt-1 text-sm leading-relaxed text-muted-foreground">
          {entry.tagline}
        </p>
      </div>
    </Link>
  );
}
