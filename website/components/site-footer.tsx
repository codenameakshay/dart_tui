import Link from "next/link";
import { Logo } from "@/components/logo";
import {
  componentsList,
  blocksList,
  guidesList,
  examplesList,
} from "@/content";
import { siteConfig } from "@/lib/utils";

const columns = [
  {
    title: "Components",
    links: componentsList.slice(0, 6).map((e) => ({
      label: e.name,
      href: `/components/${e.slug}`,
    })),
  },
  {
    title: "Blocks",
    links: blocksList.slice(0, 6).map((e) => ({
      label: e.name,
      href: `/blocks/${e.slug}`,
    })),
  },
  {
    title: "Examples",
    links: examplesList.slice(0, 6).map((e) => ({
      label: e.name,
      href: `/examples/${e.slug}`,
    })),
  },
  {
    title: "Guides",
    links: guidesList.slice(0, 6).map((e) => ({
      label: e.name,
      href: `/guides/${e.slug}`,
    })),
  },
  {
    title: "Resources",
    links: [
      { label: "GitHub", href: siteConfig.github },
      { label: "pub.dev", href: siteConfig.pub },
      { label: "Bubble Tea", href: "https://github.com/charmbracelet/bubbletea" },
      { label: "Lipgloss", href: "https://github.com/charmbracelet/lipgloss" },
    ],
  },
];

export function SiteFooter() {
  return (
    <footer className="border-t border-border/70">
      <div className="container py-14">
        <div className="grid grid-cols-2 gap-10 md:grid-cols-3 lg:grid-cols-[1.4fr_repeat(5,1fr)]">
          <div className="max-w-xs">
            <Logo />
            <p className="mt-4 text-sm leading-relaxed text-muted-foreground">
              {siteConfig.tagline}. Inspired by Bubble Tea &amp; Lipgloss, built
              in pure Dart.
            </p>
          </div>
          {columns.map((col) => (
            <div key={col.title}>
              <p className="mb-3 font-mono text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                {col.title}
              </p>
              <ul className="flex flex-col gap-2 text-sm">
                {col.links.map((link) => (
                  <li key={link.label}>
                    <Link
                      href={link.href}
                      className="text-muted-foreground transition-colors hover:text-foreground"
                    >
                      {link.label}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>

        <div className="mt-12 flex flex-col items-center justify-between gap-3 border-t border-border/70 pt-6 text-xs text-muted-foreground sm:flex-row">
          <p>
            Released under the MIT License. © {new Date().getFullYear()}{" "}
            dart_tui.
          </p>
          <p className="font-mono">
            v{siteConfig.version} · built with Next.js on Vercel
          </p>
        </div>
      </div>
    </footer>
  );
}
