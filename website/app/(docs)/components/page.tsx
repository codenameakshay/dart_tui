import type { Metadata } from "next";
import { CategoryIndex } from "@/components/category-index";
import { CATEGORY_META } from "@/content";

export const metadata: Metadata = {
  title: CATEGORY_META.components.title,
  description: CATEGORY_META.components.blurb,
};

export default function ComponentsPage() {
  return <CategoryIndex category="components" />;
}
