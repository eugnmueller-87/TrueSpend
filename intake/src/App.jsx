import { useState, useEffect, useRef, useCallback } from 'react'

// ─── Config ───────────────────────────────────────────────────────────────────

const POSTGREST_URL = import.meta.env.VITE_POSTGREST_URL || 'https://postgrest-production-7960.up.railway.app'
const POSTGREST_JWT = import.meta.env.VITE_POSTGREST_JWT || ''

// ─── Constants ───────────────────────────────────────────────────────────────

const TICKET_TYPES = [
  { id: 'renew',    label: 'Renew a contract',   icon: '🔄', hint: 'Extend or renegotiate an existing agreement' },
  { id: 'purchase', label: 'Approve a purchase',  icon: '📦', hint: 'Get sign-off on a new spend item'           },
  { id: 'onboard',  label: 'Onboard a supplier',  icon: '🏢', hint: 'Bring a new vendor into the system'         },
  { id: 'other',    label: 'Something else',       icon: '⚡', hint: 'Any other procurement request'              },
]

const BRANCHES = [
  { label: 'Global HQ',    id: 'b1000000-0000-0000-0000-000000000001' },
  { label: 'DACH',         id: 'b1000000-0000-0000-0000-000000000002' },
  { label: 'UK & Ireland', id: 'b1000000-0000-0000-0000-000000000003' },
  { label: 'Benelux',      id: 'b1000000-0000-0000-0000-000000000004' },
  { label: 'France',       id: 'b1000000-0000-0000-0000-000000000005' },
  { label: 'Nordics',      id: 'b1000000-0000-0000-0000-000000000006' },
  { label: 'Iberia',       id: 'b1000000-0000-0000-0000-000000000007' },
  { label: 'Italy',        id: 'b1000000-0000-0000-0000-000000000008' },
  { label: 'CEE',          id: 'b1000000-0000-0000-0000-000000000009' },
  { label: 'Nordics East', id: 'b1000000-0000-0000-0000-000000000010' },
]

const SUPPLIER_CATEGORIES = ['Hardware', 'Cloud', 'SaaS', 'Services', 'Other']

const STATUS_CONFIG = {
  signature_required: { label: 'Signature Required', color: '#ef4444', bg: '#1a0808' },
  pending_review:     { label: 'Pending Review',      color: '#f59e0b', bg: '#1a1200' },
  escalated:          { label: 'Escalated',           color: '#a855f7', bg: '#120a1a' },
  pending_confirm:    { label: 'Awaiting Confirm',    color: '#6366f1', bg: '#0d0d1a' },
  approved:           { label: 'Approved — Awaiting Delivery', color: '#22c55e', bg: '#081a0d' },
  rejected:           { label: 'Rejected',            color: '#6b7280', bg: '#111111' },
  closed:             { label: 'Closed',              color: '#6b7280', bg: '#111111' },
}

const COMPLIANCE_CONFIG = {
  green:   { label: 'Compliant',    color: '#22c55e' },
  amber:   { label: 'Gaps',         color: '#f59e0b' },
  red:     { label: 'Blocked',      color: '#ef4444' },
  pending: { label: 'Pending',      color: '#6b7280' },
  running: { label: 'Running…',     color: '#6366f1' },
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function formatEuro(val) {
  if (!val && val !== 0) return '—'
  const n = parseFloat(val)
  if (isNaN(n)) return val
  return '€' + n.toLocaleString('de-DE', { minimumFractionDigits: 0, maximumFractionDigits: 0 })
}

function formatDate(iso) {
  if (!iso) return '—'
  return new Date(iso).toLocaleDateString('de-DE', { day: '2-digit', month: 'short', year: 'numeric' })
}

function timeAgo(iso) {
  if (!iso) return ''
  const diff = Date.now() - new Date(iso).getTime()
  const m = Math.floor(diff / 60000)
  if (m < 1)  return 'just now'
  if (m < 60) return `${m}m ago`
  const h = Math.floor(m / 60)
  if (h < 24) return `${h}h ago`
  return `${Math.floor(h / 24)}d ago`
}

function required(val) { return val && val.toString().trim().length > 0 }
function validEmail(val) { return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(val) }

async function pgFetch(path, options = {}) {
  const headers = {
    'Authorization': `Bearer ${POSTGREST_JWT}`,
    'Accept': 'application/json',
    ...(options.headers || {}),
  }
  const res = await fetch(`${POSTGREST_URL}${path}`, { ...options, headers })
  if (!res.ok) {
    const text = await res.text().catch(() => '')
    throw new Error(`PostgREST ${res.status}: ${text}`)
  }
  if (res.status === 204) return null
  return res.json()
}

// ─── Sub-components ──────────────────────────────────────────────────────────

function StepWrapper({ children }) {
  const ref = useRef(null)
  useEffect(() => {
    const el = ref.current
    if (!el) return
    el.classList.add('step-enter')
    requestAnimationFrame(() => requestAnimationFrame(() => {
      el.classList.remove('step-enter')
      el.classList.add('step-visible')
    }))
  }, [])
  return <div ref={ref} className="step-visible w-full">{children}</div>
}

function Label({ children, required: req }) {
  return (
    <label className="block text-sm font-medium text-white mb-1.5">
      {children}{req && <span className="text-indigo-400 ml-0.5">*</span>}
    </label>
  )
}

function FieldError({ msg }) {
  if (!msg) return null
  return <p className="mt-1.5 text-xs text-red-400">{msg}</p>
}

function Field({ label, error, required: req, children }) {
  return (
    <div className="mb-4">
      {label && <Label required={req}>{label}</Label>}
      {children}
      <FieldError msg={error} />
    </div>
  )
}

function TextInput({ value, onChange, placeholder, error, type = 'text', ...rest }) {
  return (
    <input type={type} value={value} onChange={(e) => onChange(e.target.value)}
      placeholder={placeholder} className={error ? 'error' : ''} {...rest} />
  )
}

function EuroInput({ value, onChange, placeholder = '0', error }) {
  return (
    <div className="relative">
      <span className="absolute left-3 top-1/2 -translate-y-1/2 text-sm pointer-events-none" style={{ color: '#666' }}>€</span>
      <input type="number" inputMode="decimal" value={value} onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder} className={error ? 'error' : ''} style={{ paddingLeft: '28px' }} min="0" step="any" />
    </div>
  )
}

