import Link from "next/link";
import type { ReactNode } from "react";
import { tokenizeInline, type InlineToken } from "@/lib/markdown.ts";

/**
 * Tiny inline-markdown renderer for the controlled prose we author in the
 * content registry and CHANGELOG.md. Supports `code`, **bold**, and
 * [text](href) only — enough for our copy without a full markdown pipeline.
 */
export function InlineMarkdown({ text }: { text: string }): ReactNode {
  return <>{renderTokens(tokenizeInline(text))}</>;
}

function renderTokens(tokens: InlineToken[]): ReactNode[] {
  return tokens.map((token, key) => {
    switch (token.type) {
      case "text":
        return token.text;
      case "code":
        return (
          <code
            key={key}
            className="rounded border border-border bg-muted px-1.5 py-0.5 font-mono text-[0.85em] text-mauve"
          >
            {token.text}
          </code>
        );
      case "strong":
        return (
          <strong key={key} className="font-semibold text-foreground">
            {renderTokens(token.children)}
          </strong>
        );
      case "link": {
        const external = token.href.startsWith("http");
        return (
          <Link
            key={key}
            href={token.href}
            {...(external ? { target: "_blank", rel: "noreferrer" } : {})}
            className="font-medium text-mauve underline decoration-mauve/30 underline-offset-2 transition-colors hover:decoration-mauve"
          >
            {renderTokens(token.children)}
          </Link>
        );
      }
    }
  });
}
