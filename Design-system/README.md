# TrueSpend Design System

> An editorial, finance-grade visual system for **TrueSpend** — the AI-native procurement operating system that makes procurement disappear, not run faster.

This is a redesign **away from** the previous theme (a chaotic, deeply dark `#0a0a0a` shell with an indigo `#6366f1` accent) toward something that reads as serious financial software: **paper, ink, gold**. Mercury / FT / Stripe energy. Confident without shouting.

The original product is intentionally minimal — *"three things need you this week, everything else the agent closed"*. The design language must echo that restraint: tight palette, narrow type scale, hairline rules, no decorative gradients, no emoji cards, no neon glow.

---

## Sources

This system was built from these sources (the reader may or may not have access; URLs and paths preserved for reference):

| Source | Where |
|---|---|
| Product GitHub repo | <https://github.com/eugnmueller-87/TrueSpend> — explore further to refine the system against the real codebase |
| Intake / Operations Board (React + Vite) code | `intake/` in the attached codebase |
| LinkedIn launch sequence (6 posts) | `content/linkedin/post_01.md` … `post_06.md` |
| Setup docs | `docs/intake_setup.md`, `docs/grafana_setup.md`, etc. |
| Brand hero (the only existing visual asset) | `screenshots/hero.png` → preserved at `assets/hero-billboard.png` |
| Product narrative | `README.md`, `STORY.md`, `ROADMAP.md` in the repo |

---

## What this folder contains

```
TrueSpend Design System/
├── README.md                  ← you are here
├── SKILL.md                   ← Agent Skill manifest (Claude Code compatible)
├── colors_and_type.css        ← all design tokens + semantic type classes
├── assets/                    ← logos, brand imagery
├── fonts/                     ← (Google Fonts — loaded via @import in CSS)
├── preview/                   ← Design System tab cards (registered assets)
├── ui_kits/
│   └── operations-board/      ← React JSX recreations of the Ops Board UI
└── research/                  ← reference material, not for production use
```

The **products** identified for this system:

1. **Operations Board** — the single web product. A focused, paper-feel desktop+mobile interface where humans see only what they need to act on. (Originally the only screen — and intentionally so.)

---

## CONTENT FUNDAMENTALS

The voice is the most distinctive thing about TrueSpend. It is not a SaaS voice. It is closer to an opinionated newsletter or a financial analyst's note.

### Tone

**Confident. Provocative. Precise.** Sentences are short, declarative, often one-line paragraphs. The writer trusts the reader to keep up.

> *"Procurement doesn't need to be faster. It needs to not exist."*
> *"I'm not building a procurement tool. I'm building the answer to a problem that procurement was always trying to solve badly."*
> *"Three things need you this week. Everything else, the agent closed."*

### Casing

- **Sentence case** for everything — headlines, buttons, navigation, labels. No Title Case Marketing Copy.
- **UPPERCASE** only for tiny eyebrow labels (`SIGNATURE REQUIRED`, `REF`, `PENDING REVIEW`) — always tracked wide (~0.14em).
- Currency: `€` symbol, German locale grouping (`€2.199`, `€576.000`), `de-DE` formatting baked into the codebase.

### Person

- **First-person from the founder** in marketing copy ("*I'm building…*", "*I don't fix it. I make it irrelevant.*")
- **Second-person from the agent** in product copy ("*Three things need you this week.*", "*You'll hear back at jane@…*")
- Never "we" — there is no "we" in this product yet. It's one person and an agent.

### Emoji

**Almost never.** The brand hero, the LinkedIn arc, and the marketing voice contain zero emoji.