function SelectInput({ value, onChange, options, placeholder, error }) {
  return (
    <select value={value} onChange={(e) => onChange(e.target.value)} className={error ? 'error' : ''}>
      <option value="" disabled>{placeholder || 'Select…'}</option>
      {options.map((opt) => <option key={opt} value={opt}>{opt}</option>)}
    </select>
  )
}

function TextArea({ value, onChange, placeholder, error, rows = 3 }) {
  return (
    <textarea value={value} onChange={(e) => onChange(e.target.value)}
      placeholder={placeholder} rows={rows} className={error ? 'error' : ''} />
  )
}

function UrgencyToggle({ value, onChange }) {
  return (
    <div className="flex">
      <button type="button" className={`toggle-btn${value === 'normal' ? ' active' : ''}`} onClick={() => onChange('normal')}>Normal</button>
      <button type="button" className={`toggle-btn${value === 'urgent' ? ' active' : ''}`} onClick={() => onChange('urgent')}>🔴 Urgent</button>
    </div>
  )
}

function SubmitButton({ loading, children }) {
  return (
    <button type="submit" disabled={loading}
      className="w-full flex items-center justify-center gap-2 rounded-lg font-semibold text-white transition-all"
      style={{ background: loading ? '#4f52d9' : '#6366f1', minHeight: '52px', fontSize: '15px', border: 'none', cursor: loading ? 'not-allowed' : 'pointer', opacity: loading ? 0.85 : 1 }}>
      {loading ? (<><span className="spinner" /><span>Submitting…</span></>) : children}
    </button>
  )
}

function BackButton({ onClick }) {
  return (
    <button type="button" onClick={onClick}
      className="flex items-center gap-1.5 text-sm transition-colors"
      style={{ color: '#888', background: 'none', border: 'none', cursor: 'pointer', padding: '0' }}>
      <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
        <path d="M9 2L4 7l5 5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
      Back
    </button>
  )
}

function StatusBadge({ status }) {
  const cfg = STATUS_CONFIG[status] || { label: status, color: '#6b7280', bg: '#111' }
  return (
    <span className="inline-flex items-center px-2.5 py-1 rounded-md text-xs font-medium"
      style={{ color: cfg.color, background: cfg.bg, border: `1px solid ${cfg.color}30` }}>
      {cfg.label}
    </span>
  )
}

function ComplianceBadge({ status }) {
  const cfg = COMPLIANCE_CONFIG[status] || { label: status, color: '#6b7280' }
  return (
    <span className="inline-flex items-center gap-1.5 text-xs font-medium" style={{ color: cfg.color }}>
      <span style={{ width: 6, height: 6, borderRadius: '50%', background: cfg.color, display: 'inline-block' }} />
      {cfg.label}
    </span>
  )
}

// ─── Operations Board ─────────────────────────────────────────────────────────

