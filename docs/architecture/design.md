# Design

The visual language is DaisyUI 5 over Tailwind v4, with both vendored in `app/assets/tailwind/` (`daisyui.mjs`, `daisyui-theme.mjs`) so no Node toolchain is needed. `app/assets/tailwind/application.css` declares the two themes the app ships, `light` and `dark`, as full OKLCH palettes through the theme plugin, holds the `.docs` component styles the documentation site renders into, and maps Pagy's pagination nav onto DaisyUI classes (see pagination.md).

The palette is cool neutral with one accent: white and slate-blue grays for the base, an indigo `primary`, a teal `accent`, and semantic colors at the same lightness. `primary` is dark in the light theme and light in the dark one, with `primary-content` inverted to match, because a single lightness cannot carry legible text on both grounds. The body carries one faint indigo glow at the top of every page.

Depth is on (`--depth: 1`) for a soft lift on buttons and fields, and borders are a single pixel. Cards carry a `border-base-300` border as well as a small shadow, because a shadow does not show on the dark base.

The theme switcher (`app/views/shared/_theme_switcher.html.erb`) is a dropdown of three DaisyUI `theme-controller` radios: light, system and dark. `theme_controller.js` stores the choice in a `theme` cookie, and `ThemeHelper#theme_preference` reads it so the server renders the matching radio already checked. The theme therefore applies on the first paint, with no flash of the other theme and no script in the head. `system` names no theme, so with it checked the page follows the browser's colour-scheme preference. It is the default.

Icons are Lucide through the `lucide-rails` gem: `lucide_icon "house", class: "size-4"` renders inline SVG, with no icon font and no CDN. The first argument is the kebab-case name from the Lucide library; every keyword becomes an attribute of the `svg`, and the stroke follows `currentColor`, so `class:` sets size and colour. `LucideRails.default_options=` in an initializer would set global defaults; none is set.

A new app's own theme comes from a design tool fed with the design substrate and the brand brief under `docs/`. What comes back is a DaisyUI theme block for `app/assets/tailwind/application.css`, and the accessibility gate decides whether it ships.

## Gotchas

The accessibility gate decides the palette. `ApplicationSystemTestCase#visit` audits axe-core against WCAG 2.1 A/AA in both color schemes on every visit, so a color that reads well but falls under 4.5:1 turns the whole system suite red rather than producing a subtle regression.

The neutrals fail before the accent does. DaisyUI paints secondary text — form labels, `text-xs` captions — as `base-content` at reduced opacity, so the contrast that survives is what remains after the blend against `base-100`. A `base-100` slightly off white and a `base-content` slightly off black each look harmless and together drop that blended text below the threshold. Keep both extremes near the ends of the lightness range and carry the warmth in `base-200` and `base-300`, which reads the same and costs no contrast.

A page box that centers itself under `main` needs `w-full` beside `max-w-*` and `mx-auto`. The layout's `main` is a flex column, and a flex item with an automatic inline margin loses the stretch that would otherwise give it the full width, so it shrinks to its content and the page renders as a narrow ribbon that still looks deliberate. The pages that already carry `w-full` are the ones this has already bitten.

Tailwind generates CSS only for class names it finds under `app/`: `application.css` imports it with `source(none)` and adds that one directory. A class written anywhere else — a Markdown page, a test, a locale file — produces no CSS. Automatic detection would scan the whole repository instead, and every DaisyUI component a doc page names in prose (steps, tabs, tooltip, range) would ship to every visitor.

A theme change touches no view, which is what makes it safe to revert in one commit; a change that also edits markup no longer has that property.

The navbar is sticky at `z-30` and its dropdowns open at `z-40`, so anything that floats over the top of the page needs a higher layer. The flash toast sits at `z-50`; below the navbar its dismiss button cannot be clicked.
