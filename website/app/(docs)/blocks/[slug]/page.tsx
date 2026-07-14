import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { DocPage } from "@/components/doc-page";
import { getEntries, getEntry } from "@/content";

export function generateStaticParams() {
  return getEntries("blocks").map((e) => ({ slug: e.slug }));
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const entry = getEntry("blocks", slug);
  if (!entry) return {};
  return {
    title: entry.name,
    description: entry.tagline,
  };
}

export default async function BlockPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const entry = getEntry("blocks", slug);
  if (!entry) notFound();
  return <DocPage entry={entry} />;
}
