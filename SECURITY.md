# TrueSpend — Security Protocol

> **This file is binding for all agents and contributors.**
> Every rule here exists because a violation already happened.
> Read it before touching credentials, workflows, or infrastructure.

---

## The one rule that matters most

**Credentials never go in source code. Ever.**

Not in workflow JSON. Not in React source. Not in SQL seeds.
Not even temporarily. Not even for testing.

The PostgREST JWT was hardcoded in `intake_receiver.json` across 66 commits
and shipped in the compiled browser bundle (`intake/dist/`). It had to be
rotated, scrubbed from history with `git filter-repo`, and force-pushed.
That is expensive, irreversible-ish, and embarrassing. Don't repeat it.

---

## Credential locations — where things live

| Credential | Where it lives | How workflows access it |
|---|---|---|
| `POSTGREST_JWT` | n8n container env (`/docker/n8n-n3xl/.env`) | `$env.POSTGREST_JWT` in code nodes |
| `POSTGREST_URL` | n8n container env | `$env.POSTGREST_URL` in code nodes |
| PostgREST auth (httpRequest nodes) | n8n credential: **Authorization-TrueSpend** | assigned via `credentials` field |
| `ANTHROPIC_API_KEY` | n8n credential: **Anthropic-Truespend** | assigned via `credentials` field |
| `PGRST_JWT_SECRET` | Railway → postgrest service → Variables | PostgREST reads it at startup |
| `VITE_POSTGREST_JWT` | Railway → intake service → Variables | Baked into React build at deploy time |
| `VITE_POSTGREST_URL` | Railway → intake service → Variables | Baked into React build at deploy time |
| `DOCUSIGN_RSA_PRIVATE_KEY` | n8n container env | `$env.DOCUSIGN_RSA_PRIVATE_KEY` |
| DocuSign keys | n8n container env | `$env.DOCUSIGN_INTEGRATION_KEY` etc. |
| IMAP / SMTP | n8n credential: **IMAP TrueSpend**, **SMTP-TrueSpend** | assigned via `credentials` field |
| Jira | n8n credential: **Jira TrueSpend** | assigned via `credentials` field |

**Nothing in this table belongs in a `.json` workflow file or `.jsx` source file.**

---

## Rules for n8n workflow files

### Code nodes (`n8n-nodes-base.code`)

```javascript
// ✅ CORRECT
const JWT      = $env.POSTGREST_JWT;
const POSTGREST = $env.POSTGREST_URL || 'https://postgrest-production-7960.up.railway.app';

// ❌ WRONG — will be caught by pre-commit hook and quality gate
const JWT = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
```

The fallback URL in `$env.POSTGREST_URL || 'https://...'` is acceptable — it's a
public endpoint URL, not a credential. The JWT must never be hardcoded.

### httpRequest nodes

Use the `Authorization-TrueSpend` Header Auth credential — **do not** add a manual
`Authorization` header with a hardcoded Bearer token.

```json
// ✅ CORRECT — credential reference
"credentials": {
  "httpHeaderAuth": { "id": "diPB8BwY8mvOiQb3", "name": "Authorization-TrueSpend" }
}

// ❌ WRONG — hardcoded in header parameters
"headerParameters": {
  "parameters": [{ "name": "Authorization", "value": "Bearer eyJhbGciOi..." }]
}
```

---

## Rules for React / frontend code

`VITE_*` variables are baked into the compiled bundle at build time.
That bundle is public. Anything in a `VITE_*` variable becomes public.

- Only `VITE_POSTGREST_URL` and `VITE_POSTGREST_JWT` are intentionally public
  (the DB role they access has RLS — only reads what the policy allows)
- Never add `VITE_ANTHROPIC_API_KEY`, `VITE_RAILWAY_TOKEN`, or any write-capable secret
- **`intake/dist/` must never be committed** — it's in `.gitignore`

---

## JWT rotation procedure

When a JWT is compromised or rotated:

