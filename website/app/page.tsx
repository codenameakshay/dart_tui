import Image from "next/image";
import Link from "next/link";
import {
  ArrowRight,
  Boxes,
  Github,
  Gauge,
  Layers,
  Palette,
  Sparkles,
  SquareTerminal,
  Waypoints,
  Wind,
  Zap,
} from "lucide-react";
import { TerminalFrame } from "@/components/terminal-frame";
import { InstallPill } from "@/components/install-pill";
import { ComponentCard } from "@/components/component-card";
import { CodeBlock } from "@/components/code-block";
import { getEntries, componentsList } from "@/content";
import { siteConfig } from "@/lib/utils";

const features = [
  {
    icon: Waypoints,
    title: "Model–Update–View",
    desc: "The same pure, testable architecture as Elm and Bubble Tea — state in, view out.",
  },
  {
    icon: Boxes,
    title: "27+ components",
    desc: "Spinners, tables, trees, lists, inputs, forms and more — batteries included.",
  },
  {
    icon: Palette,
    title: "Lipgloss styling",
    desc: "True-color RGB, borders with titles, padding, gradients and SGR attributes.",
  },
  {
    icon: Wind,
    title: "Spring animation",
    desc: "Harmonica-style damped-spring easing for smooth progress, scroll and motion.",
  },
  {
    icon: Zap,
    title: "Async commands",
    desc: "Cmd handles timers, HTTP, subprocesses and any async work, delivered as messages.",
  },
  {
    icon: Layers,
    title: "Canvas compositing",
    desc: "Paint styled blocks at any (x, y) with z-index layering for dashboards and HUDs.",
  },
  {
    icon: Gauge,
    title: "Zero-flicker renderer",
    desc: "Cell-level diffing writes only changed cells, with synchronized-update support.",
  },
  {
    icon: SquareTerminal,
    title: "One-shot helpers",
    desc: "promptSelect, promptConfirm, promptInput plus gum-style filter, spin and pager.",
  },
  {
    icon: Sparkles,
    title: "Fast startup",
    desc: "Kernel snapshots cut warm-JIT to ~500 ms; AOT compiles to a native binary.",
  },
];

const quickStart = `import 'package:dart_tui/dart_tui.dart';

void main() async {
  await Program(
    options: const ProgramOptions(altScreen: true),
  ).run(CounterModel());
}

final class CounterModel extends TeaModel {
  CounterModel({this.count = 0});
  final int count;

  @override
  (Model, Cmd?) update(Msg msg) {
    if (msg is KeyMsg && msg.key == 'up') {
      return (CounterModel(count: count + 1), null);
    }
    if (msg is KeyMsg && msg.key == 'q') return (this, () => quit());
    return (this, null);
  }

  @override
  View view() => newView('Count: $count\\n\\n↑ to add · q to quit');
}`;

