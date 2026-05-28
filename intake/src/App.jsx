import { useState, useEffect, useRef, useCallback } from 'react'

// ─── Config ───────────────────────────────────────────────────────────────────

const POSTGREST_URL = import.meta.env.VITE_POSTGREST_URL || 'https://postgrest-production-7960.up.railway.app'
const POSTGREST_JWT = import.meta.env.VITE_POSTGREST_JWT || ''
const N8N_WEBHOOK   = import.meta.env.VITE_N8N_WEBHOOK_URL || '/api/intake'

// ─── Constants ───────────────────────────────────────────────────────────────

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

// Catalog — pre-negotiated items. catalog_item:true triggers fast path (budget check only)
const CATALOG = [
  {
    category: 'Hardware',
    icon: '💻',
    items: [
      { id: 'mac-pro-14', name: 'MacBook Pro 14"', supplier: 'Apple', price: 2199, description: 'M3 Pro, 18 GB RAM, 512 GB SSD — standard dev config', sku: 'APPMBP14M3PRO' },
      { id: 'mac-pro-16', name: 'MacBook Pro 16"', supplier: 'Apple', price: 2999, description: 'M3 Max, 36 GB RAM, 1 TB SSD — power user config', sku: 'APPMBP16M3MAX' },
      { id: 'dell-u27',   name: 'Dell UltraSharp 27"', supplier: 'Dell', price: 549, description: '4K USB-C monitor, 90W PD — standard desk monitor', sku: 'DELLU2723QE' },
      { id: 'dock-uc',    name: 'CalDigit TS4 Dock', supplier: 'CalDigit', price: 299, description: 'Thunderbolt 4 dock, 18 ports — standard docking station', sku: 'CDTS4' },
      { id: 'iphone-15',  name: 'iPhone 15 Pro', supplier: 'Apple', price: 1199, description: '256 GB, standard corporate mobile', sku: 'APPIPH15P256' },
    ],
  },
  {
    category: 'Software & Licenses',
    icon: '📱',
    items: [
      { id: 'ms365-e3',   name: 'Microsoft 365 E3', supplier: 'Microsoft', price: 36, description: 'Per user / month — Teams, Outlook, Office, SharePoint', sku: 'MS365E3' },
      { id: 'github-ent', name: 'GitHub Enterprise', supplier: 'GitHub', price: 21, description: 'Per user / month — Advanced Security + GHAS', sku: 'GHENT' },
      { id: 'figma-org',  name: 'Figma Organization', supplier: 'Figma', price: 45, description: 'Per editor / month — unlimited projects', sku: 'FIGMAORG' },
      { id: 'slack-pro',  name: 'Slack Pro', supplier: 'Salesforce', price: 8, description: 'Per user / month — standard workspace', sku: 'SLKPRO' },
      { id: 'notion-plus',name: 'Notion Plus', supplier: 'Notion', price: 16, description: 'Per user / month — unlimited pages + AI', sku: 'NOTIONPLUS' },
      { id: '1pw-teams',  name: '1Password Teams', supplier: '1Password', price: 4, description: 'Per user / month — password management', sku: '1PWTEAMS' },
    ],
  },
  {
    category: 'Cloud',
    icon: '☁️',
    items: [
      { id: 'aws-reserved', name: 'AWS Reserved Instance', supplier: 'Amazon Web Services', price: 0, description: 'Variable — submit for budget allocation. Agent reviews utilization first.', sku: 'AWS-RI', variable: true },
      { id: 'gcp-commit',   name: 'GCP Committed Use', supplier: 'Google Cloud', price: 0, description: 'Variable — commit discount contract. Agent checks prior spend.', sku: 'GCP-CUD', variable: true },
      { id: 'az-reserved',  name: 'Azure Reserved VM', supplier: 'Microsoft Azure', price: 0, description: 'Variable — 1 or 3 year reservation. Specify instance type in notes.', sku: 'AZ-RES', variable: true },
    ],
  },
  {
    category: 'Services',
    icon: '🔧',
    items: [
      { id: 'soc2-audit', name: 'SOC 2 Type II Audit', supplier: 'Deloitte', price: 35000, description: 'Annual audit — fixed price per framework agreement', sku: 'SOC2T2' },
      { id: 'pen-test',   name: 'Penetration Test', supplier: 'NCC Group', price: 18000, description: 'Annual web + infra pentest — standard scope', sku: 'PENTESTANN' },
      { id: 'legal-nda',  name: 'NDA Review', supplier: 'Bird & Bird', price: 950, description: 'Per NDA, standard review — 48h turnaround', sku: 'LGNDA48' },
    ],
  },
]

const STATUS_CONFIG = {
  signature_required: { label: 'Signature Required', color: '#ef4444', bg: '#1a0808' },
  pending_review:     { label: 'Pending Review',      color: '#f59e0b', bg: '#1a1200' },
  escalated:          { label: 'Escalated',           color: '#a855f7', bg: '#120a1a' },
  pending_confirm:    { label: 'Quick Confirm',        color: '#6366f1', bg: '#0d0d1a' },
  approved:           { label: 'Approved',             color: '#22c55e', bg: '#081a0d' },
  rejected:           { label: 'Rejected',             color: '#6b7280', bg: '#111111' },
  closed:             { label: 'Done',                 color: '#6b7280', bg: '#111111' },
  auto_executed:      { label: 'Auto-approved',        color: '#22c55e', bg: '#081a0d' },
}

const COMPLIANCE_CONFIG = {
  green:   { label: 'Compliant', color: '#22c55e' },
  amber:   { label: 'Gaps',      color: '#f59e0b' },
  red:     { label: 'Blocked',   color: '#ef4444' },
  pending: { label: 'Pending',   color: '#6b7280' },
  running: { label: 'Running…',  color: '#6366f1' },
}

const NAV_ITEMS = [
  { id: 'home',    label: 'Home',      icon: HomeIcon    },
  { id: 'catalog', label: 'Catalog',   icon: CatalogIcon },
  { id: 'mine',    label: 'My Orders', icon: ListIcon    },
  { id: 'board',   label: 'Ops Board', icon: BoardIcon   },
]

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

