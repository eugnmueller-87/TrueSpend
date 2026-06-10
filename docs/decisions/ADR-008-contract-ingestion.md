# ADR-008: Contract ingestion — demo seed now, live bulk/agentic routes later

Date: 2026-06-10
Status: Proposed (demo path active; live routes deferred — not yet built)

## Context

The Contract register reads the structured `contracts` table.

> Correction (2026-06-10): the register initially appeared empty ("No contracts
> found", all stat cards 0), which looked like missing data. Direct prod inspection
> showed the opposite — **88 contracts already exist**. The register query selected
> `contracts.contract_number`, a column that does NOT exist in the live table
> (a schema↔code divergence; schema.sql lists it, the live DB never had it), so
> PostgREST 400'd the WHOLE request and the page's `.catch(()=>[])` rendered empty.
> Fix: removed `contract_number` from the two `select=` clauses in App.jsx
> (lines ~3358 and ~4841). The register now shows Total 88 / Expired 1 / <30d 8 /
> <90d 39 / Auto-renew 44, and the Suppliers "Risk Flag" (derived in `riskFlag()`
> from contract expiry + `compliance_status`) lights up for the expiring ones.
> So the demo did NOT need a contract seed — the data was always there.

The plan below stands for the SEPARATE, real need: how a user bulk-loads NEW
contracts into the live environment (the register/ingestion has no upload UI yet).

A natural instinct is "build a RAG to upload contracts." That is the wrong tool
for this gap: TrueSpend already has a RAG layer (`document_embeddings`,
`search_documents_text()`, the `rag_embedder.json` workflow that embeds
`contracts` + `legal_documents` every 6h, and the "Search docs" page). **RAG
reads from `contracts` to index documents; it cannot populate an empty register.**
Contracts must exist as table rows first; RAG then makes their documents
searchable. So the real need is contract *ingestion* into the `contracts` table.

There is no contract-upload UI today — the register is read-only (search + stat
cards). The decision (2026-06-10) is: **populate the demo now via a seed, and
keep the live-ingestion feature open with a written plan rather than building it
prematurely.**

## Decision

### Now — demo
Nothing to seed: 88 contracts already exist. The demo was unblocked by the
one-line UI fix above (removing the non-existent `contract_number` from the
register's `select=`). The `rag_embedder` workflow already indexes these contracts
on its 6h tick. (An earlier `20_fix_demo_contracts.sql` was written and then
deleted once the 88 existing contracts were discovered — it would have injected
redundant `source='demo'` rows on top of real data.)

### Later — live ingestion (two routes, build when needed; not built yet)

**Route 1 — Structured bulk upload (CSV/XLSX → rows).** For loading an existing
contract list/export.
- UI: an "Upload contracts" action on the Contract register; parse the file
  client-side, preview/validate, then submit.
- Write path: a NEW `SECURITY DEFINER` RPC (e.g. `bulk_upsert_contracts(jsonb)`)
  — NOT a raw client INSERT. This honors I-1/I-2 and the Phase 2 posture (the
  browser token must not write business tables directly); ideally routed through
  the `/webhook/board-action` server path (ADR-006) so no money/data-write
  capability sits on the browser token.
- Supplier resolution: match `supplier_id` by name (ilike) server-side; rows that
  don't resolve go to a review list, never a silent drop.

**Route 2 — PDF drop → Claude extract → human confirm (agentic).** The showpiece;
reuses the invoice-processor shape and the Phase-1 "LLM advises, deterministic
code decides" guard.
- Drop a contract PDF → Claude extracts `{supplier, value, currency, start/expiry,
  notice_days, auto_renew, renewal_state, terms_summary, clauses}` as ADVICE.
- A deterministic guard validates the extraction (schema + allowlist + supplier
  resolution); the contract is queued to the Operations Board as `pending_review`
  — a human confirms before any row is written. Model output never writes a
  contract directly.
- On confirm: write the `contracts` row via the SECURITY DEFINER RPC, store the
  PDF as a `legal_documents` row, and let `rag_embedder` index both.

### RAG
No RAG work is required for either route — `rag_embedder.json` already consumes
`contracts`/`legal_documents`. If its prod state is unverified, verify/activate it
separately; do not rebuild it to solve ingestion. A pgvector upgrade (replacing
the text-embedding-as-JSON fallback in `db/migrations/_future/rag_schema_pgvector.sql`)
is an independent quality improvement, gated on Railway pgvector support.

## Consequences

- The demo is unblocked immediately with zero new code (seed 20, gated apply).
- The live feature has a written, boundary-aware plan (RPC-backed, board-confirmed)
  consistent with the Phase 1/2 security hardening — so "populate everything with
  contracts in live" is a scoped build, not an open question.
- Neither route lets the browser token or an LLM write a contract directly.

## Alternatives considered
- **Build RAG first** — rejected: RAG reads the register, it cannot fill it.
- **Raw client bulk INSERT to `/contracts`** — rejected: reintroduces exactly the
  browser-write exposure Phase 2/4 closed; must go through a definer RPC.
