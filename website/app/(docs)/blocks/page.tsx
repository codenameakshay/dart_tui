import type { Metadata } from "next";
import { CategoryIndex } from "@/components/category-index";
import { CATEGORY_META } from "@/content";

export const metadata: Metadata = {
  title: CATEGORY_META.blocks.title,
  description: CATEGORY_META.blocks.blurb,
};

export default function BlocksPage() {
  return <CategoryIndex category="blocks" />;
}
