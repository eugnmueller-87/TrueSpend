# ADR-004: DocuSign JWT Grant for e-Signatures
Date: 2026-05-30
Status: Accepted

## Context

TrueSpend creates legal documents (NDAs, DPAs) and procurement approvals that require authorised signatures. Previously, `signature_required` tickets had no automated signing path — the board showed the ticket but the user had to handle signing out-of-band.

Requirements:
- No browser popup / OAuth redirect (must work from within the Operations Board without navigation away)
- Server-to-server auth (no per-user OAuth flow in a multi-user tool)
- Embedded signing experience (signer stays in the app context)
- Callback to update ticket status on signing completion

## Decision

Use DocuSign eSignature API with JWT Grant (server-to-server, no popup). Sandbox environment (`account-d.docusign.com`) for current pre-production use.

### Auth flow
1. n8n `docusign_sign.json` workflow (ID: `D4aWf18qlGfxL4Qm`) receives POST from Ops Board Sign button
2. Builds RS256 JWT: `{iss: INTEGRATION_KEY, sub: USER_ID, aud: account-d.docusign.com, scope: "signature impersonation"}`
3. Signs with `DOCUSIGN_RSA_PRIVATE_KEY` env var (stored as single line with `\\n` escaped; workflow unescapes: `.replace(/\\n/g, '\n')`)
4. POSTs to `{DOCUSIGN_OAUTH_URL}/oauth/token` with JWT assertion → receives access_token
5. Creates envelope via DocuSign REST API v2.1: document (from `legal_documents.content` or generated text), signer tabs (signHere + dateSigned)
6. Creates embedded recipient view with `returnUrl = INTAKE_URL + ?signed=1&ticket={id}`
7. Returns `{signing_url, envelope_id, ticket_id}` to Ops Board
8. Ops Board opens `signing_url` in new tab (`window.open(..., '_blank')`)
9. DocuSign fires webhook to `Truespend Docusign Received` workflow (ID: `Xq8MYxC2CCvdLd5v`) on signing completion/decline

### Key env vars (n8n server)
- `DOCUSIGN_INTEGRATION_KEY` — app integration key (UUID)
- `DOCUSIGN_USER_ID` — DocuSign user ID (UUID)
- `DOCUSIGN_ACCOUNT_ID` — DocuSign account ID (UUID)
- `DOCUSIGN_RSA_PRIVATE_KEY` — RSA private key, single-line `\\n`-escaped
- `DOCUSIGN_BASE_URL` — `https://demo.docusign.net/restapi` (sandbox)
- `DOCUSIGN_OAUTH_URL` — `https://account-d.docusign.com` (sandbox)

### Redirect URI
Registered at DocuSign: `https://intake-production-84a0.up.railway.app`
Used as `returnUrl` after signing.

### JWT consent
Pre-granted at `https://account-d.docusign.com/oauth/auth?...` for the registered app. Must be re-granted if integration key changes or scopes change.

## Consequences

- The Sign button in Ops Board only shows for `procurement` role (`App.jsx:924–925` `canSign = roleGroup === 'procurement'`)
- Ticket status after signing is updated by the DocuSign callback workflow, NOT by the Sign button click
- If n8n is down, the Sign button shows an actionable error message with SSH restart instructions (`App.jsx:1064–1070`)
- If DocuSign returns no URL, the error message includes the n8n execution URL for debugging (`App.jsx:1081–1086`)
- The IF node was removed from the workflow — `$env.VAR` does not evaluate in n8n IF node condition expressions. Straight-line flow with error thrown in Code node if vars missing (`CLAUDE.md` fixed issues: "DocuSign IF node")
- Webhook conflict was resolved: old workflow `womQsMmOTTD78LYq` was deleted; path `/webhook/docusign-sign` is now owned exclusively by `D4aWf18qlGfxL4Qm`
- For production: change `DOCUSIGN_BASE_URL` to `https://www.docusign.net/restapi` and `DOCUSIGN_OAUTH_URL` to `https://account.docusign.com`

## Invariants Affected

- I-6: RSA private key must live in n8n env var only. Quality gate checks for `BEGIN PRIVATE KEY` in tracked files.
- I-1: Ticket status update after signing goes through DocuSign callback workflow, not a client-side PATCH. VERIFY: DocuSign callback workflow (ID: Xq8MYxC2CCvdLd5v) implementation details not fully reviewed.
