import Link from "next/link";

const features = [
  {
    title: "CPU-Only Rendering",
    description:
      "Run entirely on host CPU. No GPU required. Deploy anywhere — from Raspberry Pi to cloud VMs.",
    icon: "M9 3.5a5.5 5.5 0 1 0 0 11 5.5 5.5 0 0 0 0-11ZM2 9a7 7 0 1 1 12.452 4.391l3.328 3.329a.75.75 0 1 1-1.06 1.06l-3.329-3.328A7 7 0 0 1 2 9Z",
  },
  {
    title: "Real-time at 25 FPS",
    description:
      "Smooth, natural-looking animation driven by audio input. Lip sync, expressions, and head movement in real-time.",
    icon: "M2 4.5A2.5 2.5 0 0 1 4.5 2h11A2.5 2.5 0 0 1 18 4.5v11a2.5 2.5 0 0 1-2.5 2.5h-11A2.5 2.5 0 0 1 2 15.5v-11ZM4.5 3.5a1 1 0 0 0-1 1v11a1 1 0 0 0 1 1h11a1 1 0 0 0 1-1v-11a1 1 0 0 0-1-1h-11Zm3 5a.75.75 0 0 1 .75.75v3.5a.75.75 0 0 1-1.5 0v-3.5a.75.75 0 0 1 .75-.75Zm2.25-1a.75.75 0 0 0-1.5 0v5.5a.75.75 0 0 0 1.5 0v-5.5Zm1.5 2.25a.75.75 0 0 1 .75.75v2.25a.75.75 0 0 1-1.5 0V10.5a.75.75 0 0 1 .75-.75Zm3-1.5a.75.75 0 0 0-1.5 0v4.5a.75.75 0 0 0 1.5 0v-4.5Z",
  },
  {
    title: "3 Lines of Code",
    description:
      "Initialize, run, display. The SDK handles model loading, audio processing, and frame generation.",
    icon: "M3.75 2A1.75 1.75 0 0 0 2 3.75v12.5c0 .966.784 1.75 1.75 1.75h12.5A1.75 1.75 0 0 0 18 16.25V3.75A1.75 1.75 0 0 0 16.25 2H3.75ZM3.5 3.75a.25.25 0 0 1 .25-.25h12.5a.25.25 0 0 1 .25.25v12.5a.25.25 0 0 1-.25.25H3.75a.25.25 0 0 1-.25-.25V3.75ZM13 12a.75.75 0 0 1 0 1.5H7A.75.75 0 0 1 7 12h6Zm-3-3.5a.75.75 0 0 1 0 1.5H7a.75.75 0 0 1 0-1.5h3Zm4.75-3a.75.75 0 0 1 0 1.5H5.25a.75.75 0 0 1 0-1.5h9.5Z",
  },
  {
    title: "10x Lower Cost",
    description:
      "Choose host device or CPU cloud. No expensive GPU instances required for inference.",
    icon: "M10 1a1 1 0 0 1 1 1v6.756l3.22-3.22a1 1 0 0 1 1.414 1.415l-4.927 4.927a1 1 0 0 1-1.414 0L4.366 5.95a1 1 0 0 1 1.414-1.414L9 7.756V2a1 1 0 0 1 1-1ZM2 12a1 1 0 0 1 1 1v3a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-3a1 1 0 1 1 2 0v3a3 3 0 0 1-3 3H4a3 3 0 0 1-3-3v-3a1 1 0 0 1 1-1Z",
  },
  {
    title: "Web-Ready with LiveKit",
    description:
      "Stream avatars to any browser. Cloud and self-hosted deployment options with LiveKit integration.",
    icon: "M10 1a9 9 0 1 0 0 18 9 9 0 0 0 0-18ZM6.613 3.5A7.5 7.5 0 0 0 2.528 9H5.09c.103-2.16.593-4.07 1.523-5.5Zm6.774 0c.93 1.43 1.42 3.34 1.522 5.5h2.563A7.5 7.5 0 0 0 13.387 3.5ZM6.596 9c.109-2.006.573-3.737 1.364-5.001C8.75 2.736 9.38 2.5 10 2.5c.62 0 1.25.236 2.04 1.499.79 1.264 1.255 2.995 1.364 5.001H6.596Zm0 2c.109 2.006.573 3.737 1.364 5.001.79 1.263 1.42 1.499 2.04 1.499.62 0 1.25-.236 2.04-1.499.79-1.264 1.255-2.995 1.364-5.001H6.596ZM5.09 11H2.528a7.5 7.5 0 0 0 4.085 5.5c-.93-1.43-1.42-3.34-1.522-5.5Zm8.296 5.5A7.5 7.5 0 0 0 17.472 11h-2.563c-.103 2.16-.593 4.07-1.523 5.5Z",
  },
  {
    title: "Cross-Platform",
    description:
      "macOS, Linux, Windows (WSL), Raspberry Pi, Flutter mobile. Deploy avatars everywhere.",
    icon: "M3 2.75C3 1.784 3.784 1 4.75 1h10.5c.966 0 1.75.784 1.75 1.75v14.5A1.75 1.75 0 0 1 15.25 19H4.75A1.75 1.75 0 0 1 3 17.25V2.75Zm1.75-.25a.25.25 0 0 0-.25.25v14.5c0 .138.112.25.25.25h10.5a.25.25 0 0 0 .25-.25V2.75a.25.25 0 0 0-.25-.25H4.75ZM10 15.5a1 1 0 1 0 0-2 1 1 0 0 0 0 2Z",
  },
];

