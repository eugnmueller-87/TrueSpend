---
name: truespend-design
description: Use this skill to generate well-branded interfaces and assets for TrueSpend, either for production or throwaway prototypes/mocks/etc. Contains essential design guidelines, colors, type, fonts, assets, and UI kit components for prototyping the TrueSpend Operations Board and marketing surfaces.
user-invocable: true
---

Read the README.md file within this skill, and explore the other available files.

TrueSpend is an AI-native procurement operating system. The brand voice is *confident, provocative, precise* — closer to an opinionated newsletter than a SaaS dashboard. The visual language is editorial and finance-grade: warm paper backgrounds, ink-black text, a single brand gold (`#B07219`) for signal, hairline borders instead of shadows, Instrument Serif for display and Geist for UI.

Key files to read first:
- `README.md` — full brand and visual fundamentals, including the CONTENT FUNDAMENTALS section that captures the voice
- `colors_and_type.css` — every design token and semantic type class (`--ts-*`, `.ts-*`)
- `ui_kits/operations-board/` — JSX components that recreate the single product surface

If creating visual artifacts (slides, mocks, throwaway prototypes, etc), copy assets from `assets/` out into your project and link `colors_and_type.css`. Build static HTML files for the user to view. If working on production code, copy assets and read the rules here to become an expert in designing with this brand.

If the user invokes this skill without any other guidance, ask them what they want to build or design, ask some questions about audience, tone, and length, then act as an expert designer who outputs HTML artifacts _or_ production code, depending on the need.

**Hard rules** (carried from `README.md` — see the "What we don't do" section):
- No indigo / bluish-purple gradients
- No "rounded card with colored left-border" status accent
- No emoji as primary iconography (use Lucide icons — see ICONOGRAPHY section of README)
- No pure white surfaces — use `#FFFEFB`
- No drop shadows on text, no glow, no neon
- Sentence case for everything except tracked uppercase eyebrows
- Serif for display only; sans for all UI; mono for refs, IDs, currency in columns
