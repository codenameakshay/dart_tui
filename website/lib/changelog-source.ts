import { readFileSync } from "node:fs";
import { join } from "node:path";
import { parseChangelog, type ChangelogVersion } from "@/lib/changelog.ts";
import { siteConfig } from "@/lib/utils";

/**
 * Reads the package's CHANGELOG.md from the repo root at build time. The
 * Vercel project's root directory is `website/`, and Vercel checks out the
 * whole repo, so the file sits one level up during `next build`.
 */
export function getChangelog(): ChangelogVersion[] {
  const path = join(process.cwd(), "..", "CHANGELOG.md");
  let source: string;
  try {
    source = readFileSync(path, "utf8");
  } catch (error) {
    throw new Error(
      `Cannot read ${path}. The changelog page needs the full repo checkout ` +
        `(on Vercel, keep "Include files outside the root directory" on).`,
      { cause: error },
    );
  }
  return parseChangelog(source, { repoUrl: siteConfig.github });
}