const platforms = [
  { name: "macOS", detail: "M1+ (M4 ideal)" },
  { name: "Linux", detail: "x64 / ARM64" },
  { name: "Windows", detail: "via WSL2" },
  { name: "Raspberry Pi", detail: "4B, 8GB" },
  { name: "Flutter", detail: "iOS / Android / Web" },
  { name: "Docker", detail: "Cloud / Self-hosted" },
];

export default function HomePage() {
  return (
    <main>
      {/* Hero */}
      <section className="relative overflow-hidden px-6 pb-20 pt-24 md:pb-32 md:pt-36">
        <div className="bg-fd-primary/5 pointer-events-none absolute inset-0 -z-10" />
        <div className="mx-auto max-w-4xl text-center">
          <p className="text-fd-primary mb-4 text-sm font-medium uppercase tracking-widest">
            Developer Documentation
          </p>
          <h1 className="text-fd-foreground mb-6 text-5xl font-bold leading-tight tracking-tight md:text-7xl">
            Build lifelike
            <br />
            <span className="bg-gradient-to-r from-blue-600 to-violet-600 bg-clip-text text-transparent dark:from-blue-400 dark:to-violet-400">
              digital avatars
            </span>
          </h1>
          <p className="text-fd-muted-foreground mx-auto mb-10 max-w-2xl text-lg leading-relaxed md:text-xl">
            Real-time, audio-driven avatar animation. CPU-only operation,
            25&nbsp;FPS, 3&nbsp;lines of code. From prototype to production.
          </p>
          <div className="flex flex-wrap items-center justify-center gap-4">
            <Link
              href="/docs/getting-started"
              className="bg-fd-primary text-fd-primary-foreground inline-flex items-center rounded-full px-8 py-3.5 text-sm font-semibold shadow-lg transition-all hover:opacity-90 hover:shadow-xl"
            >
              Get Started
              <svg
                className="ml-2 h-4 w-4"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                strokeWidth={2}
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  d="M13 7l5 5m0 0l-5 5m5-5H6"
                />
              </svg>
            </Link>
            <Link
              href="/docs/api-reference"
              className="border-fd-border text-fd-foreground inline-flex items-center rounded-full border px-8 py-3.5 text-sm font-semibold transition-all hover:bg-fd-accent"
            >
              API Reference
            </Link>
          </div>
        </div>
      </section>

      {/* Code Preview */}
      <section className="border-fd-border border-y px-6 py-16 md:py-24">
        <div className="mx-auto max-w-3xl">
          <p className="text-fd-muted-foreground mb-6 text-center text-sm font-medium uppercase tracking-widest">
            Quick Start
          </p>
          <div className="bg-fd-card border-fd-border overflow-hidden rounded-2xl border shadow-sm">
            <div className="border-fd-border flex items-center gap-2 border-b px-4 py-3">
              <span className="h-3 w-3 rounded-full bg-red-400/80" />
              <span className="h-3 w-3 rounded-full bg-yellow-400/80" />
              <span className="h-3 w-3 rounded-full bg-green-400/80" />
              <span className="text-fd-muted-foreground ml-2 text-xs">
                main.py
              </span>
            </div>
            <pre className="overflow-x-auto !rounded-none !border-0 p-6 text-sm leading-relaxed">
              <code>
                <span className="text-purple-600 dark:text-purple-400">
                  from
                </span>
                {" bithuman "}
                <span className="text-purple-600 dark:text-purple-400">
                  import
                </span>
                {" AsyncBithuman\n\n"}
                <span className="text-fd-muted-foreground"># Initialize</span>
                {"\nruntime = "}
                <span className="text-purple-600 dark:text-purple-400">
                  await
                </span>
                {" AsyncBithuman.create(\n    model_path="}
                <span className="text-green-600 dark:text-green-400">
                  {'"model.imx"'}
                </span>
                {",\n    api_secret="}
                <span className="text-green-600 dark:text-green-400">
                  {'"your_secret"'}
                </span>
                {"\n)\n\n"}
                <span className="text-fd-muted-foreground">
                  # Stream frames at 25 FPS
                </span>
                {"\n"}
                <span className="text-purple-600 dark:text-purple-400">
                  async for
                </span>
                {" frame "}
                <span className="text-purple-600 dark:text-purple-400">in</span>
                {" runtime.run():\n    display(frame)"}
              </code>
            </pre>
          </div>
        </div>
      </section>

      {/* Features */}
      <section className="px-6 py-20 md:py-28">
        <div className="mx-auto max-w-6xl">
          <div className="mb-16 text-center">
            <h2 className="text-fd-foreground mb-4 text-3xl font-bold tracking-tight md:text-4xl">
              Built for developers
            </h2>
            <p className="text-fd-muted-foreground mx-auto max-w-xl text-lg">
              Everything you need to integrate lifelike avatars into your
              application.
            </p>
          </div>
          <div className="grid gap-8 md:grid-cols-2 lg:grid-cols-3">
            {features.map((feature) => (
              <div
                key={feature.title}
                className="bg-fd-card border-fd-border group rounded-2xl border p-8 transition-all hover:shadow-md"
              >
                <div className="bg-fd-primary/10 mb-5 inline-flex rounded-xl p-3">
                  <svg
                    className="text-fd-primary h-6 w-6"
                    viewBox="0 0 20 20"
                    fill="currentColor"
                  >
                    <path fillRule="evenodd" d={feature.icon} clipRule="evenodd" />
                  </svg>
                </div>
                <h3 className="text-fd-foreground mb-2 text-lg font-semibold">
                  {feature.title}
                </h3>
                <p className="text-fd-muted-foreground text-sm leading-relaxed">
                  {feature.description}
                </p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Platforms */}
      <section className="border-fd-border border-t px-6 py-20 md:py-28">
        <div className="mx-auto max-w-4xl">
          <div className="mb-12 text-center">
            <h2 className="text-fd-foreground mb-4 text-3xl font-bold tracking-tight md:text-4xl">
              Deploy everywhere
            </h2>
            <p className="text-fd-muted-foreground text-lg">
              One SDK, every platform.
            </p>
          </div>
          <div className="grid grid-cols-2 gap-4 md:grid-cols-3 lg:grid-cols-6">
            {platforms.map((platform) => (
              <div
                key={platform.name}
                className="bg-fd-card border-fd-border rounded-xl border p-4 text-center"
              >
                <p className="text-fd-foreground text-sm font-semibold">
                  {platform.name}
                </p>
                <p className="text-fd-muted-foreground mt-1 text-xs">
                  {platform.detail}
                </p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="px-6 py-20 md:py-28">
        <div className="bg-fd-primary/5 border-fd-border mx-auto max-w-4xl rounded-3xl border px-8 py-16 text-center md:px-16">
          <h2 className="text-fd-foreground mb-4 text-3xl font-bold tracking-tight md:text-4xl">
            Start building today
          </h2>
          <p className="text-fd-muted-foreground mb-8 text-lg">
            Get your first avatar running in under 5 minutes.
          </p>
          <div className="flex flex-wrap items-center justify-center gap-4">
            <Link
              href="/docs/getting-started"
              className="bg-fd-primary text-fd-primary-foreground rounded-full px-8 py-3.5 text-sm font-semibold shadow-lg transition-all hover:opacity-90"
            >
              Quick Start Guide
            </Link>
            <Link
              href="/docs/examples"
              className="border-fd-border text-fd-foreground rounded-full border px-8 py-3.5 text-sm font-semibold transition-all hover:bg-fd-accent"
            >
              View Examples
            </Link>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-fd-border border-t px-6 py-8">
        <div className="mx-auto flex max-w-6xl flex-col items-center justify-between gap-4 md:flex-row">
          <p className="text-fd-muted-foreground text-sm">
            BitHuman — Real-time AI avatars
          </p>
          <div className="text-fd-muted-foreground flex gap-6 text-sm">
            <a
              href="https://imaginex.bithuman.ai"
              className="hover:text-fd-foreground transition-colors"
            >
              Console
            </a>
            <a
              href="https://github.com/bithuman-product/examples"
              className="hover:text-fd-foreground transition-colors"
            >
              GitHub
            </a>
            <a
              href="https://discord.gg/ES953n7bPA"
              className="hover:text-fd-foreground transition-colors"
            >
              Discord
            </a>
          </div>
        </div>
      </footer>
    </main>
  );
}
