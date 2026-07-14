import { cn } from "@/lib/utils";

export function Logo({
  className,
  withCursor = true,
}: {
  className?: string;
  withCursor?: boolean;
}) {
  return (
    <span
      className={cn(
        "inline-flex select-none items-baseline font-mono text-[0.95rem] font-semibold tracking-tight",
        className,
      )}
    >
      <span className="text-green" aria-hidden>
        ❯
      </span>
      <span className="ml-1.5">
        <span className="text-foreground">dart</span>
        <span className="text-mauve">_tui</span>
      </span>
      {withCursor && (
        <span className="ml-0.5 inline-block h-[1.05em] w-[0.5em] translate-y-[0.12em] animate-blink bg-mauve" aria-hidden />
      )}
    </span>
  );
}
