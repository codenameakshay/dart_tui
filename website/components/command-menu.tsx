"use client";

import { Command } from "cmdk";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useState } from "react";
import { Box, BookOpen, Blocks, Search, Github } from "lucide-react";
import { allEntries, CATEGORY_META, type Category } from "@/content";
import { siteConfig } from "@/lib/utils";

const OPEN_EVENT = "open-command-menu";

export function openCommandMenu() {
  window.dispatchEvent(new Event(OPEN_EVENT));
}

const categoryIcon: Record<Category, React.ReactNode> = {
  components: <Box className="h-4 w-4 text-mauve" />,
  blocks: <Blocks className="h-4 w-4 text-sky" />,
  guides: <BookOpen className="h-4 w-4 text-green" />,
};

export function CommandMenu() {
  const [open, setOpen] = useState(false);
  const router = useRouter();

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "k" && (e.metaKey || e.ctrlKey)) {
        e.preventDefault();
        setOpen((o) => !o);
      }
    };
    const onOpen = () => setOpen(true);
    document.addEventListener("keydown", onKey);
    window.addEventListener(OPEN_EVENT, onOpen);
    return () => {
      document.removeEventListener("keydown", onKey);
      window.removeEventListener(OPEN_EVENT, onOpen);
    };
  }, []);

  const go = useCallback(
    (href: string) => {
      setOpen(false);
      router.push(href);
    },
    [router],
  );

  const groups: Category[] = ["components", "blocks", "guides"];

  return (
    <Command.Dialog
      open={open}
      onOpenChange={setOpen}
      label="Search documentation"
      className="fixed inset-0 z-[100]"
    >
      <div
        className="absolute inset-0 bg-background/70 backdrop-blur-sm"
        onClick={() => setOpen(false)}
      />
      <div className="absolute left-1/2 top-[18%] w-[92vw] max-w-xl -translate-x-1/2 overflow-hidden rounded-xl border border-border bg-popover shadow-2xl shadow-black/40">
        <div className="flex items-center gap-2 border-b border-border px-4">
          <Search className="h-4 w-4 shrink-0 text-muted-foreground" />
          <Command.Input
            autoFocus
            placeholder="Search components, blocks and guides…"
            className="h-12 w-full bg-transparent text-sm outline-none placeholder:text-muted-foreground"
          />
          <kbd className="hidden rounded border border-border bg-muted px-1.5 py-0.5 font-mono text-[10px] text-muted-foreground sm:inline">
            ESC
          </kbd>
        </div>
        <Command.List className="max-h-[60vh] overflow-y-auto p-2">
          <Command.Empty className="px-3 py-8 text-center text-sm text-muted-foreground">
            No results found.
          </Command.Empty>

          {groups.map((cat) => (
            <Command.Group
              key={cat}
              heading={CATEGORY_META[cat].label}
              className="[&_[cmdk-group-heading]]:px-2 [&_[cmdk-group-heading]]:py-1.5 [&_[cmdk-group-heading]]:text-xs [&_[cmdk-group-heading]]:font-medium [&_[cmdk-group-heading]]:text-muted-foreground"
            >
              {allEntries
                .filter((e) => e.category === cat)
                .map((e) => (
                  <Command.Item
                    key={`${cat}-${e.slug}`}
                    value={`${e.name} ${e.tagline} ${cat}`}
                    onSelect={() => go(`/${cat}/${e.slug}`)}
                    className="flex cursor-pointer items-center gap-3 rounded-md px-2 py-2 text-sm aria-selected:bg-muted"
                  >
                    {categoryIcon[cat]}
                    <span className="flex-1">
                      <span className="font-medium">{e.name}</span>
                      <span className="ml-2 text-xs text-muted-foreground">
                        {e.tagline}
                      </span>
                    </span>
                  </Command.Item>
                ))}
            </Command.Group>
          ))}

          <Command.Group
            heading="Links"
            className="[&_[cmdk-group-heading]]:px-2 [&_[cmdk-group-heading]]:py-1.5 [&_[cmdk-group-heading]]:text-xs [&_[cmdk-group-heading]]:font-medium [&_[cmdk-group-heading]]:text-muted-foreground"
          >
            <Command.Item
              value="github repository source"
              onSelect={() => {
                setOpen(false);
                window.open(siteConfig.github, "_blank");
              }}
              className="flex cursor-pointer items-center gap-3 rounded-md px-2 py-2 text-sm aria-selected:bg-muted"
            >
              <Github className="h-4 w-4 text-muted-foreground" />
              <span className="font-medium">GitHub repository</span>
            </Command.Item>
          </Command.Group>
        </Command.List>
      </div>
    </Command.Dialog>
  );
}