function TicketCard({ ticket, onAction, actionLoading }) {
  const [expanded, setExpanded] = useState(false)

  return (
    <div style={{ background: '#111', border: '1px solid #1e1e1e', borderRadius: 12, overflow: 'hidden', marginBottom: 12 }}>
      {/* Header */}
      <div style={{ padding: '16px 20px' }}>
        <div className="flex items-start justify-between gap-3 mb-3">
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2 mb-1.5 flex-wrap">
              <StatusBadge status={ticket.status} />
              {ticket.supplier_compliance && (
                <ComplianceBadge status={ticket.supplier_compliance} />
              )}
            </div>
            <h3 className="text-white font-semibold text-[15px] leading-snug">{ticket.title}</h3>
          </div>
          {ticket.value_eur && (
            <div className="text-right flex-shrink-0">
              <div className="text-white font-bold text-lg">{formatEuro(ticket.value_eur)}</div>
            </div>
          )}
        </div>

        <div className="flex items-center gap-4 text-xs flex-wrap" style={{ color: '#555' }}>
          {ticket.supplier_name && <span>🏢 {ticket.supplier_name}</span>}
          {ticket.branch_name   && <span>📍 {ticket.branch_name}</span>}
          {ticket.reference     && <span className="font-mono">{ticket.reference}</span>}
          {ticket.po_number     && <span className="font-mono" style={{ color: '#6366f1' }}>📄 {ticket.po_number}</span>}
          <span>{timeAgo(ticket.created_at)}</span>
        </div>

        {ticket.review_notes && (
          <div className="mt-3 text-xs p-3 rounded-lg" style={{ background: '#0d0d0d', color: '#888', border: '1px solid #1a1a1a' }}>
            {ticket.review_notes}
          </div>
        )}
      </div>

      {/* Expanded detail */}
      {expanded && (
        <div style={{ borderTop: '1px solid #1a1a1a', padding: '16px 20px', background: '#0d0d0d' }}>
          {ticket.recommendation && (
            <div className="mb-3">
              <div className="text-xs font-medium uppercase tracking-wider mb-1" style={{ color: '#444' }}>Agent Recommendation</div>
              <p className="text-sm" style={{ color: '#aaa' }}>{ticket.recommendation}</p>
            </div>
          )}
          {ticket.brief && (
            <div className="mb-3">
              <div className="text-xs font-medium uppercase tracking-wider mb-1" style={{ color: '#444' }}>Brief</div>
              <p className="text-sm" style={{ color: '#888', whiteSpace: 'pre-wrap' }}>{ticket.brief}</p>
            </div>
          )}
          {ticket.confidence && (
            <div className="text-xs" style={{ color: '#555' }}>
              Agent confidence: {Math.round(parseFloat(ticket.confidence) * 100)}%
            </div>
          )}
        </div>
      )}

      {/* Actions */}
      <div style={{ padding: '12px 20px', borderTop: '1px solid #1a1a1a', display: 'flex', gap: 8, alignItems: 'center' }}>
        {/* Primary actions based on status */}
        {(ticket.status === 'pending_review' || ticket.status === 'pending_confirm') && (
          <>
            <ActionButton
              onClick={() => onAction(ticket.id, 'approve')}
              loading={actionLoading === `${ticket.id}-approve`}
              variant="primary"
            >✅ Approve</ActionButton>
            <ActionButton
              onClick={() => onAction(ticket.id, 'reject')}
              loading={actionLoading === `${ticket.id}-reject`}
              variant="danger"
            >❌ Reject</ActionButton>
          </>
        )}
        {ticket.status === 'signature_required' && (
          <>
            <ActionButton
              onClick={() => onAction(ticket.id, 'sign')}
              loading={actionLoading === `${ticket.id}-sign`}
              variant="primary"
            >✍️ Sign & Send</ActionButton>
            <ActionButton
              onClick={() => onAction(ticket.id, 'reject')}
              loading={actionLoading === `${ticket.id}-reject`}
              variant="danger"
            >❌ Decline</ActionButton>
          </>
        )}
        {ticket.status === 'escalated' && (
          <ActionButton
            onClick={() => onAction(ticket.id, 'acknowledge')}
            loading={actionLoading === `${ticket.id}-acknowledge`}
            variant="secondary"
          >👁 Acknowledge</ActionButton>
        )}
        {ticket.status === 'approved' && ticket.po_id && (
          <ActionButton
            onClick={() => onAction(ticket.id, 'confirm_delivery', { po_id: ticket.po_id })}
            loading={actionLoading === `${ticket.id}-confirm_delivery`}
            variant="primary"
          >📦 Confirm Delivery</ActionButton>
        )}
        {ticket.pdf_url && (
          <a href={ticket.pdf_url} target="_blank" rel="noopener noreferrer"
            className="text-xs px-3 py-1.5 rounded-md"
            style={{ color: '#6366f1', background: '#0d0d1a', border: '1px solid #1a1a2e', textDecoration: 'none' }}>
            📄 View PDF
          </a>
        )}
        <button type="button" onClick={() => setExpanded(!expanded)}
          className="ml-auto text-xs"
          style={{ color: '#444', background: 'none', border: 'none', cursor: 'pointer' }}>
          {expanded ? 'Hide detail ↑' : 'Show detail ↓'}
        </button>
      </div>
    </div>
  )
}

