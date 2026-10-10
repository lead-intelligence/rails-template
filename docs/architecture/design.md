# Design

The visual language is DaisyUI 5 over Tailwind v4, with both vendored in `app/assets/tailwind/` (`daisyui.mjs`, `daisyui-theme.mjs`) so no Node toolchain is needed. `app/assets/tailwind/application.css` declares the two themes the app ships, `light` and `dark`, as full OKLCH palettes through the theme plugin, and holds the `.docs` component styles the documentation site renders into.

The palette is warm neutral with one accent: base and content in the sand hues, a terracotta `primary`, a muted teal `accent`, and semantic colors desaturated toward the same warmth. `primary` is dark in the light theme and light in the dark one, with `primary-content` inverted to match, because a single lightness cannot carry legible text on both grounds.

Depth is off (`--depth: 0`, `--noise: 0`) and borders are a single pixel, so hierarchy comes from spacing and weight rather than shadow.

## Gotchas

The accessibility gate decides the palette. `ApplicationSystemTestCase#visit` audits axe-core against WCAG 2.1 A/AA in both color schemes on every visit, so a color that reads well but falls under 4.5:1 turns the whole system suite red rather than producing a subtle regression.

The neutrals fail before the accent does. DaisyUI paints secondary text — form labels, `text-xs` captions — as `base-content` at reduced opacity, so the contrast that survives is what remains after the blend against `base-100`. A `base-100` slightly off white and a `base-content` slightly off black each look harmless and together drop that blended text below the threshold. Keep both extremes near the ends of the lightness range and carry the warmth in `base-200` and `base-300`, which reads the same and costs no contrast.

A page box that centers itself under `main` needs `w-full` beside `max-w-*` and `mx-auto`. The layout's `main` is a flex column, and a flex item with an automatic inline margin loses the stretch that would otherwise give it the full width, so it shrinks to its content and the page renders as a narrow ribbon that still looks deliberate. The pages that already carry `w-full` are the ones this has already bitten.

Tailwind generates CSS only for class names it finds under `app/`: `application.css` imports it with `source(none)` and adds that one directory. A class written anywhere else — a Markdown page, a test, a locale file — produces no CSS. Automatic detection would scan the whole repository instead, and every DaisyUI component a doc page names in prose (steps, tabs, tooltip, range) would ship to every visitor.

A theme change touches no view, which is what makes it safe to revert in one commit; a change that also edits markup no longer has that property.
