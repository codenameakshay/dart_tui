import { highlight } from "@/lib/highlight";
import { CopyButton } from "@/components/copy-button";
import { cn } from "@/lib/utils";

const langLabel: Record<string, string> = {
  dart: "dart",
  bash: "bash",
  sh: "bash",
  shell: "bash",
  yaml: "yaml",
  yml: "yaml",
  text: "text",
  ts: "ts",
  typescript: "ts",
};

/**
 * Server component: highlights `code` with shiki (dual Catppuccin themes) and
 * renders it in a framed block with a copy button.
 */
export async function CodeBlock({
  code,
  lang = "dart",
  className,
  showChrome = true,
}: {
  code: string;
  lang?: string;
  className?: string;
  showChrome?: boolean;
}) {
  const html = await highlight(code, lang);

  return (
    <div
      className={cn(
        "group relative overflow-hidden rounded-lg border border-border bg-card",
        className,
      )}
    >
      {showChrome && (
        <div className="flex items-center justify-between border-b border-border/70 bg-muted/40 px-4 py-2">
          <span className="font-mono text-xs text-muted-foreground">
            {langLabel[lang] ?? lang}
          </span>
          <CopyButton value={code} />
        </div>
      )}
      {!showChrome && (
        <CopyButton
          value={code}
          className="absolute right-3 top-3 opacity-0 transition-opacity group-hover:opacity-100"
        />
      )}
      <div
        className="overflow-x-auto p-4 font-mono text-[0.82rem] leading-relaxed [&_pre]:!bg-transparent [&_pre]:!m-0"
        dangerouslySetInnerHTML={{ __html: html }}
      />
    </div>
  );
}