function ActionButton({ onClick, loading, variant, children }) {
  const styles = {
    primary:   { background: '#16a34a22', color: '#22c55e', border: '1px solid #16a34a44' },
    danger:    { background: '#dc262622', color: '#ef4444', border: '1px solid #dc262644' },
    secondary: { background: '#1e1e1e',   color: '#888',    border: '1px solid #2a2a2a' },
  }
  const s = styles[variant] || styles.secondary
  return (
    <button type="button" onClick={onClick} disabled={loading}
      className="flex items-center gap-1.5 px-3 py-1.5 rounded-md text-xs font-medium transition-opacity"
      style={{ ...s, cursor: loading ? 'not-allowed' : 'pointer', opacity: loading ? 0.6 : 1, border: s.border }}>
      {loading ? <span className="spinner" style={{ width: 12, height: 12 }} /> : children}
    </button>
  )
}

function OperationsBoard() {
  const [tickets, setTickets]         = useState([])
  const [loading, setLoading]         = useState(true)
  const [error, setError]             = useState(null)
  const [actionLoading, setActionLoading] = useState(null)
  const [lastRefresh, setLastRefresh] = useState(null)

  const fetchTickets = useCallback(async () => {
    try {
      const data = await pgFetch('/open_tickets_board')
      setTickets(data || [])
      setLastRefresh(new Date())
      setError(null)
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchTickets()
    const interval = setInterval(fetchTickets, 30000) // refresh every 30s
    return () => clearInterval(interval)
  }, [fetchTickets])

  async function handleAction(ticketId, action, extra = {}) {
    setActionLoading(`${ticketId}-${action}`)
    try {
      if (action === 'confirm_delivery') {
        // Call confirm_delivery RPC — marks PO delivered, checks SLA, flags late
        await pgFetch('/rpc/confirm_delivery', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'Prefer': 'return=representation' },
          body: JSON.stringify({ p_po_id: extra.po_id, p_confirmed_by: 'ops_board' }),
        })
        // Also close the ticket
        await pgFetch(`/tickets?id=eq.${ticketId}`, {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json', 'Prefer': 'return=representation' },
          body: JSON.stringify({ status: 'closed', closed_at: new Date().toISOString() }),
        })
      } else {
        const statusMap = {
          approve:     'approved',
          reject:      'rejected',
          sign:        'closed',
          acknowledge: 'approved',
        }
        const newStatus = statusMap[action] || 'closed'
        await pgFetch(`/tickets?id=eq.${ticketId}`, {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json', 'Prefer': 'return=representation' },
          body: JSON.stringify({
            status: newStatus,
            ...(newStatus === 'closed' || newStatus === 'approved' ? { closed_at: new Date().toISOString() } : {}),
          }),
        })
      }
      await fetchTickets()
    } catch (err) {
      alert('Action failed: ' + err.message)
    } finally {
      setActionLoading(null)
    }
  }

  const signatureTickets  = tickets.filter(t => t.status === 'signature_required')
  const reviewTickets     = tickets.filter(t => t.status === 'pending_review')
  const escalatedTickets  = tickets.filter(t => t.status === 'escalated')
  const confirmTickets    = tickets.filter(t => t.status === 'pending_confirm')
  const deliveryTickets   = tickets.filter(t => t.status === 'approved' && t.po_id)

  return (
    <div style={{ minHeight: '100vh', background: '#0a0a0a', padding: '24px 16px' }}>
      <div style={{ maxWidth: 720, margin: '0 auto' }}>

        {/* Header */}
        <div className="flex items-center justify-between mb-8">
          <div>
            <div className="flex items-center gap-2 mb-1">
              <span className="font-bold text-xl tracking-tight" style={{ color: '#6366f1' }}>TrueSpend</span>
              <span className="text-xs px-2 py-0.5 rounded" style={{ background: '#1a1a2e', color: '#6366f1', border: '1px solid #2a2a4e' }}>Ops Board</span>
            </div>
            <p className="text-sm" style={{ color: '#555' }}>
              {tickets.length === 0 ? 'All clear — no open items.' : `${tickets.length} item${tickets.length !== 1 ? 's' : ''} need your attention`}
            </p>
          </div>
          <div className="text-right">
            <button type="button" onClick={fetchTickets}
              className="text-xs px-3 py-1.5 rounded-md"
              style={{ color: '#555', background: '#111', border: '1px solid #1e1e1e', cursor: 'pointer' }}>
              ↻ Refresh
            </button>
            {lastRefresh && (
              <div className="text-xs mt-1" style={{ color: '#333' }}>{timeAgo(lastRefresh)}</div>
            )}
          </div>
        </div>

        {/* Loading */}
        {loading && (
          <div className="flex items-center justify-center py-16">
            <span className="spinner" />
          </div>
        )}

        {/* Error */}
        {error && (
          <div className="rounded-lg px-4 py-3 mb-6 text-sm" style={{ background: '#1a0808', border: '1px solid #3f1010', color: '#f87171' }}>
            Failed to load tickets: {error}
          </div>
        )}

        {/* All clear */}
        {!loading && !error && tickets.length === 0 && (
          <div className="flex flex-col items-center py-20 text-center">
            <div className="text-5xl mb-4">✅</div>
            <h2 className="text-xl font-semibold text-white mb-2">Nothing needs you right now</h2>
            <p className="text-sm" style={{ color: '#555' }}>The agent is handling everything. Check back here when something major comes up.</p>
          </div>
        )}

        {/* Signature Required — highest priority */}
        {signatureTickets.length > 0 && (
          <section className="mb-8">
            <SectionHeader icon="✍️" title="Signature Required" count={signatureTickets.length} urgent />
            {signatureTickets.map(t => <TicketCard key={t.id} ticket={t} onAction={handleAction} actionLoading={actionLoading} />)}
          </section>
        )}

        {/* Pending Review — major contracts */}
        {reviewTickets.length > 0 && (
          <section className="mb-8">
            <SectionHeader icon="👁" title="Pending Your Review" count={reviewTickets.length} />
            {reviewTickets.map(t => <TicketCard key={t.id} ticket={t} onAction={handleAction} actionLoading={actionLoading} />)}
          </section>
        )}

        {/* Escalated */}
        {escalatedTickets.length > 0 && (
          <section className="mb-8">
            <SectionHeader icon="🚨" title="Escalated" count={escalatedTickets.length} />
            {escalatedTickets.map(t => <TicketCard key={t.id} ticket={t} onAction={handleAction} actionLoading={actionLoading} />)}
          </section>
        )}

        {/* One-touch confirm */}
        {confirmTickets.length > 0 && (
          <section className="mb-8">
            <SectionHeader icon="⚡" title="Quick Confirm" count={confirmTickets.length} />
            {confirmTickets.map(t => <TicketCard key={t.id} ticket={t} onAction={handleAction} actionLoading={actionLoading} />)}
          </section>
        )}

        {/* Awaiting delivery confirmation */}
        {deliveryTickets.length > 0 && (
          <section className="mb-8">
            <SectionHeader icon="📦" title="Awaiting Delivery" count={deliveryTickets.length} />
            <p className="text-xs mb-3" style={{ color: '#555' }}>PO sent. Confirm once goods or services have been received — this triggers invoice matching.</p>
            {deliveryTickets.map(t => <TicketCard key={t.id} ticket={t} onAction={handleAction} actionLoading={actionLoading} />)}
          </section>
        )}

        {/* Footer note */}
        {!loading && tickets.length > 0 && (
          <p className="text-center text-xs mt-8" style={{ color: '#2a2a2a' }}>
            Everything not shown here is handled automatically by the agent.
          </p>
        )}
      </div>
    </div>
  )
}

