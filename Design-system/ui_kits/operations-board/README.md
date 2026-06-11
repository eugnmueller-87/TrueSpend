# Operations Board — TrueSpend UI Kit

A hi-fidelity recreation of TrueSpend's single product surface — the **Operations Board** — as a proper desktop dashboard. Originally a mobile-first React + Vite + Tailwind app in `intake/` of the source repo, rebuilt here with a sidebar + main + agent-activity rail layout in the paper-ink-gold language.

## Layout

A three-column desktop dashboard, Linear / Mercury / Ramp vocabulary:

- **Left sidebar (248 px)** — workspace nav (Operations, Catalog, My requests, New request), live sub-items under Operations for each open status with counts, Reference section (Suppliers, Budgets, Contracts), user card at the bottom.
- **Main column (flex)** — sticky top bar with breadcrumb + global search + notification bell, then page content. The Board shows a big editorial headline, a 4-stat strip, then the ticket sections.
- **Right rail (320 px)** — *Agent · today* feed showing the silent work the agent is doing right now (auto-approvals, reorders, shelfware cleanup). This is the proof point for the brand promise.

The rail collapses below 1180 px; the sidebar collapses below 860 px.

## What's in here

```
operations-board/
├── index.html        ← entry point, loads everything
├── board.css         ← desktop layout + components (layered on colors_and_type.css)
├── Icons.jsx         ← Lucide-style line icons (replaces emoji)
├── Pills.jsx         ← StatusPill, CompliancePill, money formatting
├── Shell.jsx         ← Sidebar + TopBar with breadcrumb + search
├── Screens.jsx       ← Home, Catalog (grid), OrderModal, MyOrders (table), RequestForm, Success
├── Board.jsx         ← Operations Board: TicketRow, StatsStrip, AgentRail
└── App.jsx           ← Routing + state
```

## Click-through demo

Open `index.html`. The app boots on the **Operations** tab — the centerpiece.

1. Click any ticket row → it expands inline to show the **agent brief** and the **five signals** with red/amber/green dots. The Adobe row opens by default.
2. Take an action (Sign & send / Approve / Acknowledge / Confirm) — the row leaves the board, and counts in the sidebar + stats strip update in real time. Clear all four and you'll see the *"Nothing needs you"* empty state with the agent rail still ticking on the right.
3. **Catalog** → grid of pre-negotiated items by category → **Order** opens a modal → place → success state with a generated reference.
4. **New request** → tile picker → form (purchase pre-fills with the Anthropic example) → submit → success.
5. **My requests** → a desktop table with all of Eva's recent submissions and the PO numbers the agent generated.

The sidebar's sub-items under Operations are smooth-scroll anchors — click *Escalated* to jump to that section.

## Faithful to the legacy

Information architecture mirrors `intake/src/App.jsx`:

- Same status flow: `signature_required` → `pending_review` → `escalated` → `pending_confirm` → `approved`
- Same four request types (purchase / renew / onboard / other)
- Same catalog categories (Hardware / Software / Cloud / Services)
- Same five-signal reasoning language in the agent brief
- Same `de-DE` currency formatting

What changed: the **layout** (mobile-first phone → real desktop dashboard), the **visual language** (paper · ink · gold), the **iconography** (Lucide replaces emoji), and the **copy** (sentence case, editorial pull-outs in the serif).

## Component patterns to reuse

| Pattern | Where it lives |
|---|---|
| `.btn--primary` (gold), `.btn--ink` (signature), `.btn--danger`, `.btn--success`, `.btn--secondary`, `.btn--tertiary` | `board.css` |
| `<StatusPill status="…">` and `<CompliancePill>` | `Pills.jsx` |
| `<TicketRow>` with expandable five-signal brief | `Board.jsx` |
| `<StatsStrip>` — 4-cell summary header | `Board.jsx` |
| `<AgentRail>` — pulsing-dot live feed of agent activity | `Board.jsx` |
| `<Sidebar>` with section counts + status sub-items | `Shell.jsx` |
| `.pagehead` + serif H1 with optional italic gold accent | every page |
| `formatEuro(n)` helper for `de-DE` money | `Pills.jsx` |

## Responsive behavior

- ≥ 1180 px: full three-column layout with agent rail
- 860 – 1180 px: rail collapses, sidebar + main remain
- < 860 px: sidebar stacks above the main, ticket-row columns thin out

The original mobile-first version is preserved in git history if you ever want to pull it back for a phone build.

## Known omissions (faithful)

We chose not to recreate:
- The first-run "Welcome" modal — well-trodden territory.
- A real authenticated user system — Eva is hard-coded in `App.jsx`.
- Live network calls — submissions and actions are local optimistic updates with mocked refs.