The legacy intake UI uses category-icon emoji (`💻 📱 ☁️ 🔧 🛒 🔄 🏢 ⚡`) as a shortcut. In the redesign we **replace these with line icons (Lucide)** — see [ICONOGRAPHY](#iconography) below. The new system permits emoji only in user-submitted notes, never in product chrome.

### Vocabulary

A handful of in-house terms used consistently:

- **Three signals / five signals** — the agent's reasoning model
- **Confidence**, not "approval"
- **Surface**, not "notify" ("the agent surfaces what needs attention")
- **One-touch** decisions
- **Closed** rather than "completed" or "done"
- **Brief** — a pre-prepared package of context for a human decision
- **Auto-executed**, **Escalated**, **Signature required** — status verbs

### Numbers and proof

The product copy is dense with concrete numbers (€70M hardware spend, €576k bundle waste, 28 days notice, 95% confidence floor, 80% of volume by month 12). Designs should reserve space for big, legible, tabular numbers — they are the punchline.

### Sample copy snippets to reuse

```
Hero        — Procurement doesn't need to be faster. It needs to not exist.
Subhead     — One board. The three things that need you this week. Nothing else.
Tagline     — Confidence over control.
Promise     — Three things need you this week. Everything else, the agent closed.
Empty state — Nothing needs you right now. The agent is handling everything.
Trust line  — The agent earns autonomy. It never expands its own authority.
```

---

## VISUAL FOUNDATIONS

The thesis: **paper, not screen.** A senior financial analyst's notebook, not a SaaS dashboard. The legacy product reads as dark, low-contrast, and undifferentiated — six things competing for attention with no hierarchy. The new system trades the dark shell for a warm paper canvas and reserves saturation entirely for the agent's "T" gold.

### Color philosophy

| Role | Token | Hex | Use |
|---|---|---|---|
| Canvas | `--ts-paper` | `#F7F4ED` | Default background. Warm off-white — never pure white. |
| Card | `--ts-surface` | `#FFFEFB` | Cards, sheets, modals. Sits one note above paper. |
| Ink | `--ts-ink` | `#161413` | Primary text. Near-black, warmed. |
| Gold | `--ts-brand-gold` | `#B07219` | The single accent. Used for the mark, primary actions, the agent's confidence signal — *nothing decorative*. |
| Sage | `--ts-positive` | `#3D7A5A` | Approved, on-track. Muted, never neon green. |
| Brick | `--ts-negative` | `#B5462E` | Blocked, rejected, signature required. |
| Amber | `--ts-warning` | `#C99119` | Needs attention. Slightly cooler than the brand gold so they don't collide. |
| Slate-teal | `--ts-info` | `#2B5F7A` | Informational only — escalation routes, secondary tags. |

All semantic colors have `-soft` (chip background) and `-wash` (panel tint) companions. Saturation is intentionally low across the board so the gold has air around it.

### Type philosophy

Two families do everything: **Instrument Serif** (display, italic accents, editorial moments) and **Geist** (every piece of UI and body copy). **Geist Mono** for references, IDs, currency where columns need to align.

The serif carries voice. The sans carries function. They never compete — serif is reserved for headlines, pull quotes, and the brand wordmark.

> **Font substitution flag:** The original codebase used the system font stack. No specific custom font was specified for TrueSpend. We've chosen Instrument Serif + Geist + Geist Mono as a coherent editorial/finance pairing — all are free Google Fonts. If TrueSpend has a preferred or licensed family (e.g., Tiempos, GT America, Söhne, Untitled Sans), drop the files in `fonts/` and swap the `@import` line at the top of `colors_and_type.css`.

### Spacing

A 4 px base scale (`4, 8, 12, 16, 20, 24, 32, 40, 48, 64, 80`). Generosity matters more than density: this is not a Bloomberg terminal. A standard card has **24 px** internal padding; a section has **48–64 px** of vertical breathing room.

### Backgrounds

- **No gradients in product UI** other than one allowed: a vertical tonal wash on the marketing hero (`#161413` → `#0E0B09`) that echoes the brand billboard.
- **No repeating patterns or hand-drawn illustrations.**
- **No images in chrome.** The brand hero (`assets/hero-billboard.png`) is allowed once, on marketing surfaces. Product pages stay imageless.
- Paper canvas is a flat fill. The only texture is the **hairline rule**.

### Borders & rules

- Default border: **1 px** of `--ts-line` (`#E5DDD0`). Hairline. Always 1px — never 2.
- Strong rule (e.g. under page H1): 1 px `--ts-line-strong`.
- Rules carry hierarchy in this system the way shadow does in most others. We use the rule first, the shadow rarely.

### Shadows

Restrained. Three levels and you should rarely use any:

- `--ts-shadow-sm` — resting cards (1 px subtle), often replaced by border
- `--ts-shadow-md` — hover lift on interactive cards
- `--ts-shadow-lg` — modals, popovers, command menu

**No glow. No colored shadows. No inner glow.**

### Corner radii

| Radius | Token | Where |
|---|---|---|
| 2 px | `--ts-radius-xs` | Tags, chips, inline status pills |
| 4 px | `--ts-radius-sm` | Buttons, inputs, segmented controls |
| 6 px | `--ts-radius-md` | Cards |
| 10 px | `--ts-radius-lg` | Large surfaces, modals |
| Pill | `--ts-radius-pill` | Avatars, dot badges only |

Reserved. No 16 px / 20 px / 24 px card radii. This is a **document**, not a candy app.

### Cards

A card is: **paper-white surface · 1 px hairline border · 6 px radius · 24 px padding · no shadow at rest**. On hover, the border deepens by one tone (`--ts-line-strong`) — never any lift unless the card is genuinely clickable as a row.

We do **not** use "rounded card with colored left-border accent" — explicitly forbidden by the brand brief, and it's a classic SaaS tell we're escaping.

### Animation

Subtle, fast, purposeful.

- Default ease: `cubic-bezier(0.2, 0.6, 0.2, 1)` — gentle ease-out
- Default duration: **120 ms** for hovers, **220 ms** for state changes, **420 ms** only for the checkmark draw on success
- **No bounces. No spring overshoot.** Easing-out only — the system never feels playful. It feels considered.
- The success animation (a hairline check drawing inside a sage circle) is the one moment of warmth.

### Hover, press, focus

| State | Treatment |
|---|---|
| Hover (link) | Underline appears as a 1 px decoration; color unchanged |
| Hover (button — primary) | Background shifts gold → gold-deep (`#B07219` → `#8F5C12`) |
| Hover (button — secondary) | Background `transparent` → `--ts-paper-deep`; border unchanged |
| Hover (card row) | Border `--ts-line` → `--ts-line-strong`; **no transform** |
| Press | Translate Y +1 px (buttons only), darken by ~6% |
| Focus | 2 px outline at `--ts-brand-gold` with 2 px offset. Never removed. |
| Disabled | Opacity 0.45, no pointer events |

### Transparency & blur

Used **sparingly**. The success-screen backdrop is `rgba(247, 244, 237, 0.88)` with `backdrop-filter: blur(8px)`. Modal scrim is `rgba(22, 20, 19, 0.32)`. Nothing else uses blur.

### Imagery tone

When photography is needed (currently only the brand hero):
- **Warm grayscale** to deep amber highlights — never cool, never blue-grey.
- Strong chiaroscuro. Single warm light source.
- Subjects feel weighty, monumental, slightly worn — the brand hero's "post-apocalypse cathedral" mood, dialed down to "well-loved ledger" for product surfaces.

### Layout rules

- **Maximum reading width 720 px** for body content.
- **Maximum content width 1240 px** in product, with 32 px gutters.
- Top bar is **sticky**, hairline-divided, 56 px tall on desktop, 52 px on mobile. No drop shadow.
- Fixed navigation is **off** by default — content scrolls under a thin sticky bar only.
- Mobile is **bottom-nav** (matching the existing app), redrawn with line icons and paper finish.

### What we don't do

A short list of explicit anti-patterns (some are general; some are reactions to the legacy theme):

- No bluish-purple / indigo gradients
- No "rounded card with colored left-border" status accent
- No emoji as primary iconography
- No neon greens / reds / blues
- No glassmorphism, no frosted blur over hero imagery
- No drop-shadow underneath text
- No `text-transform: uppercase` on body or headings (only on tracked eyebrows)
- No pure white surfaces — `#FFFEFB` is the warmest white we allow

---

## ICONOGRAPHY

The TrueSpend codebase has **no native icon system** of its own. The existing UI uses:

- A handful of inline SVGs for the bottom nav (Home, Catalog, List, Board) — 20 × 20, 1.5 stroke, single-color, currentColor-aware. Good system; we keep this style.
- Emoji (`💻 📱 ☁️ 🔧 🛒 🔄 🏢 ⚡ ✍️ 👁 🚨 📦 ✅ 📋 ↻ ✕`) as category and section icons. **We replace these.**

### Substitution: Lucide

We adopt **[Lucide](https://lucide.dev)** as the icon system. Reasons:

- Identical stroke language to the existing custom SVGs (1.5 px, rounded join, single-color)
- Covers every emoji currently in use, with cleaner intent
- CDN-deliverable, no font payload, fully tree-shakeable when bundled
- Open source (ISC license)

**Flagged for the user:** This is a substitution — the original product had no formal icon library. If TrueSpend later licenses or commissions a custom set, swap `lucide` for the local sprite.

### Usage

Load via CDN for prototypes:

```html
<script src="https://unpkg.com/lucide@latest/dist/umd/lucide.js"></script>
<script>lucide.createIcons();</script>
```

Or as inline SVG copied from <https://lucide.dev/icons>.

| Legacy | Replace with | Lucide name |
|---|---|---|
| 💻 Hardware | Laptop outline | `laptop` |
| 📱 Software | App-window | `app-window` |
| ☁️ Cloud | Cloud | `cloud` |
| 🔧 Services | Wrench | `wrench` |
| 🛒 Purchase | Shopping-bag | `shopping-bag` |
| 🔄 Renew | Refresh-cw | `refresh-cw` |
| 🏢 Onboard supplier | Building-2 | `building-2` |
| ⚡ Other / urgent | Zap | `zap` |
| ✍️ Signature required | Pen-line | `pen-line` |
| 👁 Pending review | Eye | `eye` |
| 🚨 Escalated | Siren | `siren` |
| 📦 Awaiting delivery | Package | `package` |
| ✅ Cleared empty state | Check-circle-2 | `check-circle-2` |
| 📋 No requests | Inbox | `inbox` |
| ↻ Refresh | Rotate-cw | `rotate-cw` |
| ✕ Close | X | `x` |

### Rules

- **Stroke 1.5 px**, rounded join, rounded cap. Default size **18 px** in body, **20 px** in nav, **16 px** in small buttons.
- **Single color** — `currentColor`. Never multi-color icons.
- Icons sit on the **baseline** of the label they accompany, with a fixed gap of **8 px** (`--ts-space-2`).
- **No filled icons** in chrome. Filled is reserved for the active state of bottom-nav tabs and the brand mark.
- Unicode chars used as icons: **none**. The original `↻`, `↙` ASCII arrows are replaced with `rotate-cw` and `chevron-down`.

---

## INDEX

A manifest of this design system's contents.

### Foundations
- [`colors_and_type.css`](colors_and_type.css) — full token set and semantic typography classes. **Start here.**
- [`SKILL.md`](SKILL.md) — Agent Skill manifest, compatible with Claude Code

### Brand assets (`assets/`)
- `logo-mark.svg` — the gold "T" mark on ink
- `logo-lockup.svg` — mark + wordmark, for light surfaces
- `logo-lockup-inverse.svg` — mark + wordmark, for dark surfaces
- `hero-billboard.png` — the brand hero ("Procurement as we know it is dead.") — the one allowed full-bleed image

### Design System cards (`preview/`)

Cards visible in the Design System tab. Source HTML lives here; each is registered with the asset manifest. Groups:

- **Brand** — wordmark, monogram, hero treatment, tagline lockup
- **Type** — display serif specimens, body sans scale, mono usage, in-context paragraphs
- **Colors** — paper canvas, ink scale, signal gold, semantic colors (sage/brick/amber/slate)
- **Spacing** — radius scale, shadow scale, spacing tokens, hairline rule system
- **Components** — buttons, inputs, status pills, tickets, navigation, money treatment

### UI kits (`ui_kits/`)
- [`operations-board/`](ui_kits/operations-board/) — the single product surface. Hi-fi clickable recreation in JSX.

---

## How to use this system

If you're a designer or engineer working on TrueSpend marketing, decks, or product:

1. Import `colors_and_type.css` — every token and semantic class is namespaced `--ts-*` / `.ts-*` so it won't collide.
2. Use the existing semantic classes (`.ts-hero`, `.ts-body`, `.ts-eyebrow`, `.ts-money`) before reaching for raw tokens.
3. Pull components from `ui_kits/operations-board/` rather than rebuilding.
4. Reference the [voice samples](#content-fundamentals) above before writing any new copy.
5. When in doubt, **remove an element**. The brand premise is restraint.
