import type { Metadata } from "next";
import { CategoryIndex } from "@/components/category-index";
import { CATEGORY_META } from "@/content";

export const metadata: Metadata = {
  title: CATEGORY_META.examples.title,
  description: CATEGORY_META.examples.blurb,
};

export default function ExamplesPage() {
  return <CategoryIndex category="examples" />;
}
