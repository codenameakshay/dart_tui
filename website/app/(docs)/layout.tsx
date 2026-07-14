import { SidebarNav } from "@/components/sidebar";

export default function DocsLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="container flex gap-10">
      <aside className="sticky top-16 hidden h-[calc(100vh-4rem)] w-60 shrink-0 overflow-y-auto py-10 md:block">
        <SidebarNav />
      </aside>
      <div className="min-w-0 flex-1 py-10">{children}</div>
    </div>
  );
}
