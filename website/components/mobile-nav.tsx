"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { SidebarNav } from "@/components/sidebar";
import { cn } from "@/lib/utils";

export function MobileNav({ onNavigate }: { onNavigate?: () => void }) {
  const pathname = usePathname();
  const active = pathname.startsWith("/changelog");

  return (
    <div className="border-t border-border bg-background md:hidden">
      <div className="container max-h-[70vh] overflow-y-auto py-6">
        <Link
          href="/changelog"
          onClick={onNavigate}
          className={cn(
            "mb-6 flex items-center px-2 text-sm font-medium transition-colors",
            active
              ? "text-foreground"
              : "text-muted-foreground hover:text-foreground",
          )}
        >
          Changelog
        </Link>
        <SidebarNav onNavigate={onNavigate} />
      </div>
    </div>
  );
}
