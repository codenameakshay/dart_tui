import type { Metadata } from "next";
import { CategoryIndex } from "@/components/category-index";
import { CATEGORY_META } from "@/content";

export const metadata: Metadata = {
  title: CATEGORY_META.guides.title,
  description: CATEGORY_META.guides.blurb,
};

export default function GuidesPage() {
  return <CategoryIndex category="guides" />;
}
