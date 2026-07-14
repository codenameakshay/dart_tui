import type { Config } from "tailwindcss";

const config: Config = {
  darkMode: "class",
  content: [
    "./app/**/*.{ts,tsx,mdx}",
    "./components/**/*.{ts,tsx}",
    "./content/**/*.{ts,tsx}",
  ],
  theme: {
    container: {
      center: true,
      padding: "1.5rem",
      screens: {
        "2xl": "1200px",
      },
    },
    extend: {
      colors: {
        // Semantic tokens driven by CSS variables (see globals.css).
        background: "hsl(var(--background) / <alpha-value>)",
        foreground: "hsl(var(--foreground) / <alpha-value>)",
        card: "hsl(var(--card) / <alpha-value>)",
        "card-foreground": "hsl(var(--card-foreground) / <alpha-value>)",
        popover: "hsl(var(--popover) / <alpha-value>)",
        "popover-foreground": "hsl(var(--popover-foreground) / <alpha-value>)",
        muted: "hsl(var(--muted) / <alpha-value>)",
        "muted-foreground": "hsl(var(--muted-foreground) / <alpha-value>)",
        border: "hsl(var(--border) / <alpha-value>)",
        input: "hsl(var(--input) / <alpha-value>)",
        ring: "hsl(var(--ring) / <alpha-value>)",
        // Brand accents — Catppuccin-derived, matching the library's own palette.
        mauve: "hsl(var(--mauve) / <alpha-value>)",
        green: "hsl(var(--green) / <alpha-value>)",
        sky: "hsl(var(--sky) / <alpha-value>)",
        peach: "hsl(var(--peach) / <alpha-value>)",
        // Terminal chrome
        term: {
          bg: "hsl(var(--term-bg) / <alpha-value>)",
          fg: "hsl(var(--term-fg) / <alpha-value>)",
          bar: "hsl(var(--term-bar) / <alpha-value>)",
        },
      },
      borderRadius: {
        lg: "0.75rem",
        md: "0.5rem",
        sm: "0.375rem",
      },
      fontFamily: {
        sans: ["var(--font-sans)", "ui-sans-serif", "system-ui", "sans-serif"],
        mono: [
          "var(--font-mono)",
          "ui-monospace",
          "SFMono-Regular",
          "Menlo",
          "monospace",
        ],
      },
      maxWidth: {
        prose: "46rem",
      },
      keyframes: {
        "fade-in": {
          from: { opacity: "0", transform: "translateY(8px)" },
          to: { opacity: "1", transform: "translateY(0)" },
        },
        "blink": {
          "0%, 49%": { opacity: "1" },
          "50%, 100%": { opacity: "0" },
        },
        "grid-flow": {
          from: { backgroundPosition: "0 0" },
          to: { backgroundPosition: "0 -40px" },
        },
      },
      animation: {
        "fade-in": "fade-in 0.5s ease-out both",
        "blink": "blink 1s steps(1) infinite",
      },
    },
  },
  plugins: [],
};

export default config;
