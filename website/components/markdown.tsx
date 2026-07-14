import Link from "next/link";
import { Fragment, type ReactNode } from "react";

/**
 * Tiny inline-markdown renderer for the controlled prose we author in the
 * content registry. Supports `code`, **bold**, and [text](href) only — enough
 * for our copy without pulling in a full markdown pipeline.
 */
export function InlineMarkdown({ text }: { text: string }): ReactNode {
  return <>{parseInline(text)}</>;
}

function parseInline(text: string): ReactNode[] {
  const nodes: ReactNode[] = [];
  // Match `code`, **bold**, or [label](href), in order of appearance.
  const pattern = /(`[^`]+`)|(\*\*[^*]+\*\*)|(\[[^\]]+\]\([^)]+\))/g;
  let last = 0;
  let match: RegExpExecArray | null;
  let key = 0;

  while ((match = pattern.exec(text)) !== null) {
    if (match.index > last) {
      nodes.push(
        <Fragment key={key++}>{text.slice(last, match.index)}</Fragment>,
      );
    }
    const token = match[0];
    if (token.startsWith("`")) {
      nodes.push(
        <code
          key={key++}
          className="rounded border border-border bg-muted px-1.5 py-0.5 font-mono text-[0.85em] text-mauve"
        >
          {token.slice(1, -1)}
        </code>,
      );
    } else if (token.startsWith("**")) {
      nodes.push(
        <strong key={key++} className="font-semibold text-foreground">
          {token.slice(2, -2)}
        </strong>,
      );
    } else {
      const label = token.slice(1, token.indexOf("]"));
      const href = token.slice(token.indexOf("(") + 1, -1);
      const external = href.startsWith("http");
      nodes.push(
        <Link
          key={key++}
          href={href}
          {...(external ? { target: "_blank", rel: "noreferrer" } : {})}
          className="font-medium text-mauve underline decoration-mauve/30 underline-offset-2 transition-colors hover:decoration-mauve"
        >
          {label}
        </Link>,
      );
    }
    last = pattern.lastIndex;
  }
  if (last < text.length) {
    nodes.push(<Fragment key={key++}>{text.slice(last)}</Fragment>);
  }
  return nodes;
}