function SectionHeader({ icon, title, count, urgent }) {
  return (
    <div className="flex items-center gap-2 mb-3">
      <span>{icon}</span>
      <span className="text-sm font-semibold" style={{ color: urgent ? '#ef4444' : '#888' }}>{title}</span>
      <span className="text-xs px-1.5 py-0.5 rounded-full font-mono"
        style={{ background: urgent ? '#1a0808' : '#1a1a1a', color: urgent ? '#ef4444' : '#555' }}>
        {count}
      </span>
    </div>
  )
}

// ─── Intake Form ──────────────────────────────────────────────────────────────

function RequesterFields({ values, errors, onChange }) {
  return (
    <>
      <div className="mt-2 mb-4" style={{ borderTop: '1px solid #1e1e1e', paddingTop: '20px' }}>
        <p className="text-xs font-medium uppercase tracking-wider mb-4" style={{ color: '#555' }}>About you</p>
      </div>
      <Field label="Your name" required error={errors.submitted_by}>
        <TextInput value={values.submitted_by} onChange={(v) => onChange('submitted_by', v)} placeholder="Jane Smith" error={errors.submitted_by} autoComplete="name" />
      </Field>
      <Field label="Your email" required error={errors.submitted_by_email}>
        <TextInput type="email" value={values.submitted_by_email} onChange={(v) => onChange('submitted_by_email', v)} placeholder="jane@company.com" error={errors.submitted_by_email} autoComplete="email" />
      </Field>
      <Field label="Branch" required error={errors.branch_id}>
        <select value={values.branch_id} onChange={(e) => onChange('branch_id', e.target.value)} className={errors.branch_id ? 'error' : ''}>
          <option value="" disabled>Select your region</option>
          {BRANCHES.map((b) => <option key={b.id} value={b.id}>{b.label}</option>)}
        </select>
      </Field>
    </>
  )
}