1. **Generate** new secret + token:
   ```bash
   node -e "
   const crypto = require('crypto');
   const secret = crypto.randomBytes(32).toString('hex');
   const now = Math.floor(Date.now()/1000);
   const exp = now + Math.floor(10 * 365.25 * 24 * 3600);
   const h = Buffer.from(JSON.stringify({alg:'HS256',typ:'JWT'})).toString('base64url');
   const p = Buffer.from(JSON.stringify({role:'truespend',iat:now,exp})).toString('base64url');
   const s = crypto.createHmac('sha256',secret).update(h+'.'+p).digest('base64url');
   console.log('SECRET=' + secret);
   console.log('JWT=' + h+'.'+p+'.'+s);
   "
   ```

2. **Update Railway** (PostgREST service): set `PGRST_JWT_SECRET` to new secret

3. **Update Railway** (intake service): set `VITE_POSTGREST_JWT` to new token

4. **Update n8n credential**: `Authorization-TrueSpend` → new `Bearer <token>`

5. **Update n8n env file** on VPS:
   ```bash
   # On 187.127.87.206:
   nano /docker/n8n-n3xl/.env   # update POSTGREST_JWT=<new token>
   cd /docker/n8n-n3xl && docker compose up -d --force-recreate
   ```

6. **Verify**:
   ```bash
   # Old token should 401, new token should 200
   curl -s -o /dev/null -w "%{http_code}" https://postgrest-production-7960.up.railway.app/tickets?limit=1 \
     -H "Authorization: Bearer <OLD>"
   curl -s -o /dev/null -w "%{http_code}" https://postgrest-production-7960.up.railway.app/tickets?limit=1 \
     -H "Authorization: Bearer <NEW>"
   ```

7. **Purge history** if old token was ever committed:
   ```bash
   git filter-repo --replace-text <(echo "OLD_TOKEN==>REDACTED_JWT") --force
   git push origin --force --all
   git fetch origin && git reset --hard origin/main
   ```

---

## Automated enforcement

### Pre-commit hook

Installed at `.git/hooks/pre-commit`. Reinstall after cloning:
```bash
bash scripts/install-hooks.sh
```

**Blocks commits containing:**
- HS256 JWT tokens (`eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`)
- RSA/EC private keys
- Real `.env` files (not `.env.example`)
- `intake/dist/` build artifacts
- Anthropic (`sk-ant-`), OpenAI (`sk-`), Jira (`ATATT`), or Railway API keys

### Quality gate

```bash
bash scripts/quality-gate.sh
```

Runs security checks as step S (before all other checks). Fails the gate if any
hardcoded credential is found in tracked files. Run before every push.

---

## What agents must do

If you are an AI agent working on this codebase:

1. **Never write a credential value** into a workflow `.json`, `.jsx`, `.sql`, or any
   other tracked file. Use the reference patterns shown above.

2. **Never commit `intake/dist/`**. If the build is needed, the CI/CD pipeline
   on Railway builds it from source. Local builds stay local.

3. **Before pushing**, run `bash scripts/quality-gate.sh`. If it fails on a security
   check, fix the file — do not use `git commit --no-verify` to bypass.

4. **If you generate a new credential** (JWT, key, secret), write it to:
   - Railway env vars (via Railway API or dashboard)
   - n8n container `.env` on `187.127.87.206`
   - n8n credential store (via n8n API or UI)
   Never to a file that gets committed.

5. **If a credential is accidentally committed**, treat it as compromised immediately:
   rotate first, purge history second. The rotation makes the purge non-urgent;
   the purge makes the repo clean. Both are required.

---

## Current credential status (last rotated: 2026-05-30)

| Credential | Status | Notes |
|---|---|---|
| `POSTGREST_JWT` (live) | ✅ Rotated | Old token `a3uHWAINfZ...` dead, history purged |
| `PGRST_JWT_SECRET` | ✅ Rotated | New 32-byte hex secret on Railway |
| `VITE_POSTGREST_JWT` | ✅ Updated | Railway intake service updated |
| n8n `Authorization-TrueSpend` | ✅ Updated | New token in encrypted credential store |
| n8n container env | ✅ Updated | `/docker/n8n-n3xl/.env` with new JWT |
| DocuSign RSA key | ✅ In env only | Never committed — lives in n8n container env |
| Anthropic API key | ✅ In n8n credential | Never committed |
