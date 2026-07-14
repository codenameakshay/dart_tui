import { cn } from "@/lib/utils";

/**
 * A macOS-ish terminal window used to frame recorded GIFs so a running TUI
 * feels like a real program rather than a floating image.
 */
export function TerminalFrame({
  title = "dart_tui",
  children,
  className,
  glow = false,
}: {
  title?: string;
  children: React.ReactNode;
  className?: string;
  glow?: boolean;
}) {
  return (
    <div
      className={cn(
        "overflow-hidden rounded-xl border border-border bg-term-bg shadow-xl shadow-black/20",
        glow &&
          "shadow-2xl shadow-mauve/10 ring-1 ring-inset ring-white/[0.04]",
        className,
      )}
    >
      <div className="flex items-center gap-2 border-b border-white/[0.06] bg-term-bar/60 px-4 py-2.5">
        <span className="flex gap-1.5">
          <span className="h-3 w-3 rounded-full bg-[#ff5f56]" />
          <span className="h-3 w-3 rounded-full bg-[#ffbd2e]" />
          <span className="h-3 w-3 rounded-full bg-[#27c93f]" />
        </span>
        <span className="ml-2 truncate font-mono text-xs text-term-fg/60">
          {title}
        </span>
      </div>
      <div className="bg-term-bg p-1 sm:p-2">{children}</div>
    </div>
  );
}
