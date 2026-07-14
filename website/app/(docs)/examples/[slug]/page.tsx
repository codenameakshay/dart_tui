import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { DocPage } from "@/components/doc-page";
import { getEntries, getEntry, type ContentBlock } from "@/content";
import { readExampleSource } from "@/lib/examples";

export function generateStaticParams() {
  return getEntries("examples").map((e) => ({ slug: e.slug }));
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const entry = getEntry("examples", slug);
  if (!entry) return {};
  return {
    title: entry.name,
    description: entry.tagline,
  };
}

export default async function ExamplePage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const entry = getEntry("examples", slug);
  if (!entry) notFound();

  // Inject the real source (read at build time) as the code tab, and a
  // "Run it" block using the original underscore filename.
  const source = readExampleSource(slug);
  const fileName = `${slug.replace(/-/g, "_")}.dart`;
  const runBlock: ContentBlock[] = [
    { type: "heading", text: "Run it" },
    { type: "code", lang: "bash", code: `dart run example/${fileName}` },
  ];

  const withSource = {
    ...entry,
    snippets: [{ label: "Source", lang: "dart", code: source }],
    blocks: [...runBlock, ...(entry.blocks ?? [])],
  };

  return <DocPage entry={withSource} />;
}