export default function HomePage() {
  const featured = getEntries("components").filter((e) => e.featured).slice(0, 6);

  return (
    <>
      {/* Hero */}
      <section className="relative overflow-hidden">
        <div className="pointer-events-none absolute inset-0 bg-grid bg-grid-fade opacity-70" />
        <div className="container relative py-20 sm:py-28">
          <div className="mx-auto max-w-3xl text-center">
            <Link
              href={siteConfig.pub}
              target="_blank"
              rel="noreferrer"
              className="inline-flex items-center gap-2 rounded-full border border-border bg-card px-3 py-1 text-xs font-medium text-muted-foreground transition-colors hover:border-mauve/40 hover:text-foreground animate-fade-in"
            >
              <span className="inline-block h-1.5 w-1.5 rounded-full bg-green" />
              v{siteConfig.version} is on pub.dev
              <ArrowRight className="h-3 w-3" />
            </Link>

            <h1 className="mt-6 text-balance text-4xl font-bold tracking-tight sm:text-6xl animate-fade-in">
              Terminal UIs in Dart,{" "}
              <span className="text-gradient">done right</span>.
            </h1>

            <p className="mx-auto mt-5 max-w-2xl text-balance text-lg leading-relaxed text-muted-foreground animate-fade-in">
              {siteConfig.name} is an Elm-style TUI framework — a clean
              Model–Update–View core, a full component library, and
              Lipgloss-quality styling, all in pure Dart.
            </p>

            <div className="mt-8 flex flex-col items-center justify-center gap-4 sm:flex-row animate-fade-in">
              <div className="flex gap-3">
                <Link
                  href="/components"
                  className="inline-flex h-11 items-center gap-2 rounded-lg bg-mauve px-5 font-medium text-[#11111b] transition-transform hover:-translate-y-0.5"
                >
                  Browse components
                  <ArrowRight className="h-4 w-4" />
                </Link>
                <a
                  href={siteConfig.github}
                  target="_blank"
                  rel="noreferrer"
                  className="inline-flex h-11 items-center gap-2 rounded-lg border border-border bg-card px-5 font-medium transition-colors hover:border-mauve/40"
                >
                  <Github className="h-4 w-4" />
                  GitHub
                </a>
              </div>
            </div>

            <div className="mt-6 flex justify-center animate-fade-in">
              <InstallPill />
            </div>
          </div>

          {/* Showcase */}
          <div className="mx-auto mt-16 max-w-4xl animate-fade-in">
            <TerminalFrame title="dart run example/showcase.dart" glow>
              <Image
                src="/gifs/showcase.gif"
                alt="dart_tui showcase"
                width={1200}
                height={700}
                unoptimized
                priority
                className="h-auto w-full rounded-md"
              />
            </TerminalFrame>
          </div>
        </div>
      </section>

      {/* Features */}
      <section className="border-t border-border/70">
        <div className="container py-20">
          <div className="mx-auto max-w-2xl text-center">
            <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">
              Everything you need to build in the terminal
            </h2>
            <p className="mt-3 text-lg text-muted-foreground">
              A complete toolkit — architecture, components, styling and
              animation — with none of the boilerplate.
            </p>
          </div>
          <div className="mt-14 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
            {features.map((f) => (
              <div
                key={f.title}
                className="rounded-xl border border-border bg-card p-5 transition-colors hover:border-mauve/30"
              >
                <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-mauve/10 text-mauve">
                  <f.icon className="h-5 w-5" />
                </div>
                <h3 className="mt-4 font-semibold tracking-tight">{f.title}</h3>
                <p className="mt-1.5 text-sm leading-relaxed text-muted-foreground">
                  {f.desc}
                </p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Quick start code */}
      <section className="border-t border-border/70">
        <div className="container py-20">
          <div className="grid items-center gap-10 lg:grid-cols-2">
            <div>
              <p className="font-mono text-xs font-semibold uppercase tracking-wider text-mauve">
                Quick start
              </p>
              <h2 className="mt-2 text-3xl font-bold tracking-tight sm:text-4xl">
                A whole app in one file
              </h2>
              <p className="mt-4 text-lg leading-relaxed text-muted-foreground">
                Extend <code className="font-mono text-mauve">TeaModel</code>,
                implement <code className="font-mono text-mauve">update</code>{" "}
                and <code className="font-mono text-mauve">view</code>, and
                hand it to a <code className="font-mono text-mauve">Program</code>.
                State is immutable, updates are pure, and the renderer does the
                rest.
              </p>
              <div className="mt-6 flex flex-wrap gap-3">
                <Link
                  href="/guides/installation"
                  className="inline-flex h-11 items-center gap-2 rounded-lg border border-border bg-card px-5 font-medium transition-colors hover:border-mauve/40"
                >
                  Read the guide
                  <ArrowRight className="h-4 w-4" />
                </Link>
                <Link
                  href="/guides/mvu-architecture"
                  className="inline-flex h-11 items-center gap-2 rounded-lg px-5 font-medium text-muted-foreground transition-colors hover:text-foreground"
                >
                  How MVU works
                </Link>
              </div>
            </div>
            <CodeBlock code={quickStart} lang="dart" />
          </div>
        </div>
      </section>

      {/* Component gallery */}
      <section className="border-t border-border/70">
        <div className="container py-20">
          <div className="flex flex-wrap items-end justify-between gap-4">
            <div>
              <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">
                Ready-made components
              </h2>
              <p className="mt-3 max-w-xl text-lg text-muted-foreground">
                Drop-in, stateful widgets — each a recorded, real terminal
                program.
              </p>
            </div>
            <Link
              href="/components"
              className="inline-flex items-center gap-1.5 text-sm font-medium text-mauve transition-colors hover:text-mauve/80"
            >
              View all {componentsList.length}
              <ArrowRight className="h-4 w-4" />
            </Link>
          </div>
          <div className="mt-10 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
            {featured.map((entry) => (
              <ComponentCard key={entry.slug} entry={entry} />
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="border-t border-border/70">
        <div className="container py-24">
          <div className="relative overflow-hidden rounded-2xl border border-border bg-card px-8 py-16 text-center">
            <div className="pointer-events-none absolute inset-0 bg-grid opacity-40" />
            <div className="relative mx-auto max-w-2xl">
              <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">
                Start building your TUI today
              </h2>
              <p className="mt-3 text-lg text-muted-foreground">
                Add the package, copy an example, and ship a beautiful
                command-line app.
              </p>
              <div className="mt-8 flex flex-col items-center gap-4 sm:flex-row sm:justify-center">
                <InstallPill />
                <Link
                  href="/guides/examples"
                  className="inline-flex h-11 items-center gap-2 rounded-lg bg-mauve px-5 font-medium text-[#11111b] transition-transform hover:-translate-y-0.5"
                >
                  See 60+ examples
                  <ArrowRight className="h-4 w-4" />
                </Link>
              </div>
            </div>
          </div>
        </div>
      </section>
    </>
  );
}
