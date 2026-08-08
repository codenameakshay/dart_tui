import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export const siteConfig = {
  name: "dart_tui",
  tagline: "Elm-style terminal UI framework for Dart",
  description:
    "Build rich, interactive CLI applications in pure Dart with a clean Model–Update–View architecture, 27+ ready-made components, and Lipgloss-quality styling.",
  url: "https://dart-tui.vercel.app",
  github: "https://github.com/codenameakshay/dart_tui",
  pub: "https://pub.dev/packages/dart_tui",
  version: "2.0.0",
};
