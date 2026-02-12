import type { ReactNode } from "react";
import { HomeLayout } from "fumadocs-ui/layouts/home";

export default function Layout({ children }: { children: ReactNode }) {
  return (
    <HomeLayout
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
      links={[
        { text: "Documentation", url: "/docs" },
        { text: "API Reference", url: "/docs/api-reference" },
        { text: "Examples", url: "/docs/examples" },
        {
          text: "GitHub",
          url: "https://github.com/bithuman-product/examples",
          external: true,
        },
      ]}
    >
      {children}
    </HomeLayout>
  );
}
