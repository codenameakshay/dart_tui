"use client";

import { useState, type ReactNode } from "react";
import { cn } from "@/lib/utils";

export interface PreviewTab {
  id: string;
  label: string;
  content: ReactNode;
}

/**
 * Preview/Code tab switcher. Tab contents are rendered on the server (the GIF
 * frame and shiki-highlighted code) and handed in as ReactNodes; this client
 * shell only toggles which one is visible.
 */
export function PreviewTabs({ tabs }: { tabs: PreviewTab[] }) {
  const [active, setActive] = useState(tabs[0]?.id);

  return (
    <div className="overflow-hidden rounded-xl border border-border bg-card">
      <div className="flex items-center gap-1 border-b border-border bg-muted/40 px-2">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            type="button"
            onClick={() => setActive(tab.id)}
            className={cn(
              "relative px-3 py-2.5 text-sm font-medium transition-colors",
              active === tab.id
                ? "text-foreground"
                : "text-muted-foreground hover:text-foreground",
            )}
          >
            {tab.label}
            {active === tab.id && (
              <span className="absolute inset-x-2 -bottom-px h-0.5 rounded-full bg-mauve" />
            )}
          </button>
        ))}
      </div>
      <div className="p-4 sm:p-5">
        {tabs.map((tab) => (
          <div key={tab.id} className={active === tab.id ? "block" : "hidden"}>
            {tab.content}
          </div>
        ))}
      </div>
    </div>
  );
}
