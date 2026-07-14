"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
import { Github, Search, Menu, X } from "lucide-react";
import { Logo } from "@/components/logo";
import { ThemeToggle } from "@/components/theme-toggle";
import { openCommandMenu } from "@/components/command-menu";
import { MobileNav } from "@/components/mobile-nav";
import { siteConfig, cn } from "@/lib/utils";

const nav = [
  { href: "/components", label: "Components" },
  { href: "/blocks", label: "Blocks" },
  { href: "/examples", label: "Examples" },
  { href: "/guides/installation", label: "Guides", match: "/guides" },
];

export function SiteHeader() {
  const pathname = usePathname();
  const [mobileOpen, setMobileOpen] = useState(false);

  return (
    <header className="sticky top-0 z-50 w-full border-b border-border/70 glass">
      <div className="container flex h-16 items-center gap-4">
        <Link href="/" className="flex items-center" aria-label="dart_tui home">
          <Logo />
        </Link>

        <nav className="ml-4 hidden items-center gap-1 md:flex">
          {nav.map((item) => {
            const active = pathname.startsWith(item.match ?? item.href);
            return (
              <Link
                key={item.label}
                href={item.href}
                className={cn(
                  "rounded-md px-3 py-1.5 text-sm font-medium transition-colors",
                  active
                    ? "text-foreground"
                    : "text-muted-foreground hover:text-foreground",
                )}
              >
                {item.label}
              </Link>
            );
          })}
        </nav>

        <div className="ml-auto flex items-center gap-2">
          <button
            type="button"
            onClick={openCommandMenu}
            className="group hidden h-9 items-center gap-2 rounded-md border border-border bg-card px-3 text-sm text-muted-foreground transition-colors hover:border-mauve/40 sm:flex"
          >
            <Search className="h-4 w-4" />
            <span className="hidden lg:inline">Search…</span>
            <kbd className="ml-2 hidden rounded border border-border bg-muted px-1.5 py-0.5 font-mono text-[10px] lg:inline">
              ⌘K
            </kbd>
          </button>

          <button
            type="button"
            onClick={openCommandMenu}
            aria-label="Search"
            className="inline-flex h-9 w-9 items-center justify-center rounded-md border border-border bg-card text-muted-foreground transition-colors hover:text-foreground sm:hidden"
          >
            <Search className="h-[1.05rem] w-[1.05rem]" />
          </button>

          <a
            href={siteConfig.github}
            target="_blank"
            rel="noreferrer"
            aria-label="GitHub"
            className="inline-flex h-9 w-9 items-center justify-center rounded-md border border-border bg-card text-muted-foreground transition-colors hover:text-foreground"
          >
            <Github className="h-[1.05rem] w-[1.05rem]" />
          </a>

          <ThemeToggle />

          <button
            type="button"
            aria-label="Menu"
            onClick={() => setMobileOpen((o) => !o)}
            className="inline-flex h-9 w-9 items-center justify-center rounded-md border border-border bg-card text-muted-foreground transition-colors hover:text-foreground md:hidden"
          >
            {mobileOpen ? (
              <X className="h-[1.05rem] w-[1.05rem]" />
            ) : (
              <Menu className="h-[1.05rem] w-[1.05rem]" />
            )}
          </button>
        </div>
      </div>

      {mobileOpen && <MobileNav onNavigate={() => setMobileOpen(false)} />}
    </header>
  );
}
