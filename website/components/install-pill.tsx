import { CopyButton } from "@/components/copy-button";
import { cn } from "@/lib/utils";

export function InstallPill({
  command = "dart pub add dart_tui",
  className,
}: {
  command?: string;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "inline-flex items-center gap-3 rounded-lg border border-border bg-card px-4 py-2.5 font-mono text-sm shadow-sm",
        className,
      )}
    >
      <span className="text-green">❯</span>
      <span className="text-foreground">{command}</span>
      <CopyButton value={command} className="ml-1" />
    </div>
  );
}
