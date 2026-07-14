"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  componentsList,
  blocksList,
  guidesList,
  examplesList,
} from "@/content";
import type { DocEntry } from "@/content";
import { cn } from "@/lib/utils";

const sections: { title: string; base: string; items: DocEntry[] }[] = [
  { title: "Guides", base: "guides", items: guidesList },
  { title: "Components", base: "components", items: componentsList },
  { title: "Blocks", base: "blocks", items: blocksList },
  { title: "Examples", base: "examples", items: examplesList },
];

export function SidebarNav({ onNavigate }: { onNavigate?: () => void }) {
  const pathname = usePathname();

  return (
    <nav className="flex flex-col gap-7 pb-10 text-sm">
      {sections.map((section) => (
        <div key={section.title}>
          <p className="mb-2 px-2 font-mono text-xs font-semibold uppercase tracking-wider text-muted-foreground">
            {section.title}
          </p>
          <ul className="flex flex-col gap-0.5 border-l border-border">
            {section.items.map((item) => {
              const href = `/${section.base}/${item.slug}`;
              const active = pathname === href;
              return (
                <li key={item.slug}>
                  <Link
                    href={href}
                    onClick={onNavigate}
                    className={cn(
                      "-ml-px flex items-center gap-2 border-l-2 py-1.5 pl-3 pr-2 transition-colors",
                      active
                        ? "border-mauve font-medium text-foreground"
                        : "border-transparent text-muted-foreground hover:border-border hover:text-foreground",
                    )}
                  >
                    <span className="truncate">{item.name}</span>
                    {item.isNew && (
                      <span className="rounded-full bg-green/15 px-1.5 py-0.5 font-mono text-[9px] font-semibold uppercase text-green">
                        new
                      </span>
                    )}
                  </Link>
                </li>
              );
            })}
          </ul>
        </div>
      ))}
    </nav>
  );
}
