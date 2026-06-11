# Security cutover & remediation runbook

One ordered checklist for the prod-touching security work that is written + tested
but gated on dashboard/secret access. Do the items in this order — later ones
assume earlier ones. Each step says who/where and how to verify.

Status legend: 🔴 urgent (live exposure) · 🟠 do soon · 🟢 when ready

---

## 🔴 1. Rotate the leaked production DB password

**Why now:** the real `truespend` PostgreSQL password is recoverable from git
history (commits incl. `2a44a42`, `d539fdb`, the old `HANDOVER.md`). The redaction
commit `d15fbf3` says verbatim *"The DB password still needs rotating in Railway
(value not yet changed)."* Current tracked files are clean, but history is public →
anyone who clones can read it. Assume it is compromised.

Steps (Railway dashboard → Postgres service):
1. Rotate the DB user password (Railway: regenerate, or `ALTER USER truespend WITH PASSWORD '<new>'` + `ALTER USER postgres ...` if the postgres super pw also leaked).
2. Update `DATABASE_URL` everywhere it's consumed: Railway PostgREST service
   (`PGRST_DB_URI` → uses `truespend_app`, not `truespend`, so confirm which user
   leaked), the n8n box `.env`, GitHub Actions secret `DATABASE_URL` (used by
   db-migrate CI), and your local `.env`.
3. Verify: old creds rejected; `bash scripts/db-migrate.sh --status` (dbmate) still connects with the new URL.

Optional but recommended: purge the secret from git history (BFG / `git filter-repo`)
so it's not forever in clones. Rotating makes the leaked value useless, which is the
important part; history-scrub is hygiene on top.

---

## 🔴 2. Rotate the PostgREST JWT  (see scripts/rotate_postgrest_jwt.md)

**Why:** `POSTGREST_JWT` (role `truespend_app`, exp 2036) is served in plaintext at
`/config.js` — publicly extractable. Rotating the **secret** (not just reissuing)
revokes it.

Steps (full detail in scripts/rotate_postgrest_jwt.md):
1. `openssl rand -hex 32` → NEW_SECRET
2. `node scripts/mint_postgrest_jwt.js <NEW_SECRET> truespend_app 365` → new browser token
   (and, for the cutover in §3, mint the n8n token WITH the privileged claim — see §3).
3. PostgREST service: set `PGRST_JWT_SECRET = NEW_SECRET`, redeploy (this revokes all old tokens).
4. Intake service `POSTGREST_JWT` + GH Actions secret `VITE_POSTGREST_JWT` + n8n `.env` `POSTGREST_JWT` → new tokens; redeploy each.
5. Verify: old token → 401; `/config.js` serves the new token; app loads.

> Do §1 and §2 together if the DB and PostgREST creds rotate in one sitting — both
> touch the PostgREST service config.

---

## 🟠 3. Phase 2 money-RPC fail-closed cutover  (ADR-006)

**Goal:** the browser token can no longer move money. Sequence matters — flipping
the DB guard before the n8n token + re-route is live BRICKS the board.

Order (do NOT reorder):
1. **Mint the n8n privileged token** (during §2's secret rotation):
   `node scripts/mint_postgrest_jwt.js <NEW_SECRET> truespend_app 365 procurement`
   → set this as the token behind n8n stored credential `CI2TdAwodddFXggz`
   ("PostgREST JWT"). board_action.json + invoice_processor + delivery automation use it.
2. **Import + activate `board_action.json`** in n8n (webhook `/board-action`). Verify
   it responds 400 to a junk action and 200 to a valid one (against a scratch ticket).
3. **Deploy the SPA with `VITE_ROUTE_MONEY_VIA_N8N=true`** (GH Actions build-arg /
   Railway intake var). Now the browser posts money actions to /board-action, not RPCs.
4. **Apply `000015_money_rpcs_fail_closed.sql`** via `bash scripts/db-migrate.sh`
   (after the dbmate ledger reconciliation, §4), then `NOTIFY pgrst, 'reload schema'`.
   This flips the money RPCs fail-closed.
5. **Verify:** `node scripts/repro_money_rpc_exposure.js --assert-blocked`
   (browser token → 403 on approve_and_commit / create_payment) AND the board
   approve/reject/pay still work (routed through n8n with the privileged token).

---

## 🟠 4. dbmate ledger reconciliation + apply remaining migrations  (ADR-007)

**Why:** the repo moved to dbmate (000001..000016). Running `dbmate up` against the
old bespoke ledger would re-run everything destructively. Reconcile first.

Steps:
1. Pre-flight (read-only): `select name, applied_at from schema_migrations order by applied_at;`
   — confirm which old `stepN_*.sql` are recorded.
2. Run `db/reconcile_dbmate_ledger.sql` ONCE (renames the bespoke ledger → `_legacy`,
   creates dbmate's `schema_migrations(version)`, back-fills only applied versions).
3. `bash scripts/db-migrate.sh --status` → should show 000001–000013 applied,
   000014/000015/000016 pending (plus whatever §3 needs).
4. `bash scripts/db-migrate.sh` (= `dbmate up`) applies the pending ones; then
   `NOTIFY pgrst, 'reload schema'`.
5. `dbmate dump` → regenerate `db/schema.sql` as the labelled snapshot; this also
   reveals whether the ~11 ambiguous `tickets` denormalized columns are real.

> 000014 (supplier-email threading) and 000016 (outbox revoke) are independent of
> the money flip and safe to apply anytime after reconciliation. 000015 is the
> money flip — apply it only as part of §3's ordered sequence.

---

## 🟢 5. After cutover — tighten

- Re-run the full repro suite: `node workflows/__tests__/phase1_repro.test.js`,
  `node scripts/repro_outbox_forgery.js --assert-blocked`,
  `node scripts/repro_money_rpc_exposure.js --assert-blocked`.
- Update the README security section to drop "gated" qualifiers once the flips are live.
- Consider shortening the browser token expiry on the next rotation (1yr, not 10).
- Phase 2 follow-ups deferred earlier: scope the sensitive READS (contracts value,
  legal docs, budgets) behind server-side views; the raw `/suppliers` writes.

---

## What is already DONE (no action needed)
- All Phase 1–5 CODE is merged to `main` and the intake app is deployed (the
  prompt-injection guards, the API-client chokepoint, the dormant seam, the
  contract-register fix). Migrations do NOT auto-apply; the seam defaults OFF —
  so `main` is safe as-is until you run the gated steps above.
