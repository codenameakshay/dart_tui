import { components } from "./components";
import { blocks } from "./blocks";
import { guides } from "./guides";
import type { Category, DocEntry } from "./registry";

export * from "./registry";

export const allEntries: DocEntry[] = [...components, ...blocks, ...guides];

const byCategory: Record<Category, DocEntry[]> = {
  components: sortEntries(components),
  blocks: sortEntries(blocks),
  guides: sortEntries(guides),
};

function sortEntries(entries: DocEntry[]): DocEntry[] {
  return [...entries].sort(
    (a, b) => (a.order ?? 999) - (b.order ?? 999) || a.name.localeCompare(b.name),
  );
}

export function getEntries(category: Category): DocEntry[] {
  return byCategory[category];
}

export function getEntry(
  category: Category,
  slug: string,
): DocEntry | undefined {
  return byCategory[category].find((e) => e.slug === slug);
}

export function getEntryBySlug(slug: string): DocEntry | undefined {
  return allEntries.find((e) => e.slug === slug);
}

export function getFeatured(): DocEntry[] {
  return allEntries.filter((e) => e.featured);
}

/** Prev/next within a category for footer navigation. */
export function getSiblings(category: Category, slug: string) {
  const list = byCategory[category];
  const idx = list.findIndex((e) => e.slug === slug);
  return {
    prev: idx > 0 ? list[idx - 1] : undefined,
    next: idx >= 0 && idx < list.length - 1 ? list[idx + 1] : undefined,
  };
}

export const componentsList = byCategory.components;
export const blocksList = byCategory.blocks;
export const guidesList = byCategory.guides;