function FormRenew({ values, errors, onChange, onSubmit, onBack, loading }) {
  return (
    <form onSubmit={onSubmit} noValidate>
      <div className="flex items-center gap-3 mb-6">
        <BackButton onClick={onBack} />
        <div className="flex items-center gap-2"><span className="text-lg">🔄</span><h2 className="text-lg font-semibold text-white">Renew a contract</h2></div>
      </div>
      <Field label="Supplier name" required error={errors.supplier_name}>
        <TextInput value={values.supplier_name} onChange={(v) => onChange('supplier_name', v)} placeholder="Acme Corp" error={errors.supplier_name} autoComplete="off" />
      </Field>
      <Field label="Contract value" required error={errors.amount}>
        <EuroInput value={values.amount} onChange={(v) => onChange('amount', v)} error={errors.amount} />
      </Field>
      <Field label="Anything we should know?" error={errors.notes}>
        <TextArea value={values.notes} onChange={(v) => onChange('notes', v)} placeholder="Optional — expiry dates, key terms, changes requested…" error={errors.notes} />
      </Field>
      <RequesterFields values={values} errors={errors} onChange={onChange} />
      <SubmitButton loading={loading}>Submit request</SubmitButton>
    </form>
  )
}

function FormPurchase({ values, errors, onChange, onSubmit, onBack, loading }) {
  return (
    <form onSubmit={onSubmit} noValidate>
      <div className="flex items-center gap-3 mb-6">
        <BackButton onClick={onBack} />
        <div className="flex items-center gap-2"><span className="text-lg">📦</span><h2 className="text-lg font-semibold text-white">Approve a purchase</h2></div>
      </div>
      <Field label="Supplier" required error={errors.supplier_name}>
        <TextInput value={values.supplier_name} onChange={(v) => onChange('supplier_name', v)} placeholder="Supplier name" error={errors.supplier_name} autoComplete="off" />
      </Field>
      <Field label="Amount" required error={errors.amount}>
        <EuroInput value={values.amount} onChange={(v) => onChange('amount', v)} error={errors.amount} />
      </Field>
      <Field label="What's it for?" required error={errors.description}>
        <TextInput value={values.description} onChange={(v) => onChange('description', v)} placeholder="Brief description of the purchase" error={errors.description} />
      </Field>
      <Field label="Urgency" error={errors.urgency}>
        <UrgencyToggle value={values.urgency || 'normal'} onChange={(v) => onChange('urgency', v)} />
      </Field>
      <RequesterFields values={values} errors={errors} onChange={onChange} />
      <SubmitButton loading={loading}>Submit request</SubmitButton>
    </form>
  )
}

function FormOnboard({ values, errors, onChange, onSubmit, onBack, loading }) {
  return (
    <form onSubmit={onSubmit} noValidate>
      <div className="flex items-center gap-3 mb-6">
        <BackButton onClick={onBack} />
        <div className="flex items-center gap-2"><span className="text-lg">🏢</span><h2 className="text-lg font-semibold text-white">Onboard a supplier</h2></div>
      </div>
      <Field label="Company name" required error={errors.supplier_name}>
        <TextInput value={values.supplier_name} onChange={(v) => onChange('supplier_name', v)} placeholder="New Vendor Ltd" error={errors.supplier_name} autoComplete="off" />
      </Field>
      <Field label="Country" required error={errors.country}>
        <TextInput value={values.country} onChange={(v) => onChange('country', v)} placeholder="e.g. Germany" error={errors.country} />
      </Field>
      <Field label="Category" required error={errors.category}>
        <SelectInput value={values.category} onChange={(v) => onChange('category', v)} options={SUPPLIER_CATEGORIES} placeholder="Select category" error={errors.category} />
      </Field>
      <Field label="Why do we need them?" required error={errors.description}>
        <TextInput value={values.description} onChange={(v) => onChange('description', v)} placeholder="Brief business justification" error={errors.description} />
      </Field>
      <RequesterFields values={values} errors={errors} onChange={onChange} />
      <SubmitButton loading={loading}>Submit request</SubmitButton>
    </form>
  )
}

function FormOther({ values, errors, onChange, onSubmit, onBack, loading }) {
  return (
    <form onSubmit={onSubmit} noValidate>
      <div className="flex items-center gap-3 mb-6">
        <BackButton onClick={onBack} />
        <div className="flex items-center gap-2"><span className="text-lg">⚡</span><h2 className="text-lg font-semibold text-white">Something else</h2></div>
      </div>
      <Field label="Title" required error={errors.title}>
        <TextInput value={values.title} onChange={(v) => onChange('title', v)} placeholder="Short summary of your request" error={errors.title} />
      </Field>
      <Field label="Description" required error={errors.description}>
        <TextArea value={values.description} onChange={(v) => onChange('description', v)} placeholder="Tell us what you need and why" error={errors.description} rows={4} />
      </Field>
      <Field label="Amount (if applicable)" error={errors.amount}>
        <EuroInput value={values.amount} onChange={(v) => onChange('amount', v)} placeholder="Optional" error={errors.amount} />
      </Field>
      <RequesterFields values={values} errors={errors} onChange={onChange} />
      <SubmitButton loading={loading}>Submit request</SubmitButton>
    </form>
  )
}

