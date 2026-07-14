"use client";

import { Moon, Sun } from "lucide-react";
import { useTheme } from "next-themes";
import { useEffect, useState } from "react";

export function ThemeToggle() {
  const { resolvedTheme, setTheme } = useTheme();
  const [mounted, setMounted] = useState(false);

  useEffect(() => setMounted(true), []);

  const isDark = resolvedTheme === "dark";

  return (
    <button
      type="button"
      aria-label="Toggle theme"
      onClick={() => setTheme(isDark ? "light" : "dark")}
      className="inline-flex h-9 w-9 items-center justify-center rounded-md border border-border bg-card text-muted-foreground transition-colors hover:text-foreground hover:border-mauve/40"
    >
      {mounted ? (
        isDark ? (
          <Moon className="h-[1.05rem] w-[1.05rem]" />
        ) : (
          <Sun className="h-[1.05rem] w-[1.05rem]" />
        )
      ) : (
        <span className="h-[1.05rem] w-[1.05rem]" />
      )}
    </button>
  );
}
