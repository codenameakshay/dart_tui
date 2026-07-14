# dart_tui documentation website

The marketing + documentation site for [`dart_tui`](https://pub.dev/packages/dart_tui),
modelled on the structure of [beui.dev](https://beui.dev): a landing page plus
**Components**, **Blocks** and **Guides** sections, with a ⌘K command palette,
light/dark themes, and recorded-GIF previews framed as terminal windows.

## Tech stack

- **Next.js 15** (App Router, React 19) — statically prerendered, deploys to Vercel with zero config
- **Tailwind CSS 3** with a Catppuccin-derived palette (matches the library's own GIFs)
- **shiki** for dual-theme Dart/bash/yaml syntax highlighting
- **cmdk** for the ⌘K search, **next-themes** for theming, **lucide-react** for icons

## Local development

```bash
cd website
npm install
npm run dev        # http://localhost:3000
```

```bash
npm run build      # production build (all pages prerendered)
npm run start      # serve the production build
```

## Content model

All documentation is data-driven from a typed registry — no MDX build step:

| File | Contents |
|------|----------|
| `content/components.ts` | The 18 components (spinner, table, tree, forms fields, …) |
| `content/blocks.ts` | Higher-level blocks (forms, prompts, gum helpers, canvas, …) |
| `content/guides.ts` | Guides (install, MVU, styling, commands, architecture, …) |
| `content/registry.ts` | Shared `DocEntry` / `ContentBlock` types |

Each entry drives one page via `components/doc-page.tsx`. To add or edit docs,
change the registry — the sidebar, search, index grids, prev/next nav and
footer all update automatically.

Component previews use the GIFs recorded by the package's own `make gifs`
target, copied into `public/gifs/`.

## Deploying to Vercel

This site lives in the `website/` subdirectory of the `dart_tui` repo. When
importing the repo into Vercel:

1. **Root Directory** → set to `website`
2. Framework preset → **Next.js** (auto-detected)
3. Build command / output → defaults (`next build`)

That's it — no environment variables required.

## Regenerating the preview GIFs

The GIFs are produced by the package tooling, not this site. From the repo root:

```bash
make gifs                    # re-record all GIFs (requires VHS + ffmpeg)
cp example/tapes/output/*.gif website/public/gifs/
```