function StepSelectType({ onSelect }) {
  return (
    <StepWrapper>
      <div className="mb-8 text-center">
        <div className="inline-flex items-center gap-2 mb-6">
          <span className="text-xl font-bold tracking-tight" style={{ color: '#6366f1' }}>TrueSpend</span>
        </div>
        <h1 className="text-2xl font-semibold text-white mb-2">What do you need?</h1>
        <p className="text-sm" style={{ color: '#888' }}>Pick the request type and we'll handle the rest.</p>
      </div>
      <div className="grid gap-3">
        {TICKET_TYPES.map((t) => (
          <button key={t.id} type="button" onClick={() => onSelect(t.id)}
            className="w-full text-left rounded-xl border transition-all"
            style={{ background: '#141414', borderColor: '#2a2a2a', padding: '18px 20px', cursor: 'pointer', minHeight: '72px' }}
            onMouseEnter={(e) => { e.currentTarget.style.borderColor = '#6366f1'; e.currentTarget.style.background = '#18181f' }}
            onMouseLeave={(e) => { e.currentTarget.style.borderColor = '#2a2a2a'; e.currentTarget.style.background = '#141414' }}>
            <div className="flex items-center gap-4">
              <span className="text-2xl leading-none flex-shrink-0">{t.icon}</span>
              <div>
                <div className="font-semibold text-white text-[15px]">{t.label}</div>
                <div className="text-xs mt-0.5" style={{ color: '#666' }}>{t.hint}</div>
              </div>
              <svg className="ml-auto flex-shrink-0" width="16" height="16" viewBox="0 0 16 16" fill="none" style={{ color: '#444' }}>
                <path d="M6 3l5 5-5 5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
            </div>
          </button>
        ))}
      </div>
    </StepWrapper>
  )
}

function StepDone({ reference, email }) {
  return (
    <StepWrapper>
      <div className="flex flex-col items-center text-center py-8">
        <div className="mb-8">
          <svg width="88" height="88" viewBox="0 0 88 88" fill="none">
            <circle className="check-circle" cx="44" cy="44" r="40" fill="#16a34a" fillOpacity="0.15" stroke="#22c55e" strokeWidth="2" />
            <path className="check-mark" d="M27 45l12 12 22-22" stroke="#22c55e" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        </div>
        <h1 className="text-3xl font-bold text-white mb-3">Submitted</h1>
        {reference && (
          <div className="inline-flex items-center gap-2 rounded-lg px-4 py-2 mb-6" style={{ background: '#141414', border: '1px solid #2a2a2a' }}>
            <span className="text-xs font-medium uppercase tracking-wider" style={{ color: '#888' }}>Reference</span>
            <span className="font-mono font-semibold text-white text-sm">{reference}</span>
          </div>
        )}
        <p className="text-base mb-3" style={{ color: '#aaa', maxWidth: '320px' }}>
          The agent is reviewing this. You'll hear back at <span className="text-white font-medium">{email}</span>.
        </p>
        <p className="text-sm" style={{ color: '#555' }}>You can close this tab.</p>
      </div>
    </StepWrapper>
  )
}

// ─── Validation ──────────────────────────────────────────────────────────────

const sharedRules = {
  submitted_by:       (v) => required(v) ? null : 'Your name is required',
  submitted_by_email: (v) => { if (!required(v)) return 'Your email is required'; if (!validEmail(v)) return 'Enter a valid email address'; return null },
  branch_id:          (v) => required(v) ? null : 'Please select your branch',
}

const typeRules = {
  renew:    { supplier_name: (v) => required(v) ? null : 'Supplier name is required', amount: (v) => required(v) ? null : 'Contract value is required' },
  purchase: { supplier_name: (v) => required(v) ? null : 'Supplier is required', amount: (v) => required(v) ? null : 'Amount is required', description: (v) => required(v) ? null : 'Please describe what this is for' },
  onboard:  { supplier_name: (v) => required(v) ? null : 'Company name is required', country: (v) => required(v) ? null : 'Country is required', category: (v) => required(v) ? null : 'Please select a category', description: (v) => required(v) ? null : 'Business justification is required' },
  other:    { title: (v) => required(v) ? null : 'Title is required', description: (v) => required(v) ? null : 'Description is required' },
}

function validate(ticketType, values) {
  const rules = { ...typeRules[ticketType], ...sharedRules }
  const errors = {}
  let hasError = false
  for (const [field, rule] of Object.entries(rules)) {
    const msg = rule(values[field] || '')
    if (msg) { errors[field] = msg; hasError = true }
  }
  return { errors, hasError }
}

function buildPayload(ticketType, values) {
  const type = TICKET_TYPES.find((t) => t.id === ticketType)
  const title = ticketType === 'other' ? values.title
    : ticketType === 'renew'    ? `Renew contract — ${values.supplier_name}`
    : ticketType === 'purchase' ? `Purchase approval — ${values.supplier_name}`
    : `Onboard supplier — ${values.supplier_name}`
  return {
    ticket_type: ticketType, ticket_type_label: type?.label || ticketType,
    title, description: values.description || null, supplier_name: values.supplier_name || null,
    amount: values.amount ? parseFloat(values.amount) : null, currency: 'EUR',
    country: values.country || null, category: values.category || null,
    notes: values.notes || null, urgency: values.urgency || 'normal',
    submitted_by: values.submitted_by, submitted_by_email: values.submitted_by_email,
    branch_id: values.branch_id, submitted_at: new Date().toISOString(),
  }
}

