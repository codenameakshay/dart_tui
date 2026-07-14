import { readFileSync } from "node:fs";
import { join } from "node:path";

/**
 * Reads the real Dart source for an example at build time. Files live in
 * content/examples-src/<slug>.dart (copied verbatim from the package's
 * example/ directory), so the docs always show runnable, accurate code
 * without hand-escaping Dart's `$` interpolation into TS template strings.
 */
export function readExampleSource(slug: string): string {
  const path = join(process.cwd(), "content", "examples-src", `${slug}.dart`);
  return readFileSync(path, "utf8").trimEnd();
}
