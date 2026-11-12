import { buildRss } from "@/lib/changelog.ts";
import { getChangelog } from "@/lib/changelog-source";
import { siteConfig } from "@/lib/utils";

export const dynamic = "force-static";

export function GET() {
  const xml = buildRss(getChangelog(), {
    siteUrl: siteConfig.url,
    title: `${siteConfig.name} releases`,
    description: `Release notes for ${siteConfig.name}, newest first.`,
  });
  return new Response(xml, {
    headers: { "Content-Type": "application/rss+xml; charset=utf-8" },
  });
}
