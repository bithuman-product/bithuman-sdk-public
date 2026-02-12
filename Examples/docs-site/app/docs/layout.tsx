import type { ReactNode } from "react";
import { DocsLayout } from "fumadocs-ui/layouts/docs";
import { source } from "@/lib/source";

export default function Layout({ children }: { children: ReactNode }) {
  return (
    <DocsLayout
      tree={source.pageTree}
      nav={{
        title: (
          <span className="font-semibold tracking-tight">
            <span className="opacity-90">bit</span>
            <span>Human</span>
            <span className="text-fd-muted-foreground ml-1.5 text-sm font-normal">
              Docs
            </span>
          </span>
        ),
        url: "/",
      }}
      sidebar={{ defaultOpenLevel: 0 }}
      links={[
        {
          text: "Console",
          url: "https://imaginex.bithuman.ai",
          external: true,
        },
        {
          text: "GitHub",
          url: "https://github.com/bithuman-product/examples",
          external: true,
        },
        {
          text: "Discord",
          url: "https://discord.gg/ES953n7bPA",
          external: true,
        },
      ]}
    >
      {children}
    </DocsLayout>
  );
}