async function submitIntake(payload) {
  const res = await fetch(N8N_WEBHOOK, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  })
  if (!res.ok) {
    const text = await res.text().catch(() => '')
    throw new Error(text || `Server error ${res.status}`)
  }
  try { return await res.json() } catch { return {} }
}

function useLocalStorage(key, initial) {
  const [value, setValue] = useState(() => {
    try { const s = localStorage.getItem(key); return s ? JSON.parse(s) : initial } catch { return initial }
  })
  const set = useCallback((v) => {
    setValue(v)
    try { localStorage.setItem(key, JSON.stringify(v)) } catch {}
  }, [key])
  return [value, set]
}

// ─── Icons ────────────────────────────────────────────────────────────────────

function HomeIcon({ size = 20 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M3 9.5L10 3l7 6.5" /><path d="M5 8v8h4v-4h2v4h4V8" />
    </svg>
  )
}

function CatalogIcon({ size = 20 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <rect x="2" y="3" width="7" height="7" rx="1" /><rect x="11" y="3" width="7" height="7" rx="1" />
      <rect x="2" y="12" width="7" height="7" rx="1" /><rect x="11" y="12" width="7" height="7" rx="1" />
    </svg>
  )
}

function ListIcon({ size = 20 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M4 6h12M4 10h12M4 14h7" />
    </svg>
  )
}

function BoardIcon({ size = 20 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <rect x="2" y="3" width="16" height="14" rx="2" />
      <path d="M2 7h16" /><circle cx="6" cy="12" r="1.5" fill="currentColor" stroke="none" />
      <path d="M10 12h6" />
    </svg>
  )
}

function ChevronRight({ size = 16 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M6 3l5 5-5 5" />
    </svg>
  )
}

function ChevronBack({ size = 14 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M9 2L4 7l5 5" />
    </svg>
  )
}

// ─── Base UI components ───────────────────────────────────────────────────────

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

function Label({ children, req }) {
  return (
    <label className="block text-sm font-medium text-white mb-1.5">
      {children}{req && <span style={{ color: '#6366f1' }} className="ml-0.5">*</span>}
    </label>
  )
}

function Field({ label, error, req, children }) {
  return (
    <div className="mb-4">
      {label && <Label req={req}>{label}</Label>}
      {children}
      {error && <p className="mt-1.5 text-xs" style={{ color: '#f87171' }}>{error}</p>}
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
      <button type="button" className={`toggle-btn${value === 'urgent' ? ' active' : ''}`} onClick={() => onChange('urgent')}>Urgent</button>
    </div>
  )
}

function PrimaryButton({ loading, disabled, onClick, type = 'submit', children, fullWidth = true }) {
  return (
    <button type={type} disabled={loading || disabled} onClick={onClick}
      className={`${fullWidth ? 'w-full' : ''} flex items-center justify-center gap-2 rounded-xl font-semibold text-white transition-all`}
      style={{ background: loading || disabled ? '#4f52d9' : '#6366f1', minHeight: '52px', fontSize: '15px', border: 'none', cursor: loading || disabled ? 'not-allowed' : 'pointer', opacity: loading || disabled ? 0.75 : 1 }}>
      {loading ? (<><span className="spinner" /><span>Submitting…</span></>) : children}
    </button>
  )
}