function IntakeForm() {
  const [step, setStep]               = useState('select')
  const [ticketType, setTicketType]   = useState(null)
  const [values, setValues]           = useState({})
  const [errors, setErrors]           = useState({})
  const [loading, setLoading]         = useState(false)
  const [submitError, setSubmitError] = useState(null)
  const [reference, setReference]     = useState(null)

  function handleSelectType(type) {
    setTicketType(type); setValues({ urgency: 'normal' }); setErrors({}); setSubmitError(null); setStep('form')
  }
  function handleChange(field, val) {
    setValues((prev) => ({ ...prev, [field]: val }))
    if (errors[field]) setErrors((prev) => ({ ...prev, [field]: null }))
  }
  function handleBack() { setStep('select'); setTicketType(null); setErrors({}); setSubmitError(null) }

  async function handleSubmit(e) {
    e.preventDefault()
    const { errors: validationErrors, hasError } = validate(ticketType, values)
    if (hasError) { setErrors(validationErrors); return }
    setLoading(true); setSubmitError(null)
    try {
      const res = await fetch('/api/intake', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(buildPayload(ticketType, values)),
      })
      if (!res.ok) { const text = await res.text().catch(() => ''); throw new Error(text || `Server error ${res.status}`) }
      let data = {}
      try { data = await res.json() } catch {}
      setReference(data?.reference || data?.ticket_id || data?.id || null)
      setStep('done')
    } catch (err) {
      setSubmitError(err.message?.includes('Failed to fetch')
        ? 'Could not reach the server. Check your connection and try again.'
        : err.message || 'Something went wrong. Please try again.')
    } finally { setLoading(false) }
  }

  const formProps = { values, errors, onChange: handleChange, onSubmit: handleSubmit, onBack: handleBack, loading }

  return (
    <div className="min-h-screen flex flex-col items-center justify-center px-4 py-12" style={{ background: '#0a0a0a' }}>
      <div className="w-full" style={{ maxWidth: '440px' }}>
        {step === 'select' && <StepSelectType onSelect={handleSelectType} />}
        {step === 'form' && ticketType && (
          <StepWrapper>
            {ticketType === 'renew'    && <FormRenew    {...formProps} />}
            {ticketType === 'purchase' && <FormPurchase {...formProps} />}
            {ticketType === 'onboard'  && <FormOnboard  {...formProps} />}
            {ticketType === 'other'    && <FormOther    {...formProps} />}
            {submitError && (
              <div className="mt-4 rounded-lg px-4 py-3 text-sm" style={{ background: '#1a0808', border: '1px solid #3f1010', color: '#f87171' }}>{submitError}</div>
            )}
          </StepWrapper>
        )}
        {step === 'done' && <StepDone reference={reference} email={values.submitted_by_email} />}
        {step === 'select' && <p className="text-center text-xs mt-8" style={{ color: '#333' }}>Powered by TrueSpend · Procurement OS</p>}
      </div>
    </div>
  )
}

// ─── Main App — Tab Navigation ────────────────────────────────────────────────

export default function App() {
  const [tab, setTab] = useState(() => {
    return window.location.hash === '#board' ? 'board' : 'intake'
  })

  function switchTab(t) {
    setTab(t)
    window.location.hash = t === 'board' ? '#board' : ''
  }

  return (
    <div style={{ background: '#0a0a0a', minHeight: '100vh' }}>
      {/* Tab bar */}
      <div style={{ borderBottom: '1px solid #1a1a1a', background: '#0a0a0a', position: 'sticky', top: 0, zIndex: 10 }}>
        <div style={{ maxWidth: 720, margin: '0 auto', padding: '0 16px', display: 'flex', gap: 0 }}>
          <TabButton active={tab === 'intake'} onClick={() => switchTab('intake')}>
            📝 Submit Request
          </TabButton>
          <TabButton active={tab === 'board'} onClick={() => switchTab('board')}>
            📋 Operations Board
          </TabButton>
        </div>
      </div>

      {/* Content */}
      {tab === 'intake' && <IntakeForm />}
      {tab === 'board'  && <OperationsBoard />}
    </div>
  )
}

function TabButton({ active, onClick, children }) {
  return (
    <button type="button" onClick={onClick}
      className="px-4 py-3 text-sm font-medium transition-colors"
      style={{
        background: 'none', border: 'none', cursor: 'pointer',
        color: active ? '#6366f1' : '#444',
        borderBottom: active ? '2px solid #6366f1' : '2px solid transparent',
        marginBottom: '-1px',
      }}>
      {children}
    </button>
  )
}
