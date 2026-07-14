"use client";

import { SidebarNav } from "@/components/sidebar";

export function MobileNav({ onNavigate }: { onNavigate?: () => void }) {
  return (
    <div className="border-t border-border bg-background md:hidden">
      <div className="container max-h-[70vh] overflow-y-auto py-6">
        <SidebarNav onNavigate={onNavigate} />
      </div>
    </div>
  );
}
