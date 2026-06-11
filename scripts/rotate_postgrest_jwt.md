# Rotate the PostgREST JWT (runbook)

**Why:** `POSTGREST_JWT` (role `truespend_app`, 10-yr expiry) is served in plaintext
at `https://intake-production-84a0.up.railway.app/config.js` — anyone can extract
it. Rotation invalidates the leaked value. (It does NOT close the architectural
hole — the new token is also in config.js; that's what Phase 2 / ADR-006 fixes.
Rotation is harm-reduction until the fail-closed cutover.)

**Why this needs you:** minting a valid token requires `PGRST_JWT_SECRET` (the HS256
secret PostgREST validates against). It lives on the **PostgREST Railway service**
and is NOT readable with the project-scoped `RAILWAY_TOKEN` in `.env`. So steps 1
and 4–6 need Railway dashboard access.

---

## Option A — reissue a token (leaked token stays valid until its 2036 expiry)
Mint a new token signed with the EXISTING secret and swap it in. Simple, but the
old leaked token KEEPS WORKING for 10 years (same secret, not yet expired). Only
use if you also shorten the new token's expiry and accept the old one lingers.

## Option B — rotate the SECRET (RECOMMENDED — instantly kills the leaked token)
Change `PGRST_JWT_SECRET`, which invalidates EVERY token signed with the old one
(the leaked browser token AND the n8n service token), then issue fresh tokens.
This actually revokes the exposure. Do all swaps in one sitting to avoid downtime.

### Steps (Option B)

1. **Generate a new secret** (≥32 bytes), locally:
   ```bash
   openssl rand -hex 32        # copy the output → NEW_SECRET
   ```

2. **Mint the new browser token** (low-power: short-ish expiry; role unchanged):
   ```bash
   node scripts/mint_postgrest_jwt.js <NEW_SECRET> truespend_app 365   # 1-year expiry
   # → prints the new browser JWT (role=truespend_app)
   ```
   And, separately, the n8n service token — once Phase 2 lands it should carry the
   privileged claim; for now keep it role-only to match current behavior:
   ```bash
   node scripts/mint_postgrest_jwt.js <NEW_SECRET> truespend_app 365   # n8n token
   ```
   (When ADR-006 cutover happens, mint the n8n one with app_role:'procurement'
   instead — see scripts/mint_postgrest_jwt.js --help.)

3. **PostgREST service (Railway dashboard → postgrest service → Variables):**
   set `PGRST_JWT_SECRET = <NEW_SECRET>`. Redeploy the PostgREST service.
   ⚠️ The moment this redeploys, ALL old tokens 401. Have the new tokens ready (step 2)
   and do steps 4–5 immediately.

4. **Intake service (Railway → intake service → Variables):**
   set `POSTGREST_JWT = <new browser token>`. Redeploy intake (or re-run the
   deploy-intake workflow) so /config.js serves the new token.
   Also update `VITE_POSTGREST_JWT` if it's set as a build-arg secret in the
   GitHub Actions secrets (it is — deploy-intake.yml passes it).

5. **n8n box** (`/docker/n8n-n3xl/.env`): set `POSTGREST_JWT = <new n8n token>`,
   then `docker compose up -d` to restart n8n so workflows use it.

6. **Verify:**
   ```bash
   # old token must now fail:
   curl -s -o /dev/null -w "%{http_code}\n" -H "Authorization: Bearer <OLD_TOKEN>" \
     https://postgrest-production-7960.up.railway.app/suppliers?limit=1     # expect 401
   # live config.js must serve the NEW token and the app must load data:
   curl -s https://intake-production-84a0.up.railway.app/config.js | head
   ```

### Also rotate (same exposure class)
- The **DB password** / `DATABASE_URL` if it was ever in `/config.js` or a public
  bundle (it should NOT be — confirm). The earlier "Remove leaked DB credentials"
  commit removed creds from tracked files but they remain in git history — if those
  were real, rotate them too.

### After rotation
- Update `.env` (local) and `.env.example` comment if the expiry changed.
- The REAL fix remains Phase 2 (ADR-006): make the browser token powerless so a
  future leak is inert. Rotation buys time, not closure.