function BackButton({ onClick }) {
  return (
    <button type="button" onClick={onClick}
      className="flex items-center gap-1.5 text-sm transition-colors"
      style={{ color: '#666', background: 'none', border: 'none', cursor: 'pointer', padding: '0' }}>
      <ChevronBack />Back
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

function ActionButton({ onClick, loading, variant, children }) {
  const styles = {
    primary:   { background: '#16a34a22', color: '#22c55e', border: '1px solid #16a34a44' },
    danger:    { background: '#dc262622', color: '#ef4444', border: '1px solid #dc262644' },
    secondary: { background: '#1e1e1e',   color: '#888',    border: '1px solid #2a2a2a'   },
  }
  const s = styles[variant] || styles.secondary
  return (
    <button type="button" onClick={onClick} disabled={loading}
      className="flex items-center gap-1.5 px-3 py-1.5 rounded-md text-xs font-medium transition-opacity"
      style={{ ...s, cursor: loading ? 'not-allowed' : 'pointer', opacity: loading ? 0.6 : 1 }}>
      {loading ? <span className="spinner" style={{ width: 12, height: 12 }} /> : children}
    </button>
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

// ─── User session (localStorage) ─────────────────────────────────────────────

function UserSetupModal({ onSave }) {
  const [name,  setName]   = useState('')
  const [email, setEmail]  = useState('')
  const [branch, setBranch] = useState('')
  const [errors, setErrors] = useState({})

  function save() {
    const e = {}
    if (!required(name))         e.name   = 'Required'
    if (!required(email) || !validEmail(email)) e.email  = 'Valid email required'
    if (!required(branch))       e.branch = 'Required'
    if (Object.keys(e).length) { setErrors(e); return }
    onSave({ name, email, branch_id: branch })
  }

  return (
    <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.85)', zIndex: 100, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '16px' }}>
      <div style={{ background: '#111', border: '1px solid #2a2a2a', borderRadius: 16, padding: '32px 24px', width: '100%', maxWidth: 400 }}>
        <div className="text-center mb-6">
          <div className="font-bold text-xl mb-1" style={{ color: '#6366f1' }}>TrueSpend</div>
          <h2 className="text-lg font-semibold text-white mb-1">Welcome</h2>
          <p className="text-sm" style={{ color: '#666' }}>Tell us who you are — we'll remember you on this device.</p>
        </div>
        <Field label="Your name" req error={errors.name}>
          <TextInput value={name} onChange={setName} placeholder="Jane Smith" error={errors.name} autoComplete="name" />
        </Field>
        <Field label="Work email" req error={errors.email}>
          <TextInput type="email" value={email} onChange={setEmail} placeholder="jane@company.com" error={errors.email} autoComplete="email" />
        </Field>
        <Field label="Region / Branch" req error={errors.branch}>
          <select value={branch} onChange={(e) => setBranch(e.target.value)} className={errors.branch ? 'error' : ''}>
            <option value="" disabled>Select your region</option>
            {BRANCHES.map((b) => <option key={b.id} value={b.id}>{b.label}</option>)}
          </select>
        </Field>
        <PrimaryButton type="button" onClick={save}>Get started</PrimaryButton>
      </div>
    </div>
  )
}

// ─── Home screen ─────────────────────────────────────────────────────────────

const QUICK_TILES = [
  { id: 'catalog',  label: 'Order from catalog',   sub: 'Pre-negotiated items, fast approval',  icon: '📦', nav: 'catalog'   },
  { id: 'purchase', label: 'Ad-hoc purchase',       sub: 'New supplier or one-off spend',        icon: '🛒', nav: 'request', type: 'purchase' },
  { id: 'renew',    label: 'Renew a contract',      sub: 'Extend or renegotiate an agreement',   icon: '🔄', nav: 'request', type: 'renew'    },
  { id: 'onboard',  label: 'Onboard a supplier',   sub: 'Bring a new vendor into the system',   icon: '🏢', nav: 'request', type: 'onboard'  },
  { id: 'other',    label: 'Something else',        sub: 'Any other procurement request',        icon: '⚡', nav: 'request', type: 'other'    },
]

function HomeScreen({ user, onNavigate, onRequestType }) {
  const branchLabel = BRANCHES.find(b => b.id === user.branch_id)?.label || 'Unknown'

  return (
    <div style={{ padding: '0 0 100px' }}>
      {/* Greeting */}
      <div style={{ padding: '28px 16px 20px' }}>
        <p className="text-sm mb-1" style={{ color: '#666' }}>Good day,</p>
        <h1 className="text-2xl font-bold text-white mb-0.5">{user.name}</h1>
        <p className="text-sm" style={{ color: '#555' }}>{branchLabel}</p>
      </div>

      {/* Fast-path catalog banner */}
      <div style={{ margin: '0 16px 20px', background: 'linear-gradient(135deg, #1a1a2e 0%, #16213e 100%)', border: '1px solid #2a2a4e', borderRadius: 14, padding: '20px' }}>
        <div className="flex items-center justify-between">
          <div>
            <div className="text-xs font-semibold uppercase tracking-wider mb-1" style={{ color: '#6366f1' }}>Pre-approved catalog</div>
            <div className="text-white font-semibold mb-1">Standard items, instant approval</div>
            <div className="text-xs" style={{ color: '#666' }}>Contract in place. Budget check only. No waiting.</div>
          </div>
          <button type="button" onClick={() => onNavigate('catalog')}
            style={{ background: '#6366f1', color: '#fff', border: 'none', borderRadius: 10, padding: '10px 16px', fontSize: 14, fontWeight: 600, cursor: 'pointer', whiteSpace: 'nowrap', flexShrink: 0, marginLeft: 12 }}>
            Browse
          </button>
        </div>
      </div>

      {/* Request tiles */}
      <div style={{ padding: '0 16px' }}>
        <p className="text-xs font-semibold uppercase tracking-wider mb-3" style={{ color: '#444' }}>What do you need?</p>
        <div className="grid gap-3">
          {QUICK_TILES.map((tile) => (
            <button key={tile.id} type="button"
              onClick={() => tile.nav === 'catalog' ? onNavigate('catalog') : onRequestType(tile.type)}
              style={{ background: '#111', border: '1px solid #1e1e1e', borderRadius: 12, padding: '16px', textAlign: 'left', cursor: 'pointer', transition: 'border-color 0.15s' }}
              onMouseEnter={(e) => e.currentTarget.style.borderColor = '#6366f133'}
              onMouseLeave={(e) => e.currentTarget.style.borderColor = '#1e1e1e'}>
              <div className="flex items-center gap-3">
                <span style={{ fontSize: 22, lineHeight: 1 }}>{tile.icon}</span>
                <div className="flex-1 min-w-0">
                  <div className="text-white font-semibold text-sm">{tile.label}</div>
                  <div className="text-xs mt-0.5" style={{ color: '#555' }}>{tile.sub}</div>
                </div>
                <ChevronRight />
              </div>
            </button>
          ))}
        </div>
      </div>
    </div>
  )
}

// ─── Catalog ─────────────────────────────────────────────────────────────────

function CatalogScreen({ user, onSuccess }) {
  const [activeCategory, setActiveCategory] = useState(CATALOG[0].category)
  const [ordering, setOrdering]   = useState(null) // item id being ordered
  const [modal, setModal]         = useState(null) // item to confirm
  const [qty, setQty]             = useState(1)
  const [notes, setNotes]         = useState('')
  const [amount, setAmount]       = useState('')
  const [loading, setLoading]     = useState(false)

  const cat = CATALOG.find(c => c.category === activeCategory)

  function openModal(item) {
    setModal(item)
    setQty(1)
    setNotes('')
    setAmount(item.variable ? '' : String(item.price))
  }

  async function placeOrder() {
    if (!modal) return
    setLoading(true)
    try {
      const unitPrice = modal.variable ? parseFloat(amount) || 0 : modal.price
      const total = unitPrice * qty
      const payload = {
        ticket_type: 'purchase',
        ticket_type_label: 'Catalog Order',
        catalog_item: true,
        catalog_sku: modal.sku,
        title: `${modal.name} × ${qty}`,
        description: `Catalog order: ${modal.name}. SKU: ${modal.sku}. ${notes}`.trim(),
        supplier_name: modal.supplier,
        amount: total,
        currency: 'EUR',
        urgency: 'normal',
        notes: notes || null,
        submitted_by: user.name,
        submitted_by_email: user.email,
        branch_id: user.branch_id,
        submitted_at: new Date().toISOString(),
      }
      const data = await submitIntake(payload)
      setModal(null)
      onSuccess({ reference: data?.reference || data?.ticket_id || data?.id || null, email: user.email, item: modal.name })
    } catch (err) {
      alert('Order failed: ' + err.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div style={{ paddingBottom: 100 }}>
      {/* Category tabs */}
      <div style={{ overflowX: 'auto', padding: '16px 16px 0', display: 'flex', gap: 8, borderBottom: '1px solid #1a1a1a' }}>
        {CATALOG.map(c => (
          <button key={c.category} type="button" onClick={() => setActiveCategory(c.category)}
            style={{ whiteSpace: 'nowrap', padding: '8px 14px', borderRadius: '8px 8px 0 0', fontSize: 13, fontWeight: 500, border: 'none', cursor: 'pointer', background: activeCategory === c.category ? '#6366f1' : 'transparent', color: activeCategory === c.category ? '#fff' : '#666', borderBottom: activeCategory === c.category ? 'none' : 'transparent', transition: 'all 0.15s' }}>
            {c.icon} {c.category}
          </button>
        ))}
      </div>

      {/* Item list */}
      <div style={{ padding: '16px' }}>
        <p className="text-xs mb-4" style={{ color: '#555' }}>Pre-negotiated pricing. Contract on file. Budget check only — no full review.</p>
        <div className="grid gap-3">
          {cat.items.map(item => (
            <div key={item.id} style={{ background: '#111', border: '1px solid #1e1e1e', borderRadius: 12, padding: '16px' }}>
              <div className="flex items-start justify-between gap-3">
                <div className="flex-1 min-w-0">
                  <div className="text-white font-semibold text-sm mb-0.5">{item.name}</div>
                  <div className="text-xs mb-2" style={{ color: '#555' }}>{item.description}</div>
                  <div className="flex items-center gap-3">
                    <span className="text-xs" style={{ color: '#444' }}>{item.supplier}</span>
                    <span className="text-xs font-mono" style={{ color: '#333' }}>{item.sku}</span>
                  </div>
                </div>
                <div className="text-right flex-shrink-0">
                  <div className="font-bold text-white mb-2">
                    {item.variable ? 'Variable' : formatEuro(item.price)}
                    {!item.variable && <span className="text-xs font-normal ml-1" style={{ color: '#555' }}>{item.price < 100 ? '/mo' : ''}</span>}
                  </div>
                  <button type="button" onClick={() => openModal(item)}
                    style={{ background: '#6366f115', color: '#6366f1', border: '1px solid #6366f133', borderRadius: 8, padding: '6px 14px', fontSize: 13, fontWeight: 600, cursor: 'pointer' }}>
                    Order
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Order modal */}
      {modal && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.85)', zIndex: 50, display: 'flex', alignItems: 'flex-end', justifyContent: 'center', padding: '0' }}>
          <div style={{ background: '#111', border: '1px solid #2a2a2a', borderRadius: '16px 16px 0 0', padding: '24px 20px 40px', width: '100%', maxWidth: 500 }}>
            <div className="flex items-center justify-between mb-5">
              <div>
                <div className="text-white font-bold">{modal.name}</div>
                <div className="text-xs" style={{ color: '#555' }}>{modal.supplier}</div>
              </div>
              <button type="button" onClick={() => setModal(null)}
                style={{ background: 'none', border: 'none', color: '#555', cursor: 'pointer', fontSize: 20, padding: 4 }}>
                ✕
              </button>
            </div>

            {modal.variable && (
              <Field label="Amount (€)" req>
                <EuroInput value={amount} onChange={setAmount} placeholder="Enter total amount" />
              </Field>
            )}

            <Field label="Quantity">
              <div className="flex items-center gap-3">
                <button type="button" onClick={() => setQty(q => Math.max(1, q - 1))}
                  style={{ background: '#1e1e1e', border: '1px solid #2a2a2a', color: '#fff', width: 40, height: 40, borderRadius: 8, fontSize: 18, cursor: 'pointer' }}>−</button>
                <span className="text-white font-bold text-lg" style={{ minWidth: 32, textAlign: 'center' }}>{qty}</span>
                <button type="button" onClick={() => setQty(q => q + 1)}
                  style={{ background: '#1e1e1e', border: '1px solid #2a2a2a', color: '#fff', width: 40, height: 40, borderRadius: 8, fontSize: 18, cursor: 'pointer' }}>+</button>
                {!modal.variable && (
                  <span className="ml-2 font-semibold text-white">{formatEuro(modal.price * qty)}</span>
                )}
              </div>
            </Field>

            <Field label="Notes (optional)">
              <TextArea value={notes} onChange={setNotes} placeholder="Any specific requirements, asset tag, etc." rows={2} />
            </Field>

            <div style={{ background: '#0d0d1a', border: '1px solid #1a1a2e', borderRadius: 10, padding: '12px 14px', marginBottom: 16 }}>
              <div className="text-xs" style={{ color: '#6366f1' }}>Fast-path order — budget check only. Auto-approved if budget available.</div>
            </div>

            <PrimaryButton type="button" onClick={placeOrder} loading={loading}>
              Place Order
            </PrimaryButton>
          </div>
        </div>
      )}
    </div>
  )
}

// ─── My Requests ─────────────────────────────────────────────────────────────

function MyRequestsScreen({ user }) {
  const [tickets, setTickets]   = useState([])
  const [loading, setLoading]   = useState(true)
  const [error, setError]       = useState(null)

  const fetchMyTickets = useCallback(async () => {
    setLoading(true)
    try {
      const enc = encodeURIComponent(user.email)
      const data = await pgFetch(`/tickets?submitted_by_email=eq.${enc}&order=created_at.desc&limit=50`)
      setTickets(data || [])
      setError(null)
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }, [user.email])

  useEffect(() => { fetchMyTickets() }, [fetchMyTickets])

  return (
    <div style={{ padding: '20px 16px 100px' }}>
      <div className="flex items-center justify-between mb-5">
        <h2 className="text-lg font-bold text-white">My Requests</h2>
        <button type="button" onClick={fetchMyTickets}
          style={{ background: '#111', border: '1px solid #1e1e1e', color: '#555', borderRadius: 8, padding: '6px 12px', fontSize: 12, cursor: 'pointer' }}>
          ↻ Refresh
        </button>
      </div>

      {loading && (
        <div className="flex justify-center py-12"><span className="spinner" /></div>
      )}
      {error && (
        <div className="rounded-xl px-4 py-3 mb-4 text-sm" style={{ background: '#1a0808', border: '1px solid #3f1010', color: '#f87171' }}>
          {error}
        </div>
      )}
      {!loading && !error && tickets.length === 0 && (
        <div className="flex flex-col items-center py-16 text-center">
          <div style={{ fontSize: 40, marginBottom: 12 }}>📋</div>
          <p className="text-sm" style={{ color: '#555' }}>No requests yet. Use the catalog or submit a request from Home.</p>
        </div>
      )}

      <div className="grid gap-3">
        {tickets.map(t => (
          <div key={t.id} style={{ background: '#111', border: '1px solid #1e1e1e', borderRadius: 12, padding: '16px' }}>
            <div className="flex items-start justify-between gap-2 mb-2">
              <div className="text-white text-sm font-semibold flex-1 min-w-0">{t.title}</div>
              <StatusBadge status={t.status} />
            </div>
            <div className="flex items-center gap-3 text-xs flex-wrap" style={{ color: '#555' }}>
              {t.value_eur && <span className="font-semibold" style={{ color: '#888' }}>{formatEuro(t.value_eur)}</span>}
              {t.supplier_name && <span>{t.supplier_name}</span>}
              {t.reference && <span className="font-mono">{t.reference}</span>}
              <span>{timeAgo(t.created_at)}</span>
            </div>
            {t.po_number && (
              <div className="mt-2 text-xs font-mono" style={{ color: '#6366f1' }}>PO: {t.po_number}</div>
            )}
            {t.review_notes && (
              <div className="mt-2 text-xs p-2 rounded-lg" style={{ background: '#0d0d0d', color: '#777', border: '1px solid #1a1a1a' }}>
                {t.review_notes}
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  )
}

// ─── Request form (ad-hoc, renew, onboard, other) ────────────────────────────

const FORM_CONFIG = {
  purchase: { icon: '🛒', title: 'Purchase Request',   hint: 'New supplier or one-off spend' },
  renew:    { icon: '🔄', title: 'Contract Renewal',   hint: 'Extend or renegotiate an agreement' },
  onboard:  { icon: '🏢', title: 'Supplier Onboarding', hint: 'Bring a new vendor into the system' },
  other:    { icon: '⚡', title: 'Other Request',       hint: 'Anything else' },
}

const SUPPLIER_CATEGORIES = ['Hardware', 'Cloud', 'SaaS', 'Services', 'Other']

function RequestForm({ user, requestType, onBack, onSuccess }) {
  const cfg = FORM_CONFIG[requestType] || FORM_CONFIG.other
  const [values, setValues] = useState({ urgency: 'normal' })
  const [errors, setErrors] = useState({})
  const [loading, setLoading] = useState(false)
  const [submitError, setSubmitError] = useState(null)

  function change(field, val) {
    setValues(prev => ({ ...prev, [field]: val }))
    if (errors[field]) setErrors(prev => ({ ...prev, [field]: null }))
  }

  const sharedRules = {
    submitted_by:       v => required(v) ? null : 'Your name is required',
    submitted_by_email: v => { if (!required(v)) return 'Email required'; if (!validEmail(v)) return 'Valid email required'; return null },
    branch_id:          v => required(v) ? null : 'Select your branch',
  }

  const typeRules = {
    purchase: { supplier_name: v => required(v) ? null : 'Supplier required', amount: v => required(v) ? null : 'Amount required', description: v => required(v) ? null : 'Description required' },
    renew:    { supplier_name: v => required(v) ? null : 'Supplier required', amount: v => required(v) ? null : 'Value required' },
    onboard:  { supplier_name: v => required(v) ? null : 'Company required', country: v => required(v) ? null : 'Country required', category: v => required(v) ? null : 'Category required', description: v => required(v) ? null : 'Justification required' },
    other:    { title: v => required(v) ? null : 'Title required', description: v => required(v) ? null : 'Description required' },
  }

  function validate() {
    const rules = { ...(typeRules[requestType] || {}), ...sharedRules }
    const errs = {}
    let hasError = false
    for (const [field, rule] of Object.entries(rules)) {
      const msg = rule(values[field] || '')
      if (msg) { errs[field] = msg; hasError = true }
    }
    return { errs, hasError }
  }

  async function handleSubmit(e) {
    e.preventDefault()
    const { errs, hasError } = validate()
    if (hasError) { setErrors(errs); return }
    setLoading(true); setSubmitError(null)
    try {
      const title = requestType === 'other'    ? values.title
        : requestType === 'renew'    ? `Renew — ${values.supplier_name}`
        : requestType === 'purchase' ? `Purchase — ${values.supplier_name}`
        : `Onboard — ${values.supplier_name}`
      const payload = {
        ticket_type: requestType,
        ticket_type_label: cfg.title,
        catalog_item: false,
        title,
        description: values.description || null,
        supplier_name: values.supplier_name || null,
        amount: values.amount ? parseFloat(values.amount) : null,
        currency: 'EUR',
        country: values.country || null,
        category: values.category || null,
        notes: values.notes || null,
        urgency: values.urgency || 'normal',
        submitted_by: user.name,
        submitted_by_email: user.email,
        branch_id: user.branch_id,
        submitted_at: new Date().toISOString(),
      }
      const data = await submitIntake(payload)
      onSuccess({ reference: data?.reference || data?.ticket_id || data?.id || null, email: user.email })
    } catch (err) {
      setSubmitError(err.message?.includes('Failed to fetch')
        ? 'Could not reach the server. Check your connection.'
        : err.message || 'Something went wrong. Try again.')
    } finally { setLoading(false) }
  }

  return (
    <div style={{ padding: '20px 16px 100px' }}>
      <div className="flex items-center gap-3 mb-6">
        <BackButton onClick={onBack} />
        <div className="flex items-center gap-2">
          <span style={{ fontSize: 20 }}>{cfg.icon}</span>
          <div>
            <div className="text-white font-semibold">{cfg.title}</div>
            <div className="text-xs" style={{ color: '#555' }}>{cfg.hint}</div>
          </div>
        </div>
      </div>

      <form onSubmit={handleSubmit} noValidate>
        {/* Purchase-specific */}
        {requestType === 'purchase' && (
          <>
            <Field label="Supplier" req error={errors.supplier_name}>
              <TextInput value={values.supplier_name || ''} onChange={v => change('supplier_name', v)} placeholder="Supplier or vendor name" error={errors.supplier_name} />
            </Field>
            <Field label="Amount" req error={errors.amount}>
              <EuroInput value={values.amount || ''} onChange={v => change('amount', v)} error={errors.amount} />
            </Field>
            <Field label="What's it for?" req error={errors.description}>
              <TextInput value={values.description || ''} onChange={v => change('description', v)} placeholder="Brief description" error={errors.description} />
            </Field>
            <Field label="Business justification" error={errors.notes}>
              <TextArea value={values.notes || ''} onChange={v => change('notes', v)} placeholder="Why is this needed? What does it replace or enable?" rows={3} />
            </Field>
            <Field label="Urgency">
              <UrgencyToggle value={values.urgency || 'normal'} onChange={v => change('urgency', v)} />
            </Field>
          </>
        )}

        {/* Renew-specific */}
        {requestType === 'renew' && (
          <>
            <Field label="Supplier name" req error={errors.supplier_name}>
              <TextInput value={values.supplier_name || ''} onChange={v => change('supplier_name', v)} placeholder="Acme Corp" error={errors.supplier_name} />
            </Field>
            <Field label="Contract value" req error={errors.amount}>
              <EuroInput value={values.amount || ''} onChange={v => change('amount', v)} error={errors.amount} />
            </Field>
            <Field label="Notes" error={errors.notes}>
              <TextArea value={values.notes || ''} onChange={v => change('notes', v)} placeholder="Expiry date, key terms, requested changes…" rows={3} />
            </Field>
          </>
        )}

        {/* Onboard-specific */}
        {requestType === 'onboard' && (
          <>
            <Field label="Company name" req error={errors.supplier_name}>
              <TextInput value={values.supplier_name || ''} onChange={v => change('supplier_name', v)} placeholder="New Vendor Ltd" error={errors.supplier_name} />
            </Field>
            <Field label="Country" req error={errors.country}>
              <TextInput value={values.country || ''} onChange={v => change('country', v)} placeholder="e.g. Germany" error={errors.country} />
            </Field>
            <Field label="Category" req error={errors.category}>
              <select value={values.category || ''} onChange={e => change('category', e.target.value)} className={errors.category ? 'error' : ''}>
                <option value="" disabled>Select category</option>
                {SUPPLIER_CATEGORIES.map(c => <option key={c} value={c}>{c}</option>)}
              </select>
            </Field>
            <Field label="Business justification" req error={errors.description}>
              <TextArea value={values.description || ''} onChange={v => change('description', v)} placeholder="Why do we need this vendor?" rows={3} />
            </Field>
          </>
        )}

        {/* Other */}
        {requestType === 'other' && (
          <>
            <Field label="Title" req error={errors.title}>
              <TextInput value={values.title || ''} onChange={v => change('title', v)} placeholder="Short summary" error={errors.title} />
            </Field>
            <Field label="Description" req error={errors.description}>
              <TextArea value={values.description || ''} onChange={v => change('description', v)} placeholder="What do you need and why?" rows={4} />
            </Field>
            <Field label="Amount (if applicable)" error={errors.amount}>
              <EuroInput value={values.amount || ''} onChange={v => change('amount', v)} placeholder="Optional" error={errors.amount} />
            </Field>
          </>
        )}

        {/* Note about full workflow */}
        <div style={{ background: '#0d0d0d', border: '1px solid #1a1a1a', borderRadius: 10, padding: '12px 14px', marginBottom: 20 }}>
          <div className="text-xs" style={{ color: '#555' }}>This request runs a full compliance and budget review. The agent will process it and notify you at <span style={{ color: '#aaa' }}>{user.email}</span>.</div>
        </div>

        {submitError && (
          <div className="rounded-xl px-4 py-3 mb-4 text-sm" style={{ background: '#1a0808', border: '1px solid #3f1010', color: '#f87171' }}>{submitError}</div>
        )}

        <PrimaryButton loading={loading}>Submit request</PrimaryButton>
      </form>
    </div>
  )
}

// ─── Success screen ───────────────────────────────────────────────────────────

function SuccessScreen({ result, onDone }) {
  return (
    <StepWrapper>
      <div className="flex flex-col items-center text-center" style={{ padding: '60px 24px 40px' }}>
        <svg width="88" height="88" viewBox="0 0 88 88" fill="none" style={{ marginBottom: 28 }}>
          <circle className="check-circle" cx="44" cy="44" r="40" fill="#16a34a" fillOpacity="0.15" stroke="#22c55e" strokeWidth="2" />
          <path className="check-mark" d="M27 45l12 12 22-22" stroke="#22c55e" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
        <h1 className="text-2xl font-bold text-white mb-2">{result.item ? 'Order placed' : 'Submitted'}</h1>
        {result.reference && (
          <div className="inline-flex items-center gap-2 rounded-lg px-4 py-2 mb-4" style={{ background: '#141414', border: '1px solid #2a2a2a' }}>
            <span className="text-xs font-medium uppercase tracking-wider" style={{ color: '#888' }}>Ref</span>
            <span className="font-mono font-semibold text-white text-sm">{result.reference}</span>
          </div>
        )}
        <p className="text-sm mb-6" style={{ color: '#888', maxWidth: 280 }}>
          {result.item
            ? `${result.item} — budget check running. You'll hear back at `
            : 'The agent is on it. You\'ll hear back at '}
          <span style={{ color: '#ccc' }}>{result.email}</span>.
        </p>
        <button type="button" onClick={onDone}
          style={{ background: '#1a1a1a', border: '1px solid #2a2a2a', color: '#888', borderRadius: 10, padding: '12px 24px', fontSize: 14, cursor: 'pointer' }}>
          Back to Home
        </button>
      </div>
    </StepWrapper>
  )
}

// ─── Operations Board ─────────────────────────────────────────────────────────

function TicketCard({ ticket, onAction, actionLoading }) {
  const [expanded, setExpanded] = useState(false)

  return (
    <div style={{ background: '#111', border: '1px solid #1e1e1e', borderRadius: 12, overflow: 'hidden', marginBottom: 12 }}>
      <div style={{ padding: '16px 20px' }}>
        <div className="flex items-start justify-between gap-3 mb-3">
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2 mb-1.5 flex-wrap">
              <StatusBadge status={ticket.status} />
              {ticket.supplier_compliance && <ComplianceBadge status={ticket.supplier_compliance} />}
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
          {ticket.supplier_name && <span>{ticket.supplier_name}</span>}
          {ticket.branch_name   && <span>{ticket.branch_name}</span>}
          {ticket.reference     && <span className="font-mono">{ticket.reference}</span>}
          {ticket.po_number     && <span className="font-mono" style={{ color: '#6366f1' }}>PO: {ticket.po_number}</span>}
          <span>{timeAgo(ticket.created_at)}</span>
        </div>
        {ticket.review_notes && (
          <div className="mt-3 text-xs p-3 rounded-lg" style={{ background: '#0d0d0d', color: '#888', border: '1px solid #1a1a1a' }}>
            {ticket.review_notes}
          </div>
        )}
      </div>

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

      <div style={{ padding: '12px 20px', borderTop: '1px solid #1a1a1a', display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
        {(ticket.status === 'pending_review' || ticket.status === 'pending_confirm') && (
          <>
            <ActionButton onClick={() => onAction(ticket.id, 'approve')} loading={actionLoading === `${ticket.id}-approve`} variant="primary">Approve</ActionButton>
            <ActionButton onClick={() => onAction(ticket.id, 'reject')}  loading={actionLoading === `${ticket.id}-reject`}  variant="danger">Reject</ActionButton>
          </>
        )}
        {ticket.status === 'signature_required' && (
          <>
            <ActionButton onClick={() => onAction(ticket.id, 'sign')}   loading={actionLoading === `${ticket.id}-sign`}   variant="primary">Sign & Send</ActionButton>
            <ActionButton onClick={() => onAction(ticket.id, 'reject')} loading={actionLoading === `${ticket.id}-reject`} variant="danger">Decline</ActionButton>
          </>
        )}
        {ticket.status === 'escalated' && (
          <ActionButton onClick={() => onAction(ticket.id, 'acknowledge')} loading={actionLoading === `${ticket.id}-acknowledge`} variant="secondary">Acknowledge</ActionButton>
        )}
        {ticket.status === 'approved' && ticket.po_id && (
          <ActionButton onClick={() => onAction(ticket.id, 'confirm_delivery', { po_id: ticket.po_id })} loading={actionLoading === `${ticket.id}-confirm_delivery`} variant="primary">Confirm Delivery</ActionButton>
        )}
        {ticket.pdf_url && (
          <a href={ticket.pdf_url} target="_blank" rel="noopener noreferrer"
            className="text-xs px-3 py-1.5 rounded-md"
            style={{ color: '#6366f1', background: '#0d0d1a', border: '1px solid #1a1a2e', textDecoration: 'none' }}>
            View PDF
          </a>
        )}
        <button type="button" onClick={() => setExpanded(!expanded)} className="ml-auto text-xs"
          style={{ color: '#444', background: 'none', border: 'none', cursor: 'pointer' }}>
          {expanded ? 'Less ↑' : 'Detail ↓'}
        </button>
      </div>
    </div>
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
    const interval = setInterval(fetchTickets, 30000)
    return () => clearInterval(interval)
  }, [fetchTickets])

  async function handleAction(ticketId, action, extra = {}) {
    setActionLoading(`${ticketId}-${action}`)
    try {
      if (action === 'confirm_delivery') {
        await pgFetch('/rpc/confirm_delivery', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'Prefer': 'return=representation' },
          body: JSON.stringify({ p_po_id: extra.po_id, p_confirmed_by: 'ops_board' }),
        })
        await pgFetch(`/tickets?id=eq.${ticketId}`, {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json', 'Prefer': 'return=representation' },
          body: JSON.stringify({ status: 'closed', closed_at: new Date().toISOString() }),
        })
      } else {
        const statusMap = { approve: 'approved', reject: 'rejected', sign: 'closed', acknowledge: 'approved' }
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

  const signatureTickets = tickets.filter(t => t.status === 'signature_required')
  const reviewTickets    = tickets.filter(t => t.status === 'pending_review')
  const escalatedTickets = tickets.filter(t => t.status === 'escalated')
  const confirmTickets   = tickets.filter(t => t.status === 'pending_confirm')
  const deliveryTickets  = tickets.filter(t => t.status === 'approved' && t.po_id)

  return (
    <div style={{ padding: '20px 16px 100px' }}>
      <div className="flex items-center justify-between mb-6">
        <div>
          <h2 className="text-lg font-bold text-white mb-0.5">Operations Board</h2>
          <p className="text-sm" style={{ color: '#555' }}>
            {tickets.length === 0 ? 'All clear.' : `${tickets.length} item${tickets.length !== 1 ? 's' : ''} need attention`}
          </p>
        </div>
        <div className="text-right">
          <button type="button" onClick={fetchTickets}
            style={{ background: '#111', border: '1px solid #1e1e1e', color: '#555', borderRadius: 8, padding: '6px 12px', fontSize: 12, cursor: 'pointer' }}>
            ↻ Refresh
          </button>
          {lastRefresh && <div className="text-xs mt-1" style={{ color: '#333' }}>{timeAgo(lastRefresh)}</div>}
        </div>
      </div>

      {loading && <div className="flex justify-center py-12"><span className="spinner" /></div>}
      {error && (
        <div className="rounded-xl px-4 py-3 mb-6 text-sm" style={{ background: '#1a0808', border: '1px solid #3f1010', color: '#f87171' }}>
          Failed to load: {error}
        </div>
      )}

      {!loading && !error && tickets.length === 0 && (
        <div className="flex flex-col items-center py-16 text-center">
          <div style={{ fontSize: 40, marginBottom: 12 }}>✅</div>
          <h2 className="text-lg font-semibold text-white mb-2">Nothing needs you right now</h2>
          <p className="text-sm" style={{ color: '#555' }}>The agent is handling everything.</p>
        </div>
      )}

      {signatureTickets.length > 0 && (
        <section className="mb-8">
          <SectionHeader icon="✍️" title="Signature Required" count={signatureTickets.length} urgent />
          {signatureTickets.map(t => <TicketCard key={t.id} ticket={t} onAction={handleAction} actionLoading={actionLoading} />)}
        </section>
      )}
      {reviewTickets.length > 0 && (
        <section className="mb-8">
          <SectionHeader icon="👁" title="Pending Review" count={reviewTickets.length} />
          {reviewTickets.map(t => <TicketCard key={t.id} ticket={t} onAction={handleAction} actionLoading={actionLoading} />)}
        </section>
      )}
      {escalatedTickets.length > 0 && (
        <section className="mb-8">
          <SectionHeader icon="🚨" title="Escalated" count={escalatedTickets.length} />
          {escalatedTickets.map(t => <TicketCard key={t.id} ticket={t} onAction={handleAction} actionLoading={actionLoading} />)}
        </section>
      )}
      {confirmTickets.length > 0 && (
        <section className="mb-8">
          <SectionHeader icon="⚡" title="Quick Confirm" count={confirmTickets.length} />
          {confirmTickets.map(t => <TicketCard key={t.id} ticket={t} onAction={handleAction} actionLoading={actionLoading} />)}
        </section>
      )}
      {deliveryTickets.length > 0 && (
        <section className="mb-8">
          <SectionHeader icon="📦" title="Awaiting Delivery" count={deliveryTickets.length} />
          <p className="text-xs mb-3" style={{ color: '#555' }}>PO sent. Confirm once goods or services received — triggers invoice matching.</p>
          {deliveryTickets.map(t => <TicketCard key={t.id} ticket={t} onAction={handleAction} actionLoading={actionLoading} />)}
        </section>
      )}
    </div>
  )
}

// ─── Bottom nav ───────────────────────────────────────────────────────────────

function BottomNav({ activeTab, onNavigate, boardCount }) {
  return (
    <div style={{ position: 'fixed', bottom: 0, left: 0, right: 0, background: '#0a0a0a', borderTop: '1px solid #1a1a1a', zIndex: 20, paddingBottom: 'env(safe-area-inset-bottom)' }}>
      <div style={{ maxWidth: 480, margin: '0 auto', display: 'flex' }}>
        {NAV_ITEMS.map(item => {
          const active = activeTab === item.id
          const Icon = item.icon
          return (
            <button key={item.id} type="button" onClick={() => onNavigate(item.id)}
              style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3, padding: '10px 4px 8px', background: 'none', border: 'none', cursor: 'pointer', color: active ? '#6366f1' : '#3a3a3a', transition: 'color 0.15s', position: 'relative' }}>
              <Icon size={20} />
              <span style={{ fontSize: 10, fontWeight: 500 }}>{item.label}</span>
              {item.id === 'board' && boardCount > 0 && (
                <span style={{ position: 'absolute', top: 8, right: '50%', marginRight: -18, background: '#ef4444', color: '#fff', fontSize: 9, fontWeight: 700, borderRadius: 99, padding: '1px 5px', lineHeight: '14px' }}>
                  {boardCount}
                </span>
              )}
            </button>
          )
        })}
      </div>
    </div>
  )
}

// ─── App shell ────────────────────────────────────────────────────────────────

export default function App() {
  const [user, setUser]     = useLocalStorage('truespend_user', null)
  const [tab, setTab]       = useState(() => window.location.hash === '#board' ? 'board' : 'home')
  const [requestType, setRequestType] = useState(null) // when showing request form
  const [successResult, setSuccessResult] = useState(null) // after submit
  const [boardCount, setBoardCount] = useState(0)

  // Poll board count for the badge
  useEffect(() => {
    if (!POSTGREST_JWT) return
    async function fetchCount() {
      try {
        const data = await pgFetch('/open_tickets_board')
        setBoardCount((data || []).length)
      } catch {}
    }
    fetchCount()
    const t = setInterval(fetchCount, 60000)
    return () => clearInterval(t)
  }, [])

  function navigate(newTab) {
    setTab(newTab)
    setRequestType(null)
    setSuccessResult(null)
    window.location.hash = newTab === 'board' ? '#board' : ''
  }

  function startRequest(type) {
    setRequestType(type)
    setSuccessResult(null)
    setTab('request')
  }

  function handleSuccess(result) {
    setSuccessResult(result)
    setRequestType(null)
  }

  if (!user) {
    return <UserSetupModal onSave={setUser} />
  }

  return (
    <div style={{ background: '#0a0a0a', minHeight: '100vh' }}>
      {/* Top bar */}
      <div style={{ borderBottom: '1px solid #1a1a1a', background: '#0a0a0a', position: 'sticky', top: 0, zIndex: 10 }}>
        <div style={{ maxWidth: 480, margin: '0 auto', padding: '12px 16px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <span className="font-bold tracking-tight" style={{ color: '#6366f1', fontSize: 17 }}>TrueSpend</span>
          <button type="button" onClick={() => setUser(null)}
            style={{ background: 'none', border: 'none', color: '#333', cursor: 'pointer', fontSize: 12, padding: 4 }}
            title="Switch user">
            {user.name.split(' ')[0]} ↙
          </button>
        </div>
      </div>

      {/* Content */}
      <div style={{ maxWidth: 480, margin: '0 auto' }}>
        {successResult && (
          <SuccessScreen result={successResult} onDone={() => { setSuccessResult(null); navigate('home') }} />
        )}
        {!successResult && tab === 'home' && (
          <HomeScreen user={user} onNavigate={navigate} onRequestType={startRequest} />
        )}
        {!successResult && tab === 'catalog' && (
          <CatalogScreen user={user} onSuccess={handleSuccess} />
        )}
        {!successResult && tab === 'mine' && (
          <MyRequestsScreen user={user} />
        )}
        {!successResult && tab === 'request' && requestType && (
          <RequestForm user={user} requestType={requestType} onBack={() => navigate('home')} onSuccess={handleSuccess} />
        )}
        {!successResult && tab === 'board' && (
          <OperationsBoard />
        )}
      </div>

      <BottomNav activeTab={successResult ? null : tab} onNavigate={navigate} boardCount={boardCount} />
    </div>
  )
}
