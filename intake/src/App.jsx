import { useState, useEffect, useCallback, useRef } from 'react'

// ─── Config ───────────────────────────────────────────────────────────────────
const POSTGREST_URL = import.meta.env.VITE_POSTGREST_URL || 'https://postgrest-production-7960.up.railway.app'
const POSTGREST_JWT = import.meta.env.VITE_POSTGREST_JWT || ''
const N8N_WEBHOOK   = import.meta.env.VITE_N8N_WEBHOOK_URL || 'https://n8n-n3xl.eugenmueller.tech/webhook/intake'

// ─── Branches ─────────────────────────────────────────────────────────────────
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
]

// ─── Helpers ──────────────────────────────────────────────────────────────────
const fmt = (n) => '€' + Number(n).toLocaleString('de-DE', { minimumFractionDigits: 0, maximumFractionDigits: 0 })

const timeAgo = (iso) => {
  const m = Math.floor((Date.now() - new Date(iso)) / 60000)
  if (m < 1)  return 'just now'
  if (m < 60) return `${m}m ago`
  const h = Math.floor(m / 60)
  if (h < 24) return `${h}h ago`
  return `${Math.floor(h / 24)}d ago`
}

function useLocalStorage(key, init) {
  const [v, setV] = useState(() => {
    try { const s = localStorage.getItem(key); return s ? JSON.parse(s) : init } catch { return init }
  })
  const set = useCallback((val) => {
    const next = typeof val === 'function' ? val(v) : val
    setV(next)
    try { localStorage.setItem(key, JSON.stringify(next)) } catch {}
  }, [key, v])
  return [v, set]
}

async function pgFetch(path) {
  const r = await fetch(`${POSTGREST_URL}${path}`, {
    headers: { Authorization: `Bearer ${POSTGREST_JWT}`, Accept: 'application/json' }
  })
  if (!r.ok) throw new Error(`PostgREST ${r.status}`)
  return r.json()
}

async function pgPatch(path, body) {
  const r = await fetch(`${POSTGREST_URL}${path}`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${POSTGREST_JWT}`, 'Content-Type': 'application/json', Prefer: 'return=representation' },
    body: JSON.stringify(body)
  })
  if (!r.ok) throw new Error(`PostgREST PATCH ${r.status}`)
  return r.json()
}

// ─── Icons (Lucide stroke style, 1.5px rounded) ───────────────────────────────
const Icon = ({ children, size = 18, color, strokeWidth = 1.5, style, ...rest }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none"
    stroke={color || 'currentColor'} strokeWidth={strokeWidth}
    strokeLinecap="round" strokeLinejoin="round" style={style} {...rest}>
    {children}
  </svg>
)

const IconHome     = (p) => <Icon {...p}><path d="M3 12l9-9 9 9"/><path d="M5 10v11h5v-7h4v7h5V10"/></Icon>
const IconCatalog  = (p) => <Icon {...p}><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/></Icon>
const IconList     = (p) => <Icon {...p}><path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01"/></Icon>
const IconBoard    = (p) => <Icon {...p}><rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18"/><circle cx="7" cy="14" r="1" fill="currentColor"/><path d="M11 14h7"/></Icon>
const IconPlus     = (p) => <Icon {...p}><path d="M12 5v14M5 12h14"/></Icon>
const IconMinus    = (p) => <Icon {...p}><path d="M5 12h14"/></Icon>
const IconChev     = (p) => <Icon {...p}><path d="M9 6l6 6-6 6"/></Icon>
const IconChevDown = (p) => <Icon {...p}><path d="M6 9l6 6 6-6"/></Icon>
const IconArrowL   = (p) => <Icon {...p}><path d="M19 12H5M12 19l-7-7 7-7"/></Icon>
const IconX        = (p) => <Icon {...p}><path d="M18 6L6 18M6 6l12 12"/></Icon>
const IconRotateCw = (p) => <Icon {...p}><path d="M21 12a9 9 0 1 1-3-6.7"/><path d="M21 4v5h-5"/></Icon>
const IconCheck    = (p) => <Icon {...p}><circle cx="12" cy="12" r="9"/><path d="M8 12l3 3 5-6"/></Icon>
const IconPenLine  = (p) => <Icon {...p}><path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z"/></Icon>
const IconEye      = (p) => <Icon {...p}><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7z"/><circle cx="12" cy="12" r="3"/></Icon>
const IconSiren    = (p) => <Icon {...p}><path d="M7 12a5 5 0 0 1 10 0v6H7z"/><path d="M5 20h14"/><path d="M21 12h1M2 12h1M12 2v1M19 5l.7-.7M5 5l-.7-.7"/></Icon>
const IconZap      = (p) => <Icon {...p}><path d="M13 2L4 14h7l-1 8 9-12h-7z"/></Icon>
const IconBag      = (p) => <Icon {...p}><path d="M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z"/><path d="M3 6h18"/><path d="M16 10a4 4 0 0 1-8 0"/></Icon>
const IconRefresh  = (p) => <Icon {...p}><path d="M21 12a9 9 0 1 1-3-6.7L21 8"/><path d="M21 3v5h-5"/></Icon>
const IconBuilding = (p) => <Icon {...p}><rect x="4" y="2" width="16" height="20" rx="1.5"/><path d="M9 22v-4h6v4"/><path d="M8 6h.01M16 6h.01M8 10h.01M16 10h.01M8 14h.01M16 14h.01M12 6h.01M12 10h.01M12 14h.01"/></Icon>
const IconLaptop   = (p) => <Icon {...p}><rect x="3" y="5" width="18" height="11" rx="1.5"/><path d="M2 20h20"/></Icon>
const IconApp      = (p) => <Icon {...p}><rect x="3" y="4" width="18" height="16" rx="2"/><path d="M3 9h18"/><circle cx="6.5" cy="6.5" r="0.6" fill="currentColor"/><circle cx="9" cy="6.5" r="0.6" fill="currentColor"/></Icon>
const IconCloud    = (p) => <Icon {...p}><path d="M17 18a4 4 0 0 0 0-8 6 6 0 0 0-11.7 1.5A4.5 4.5 0 0 0 6.5 18z"/></Icon>
const IconWrench   = (p) => <Icon {...p}><path d="M14.7 6.3a4 4 0 0 0 5.7 5.7l-9.4 9.4a2 2 0 0 1-2.8-2.8z"/><path d="M17 7l-2-2"/></Icon>
const IconClock    = (p) => <Icon {...p}><circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/></Icon>
const IconPackage  = (p) => <Icon {...p}><path d="M12 3l9 4.5v9L12 21l-9-4.5v-9z"/><path d="M3 7.5l9 4.5 9-4.5"/><path d="M12 12v9"/></Icon>
const IconTruck    = (p) => <Icon {...p}><path d="M5 17H3a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11v12H5z"/><path d="M14 7h5l3 4v4h-8V7z"/><circle cx="7.5" cy="17.5" r="1.5"/><circle cx="17.5" cy="17.5" r="1.5"/></Icon>
const IconFile     = (p) => <Icon {...p}><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6"/><path d="M16 13H8M16 17H8M10 9H8"/></Icon>

// ─── Status config ─────────────────────────────────────────────────────────────
const STATUS = {
  signature_required: { label: 'Signature required', dot: '#B5462E', bg: '#F6E5DE', fg: '#B5462E' },
  pending_review:     { label: 'Pending review',     dot: '#C99119', bg: '#FAF1D7', fg: '#8C6510' },
  escalated:          { label: 'Escalated',          dot: '#2B5F7A', bg: '#E6EEF2', fg: '#2B5F7A' },
  pending_confirm:    { label: 'Quick confirm',      dot: '#B07219', bg: '#F7EFDE', fg: '#8F5C12' },
  approved:           { label: 'Approved',           dot: '#3D7A5A', bg: '#EEF3EE', fg: '#3D7A5A' },
  rejected:           { label: 'Rejected',           dot: '#A89B8B', bg: '#EFEBE1', fg: '#75695F' },
  closed:             { label: 'Closed',             dot: '#A89B8B', bg: '#EFEBE1', fg: '#75695F' },
  auto_executed:      { label: 'Auto-executed',      dot: '#3D7A5A', bg: '#EEF3EE', fg: '#3D7A5A' },
  reasoning:          { label: 'Reviewing',          dot: '#B07219', bg: '#F7EFDE', fg: '#8F5C12' },
}

const StatusPill = ({ status }) => {
  const s = STATUS[status] || STATUS.closed
  return (
    <span className="pill" style={{ background: s.bg, color: s.fg }}>
      <span className="pill__dot" style={{ background: s.dot }} />
      {s.label}
    </span>
  )
}

// ─── Board sections ────────────────────────────────────────────────────────────
const BOARD_SECTIONS = [
  { id: 'sig', Icon: IconPenLine, title: 'Signature required', urgent: true,  status: 'signature_required', hint: 'Final human checkpoint — agent has prepared the package.' },
  { id: 'rev', Icon: IconEye,     title: 'Pending review',     urgent: false, status: 'pending_review',     hint: 'One signal uncertain — agent recommends, you decide.' },
  { id: 'esc', Icon: IconSiren,   title: 'Escalated',          urgent: false, status: 'escalated',          hint: 'Crosses €100k or hits a compliance blocker.' },
  { id: 'con', Icon: IconZap,     title: 'Quick confirm',      urgent: false, status: 'pending_confirm',    hint: 'Standard request — one-touch and the agent does the rest.' },
]

// ─── Catalog data ──────────────────────────────────────────────────────────────
const CATALOG = [
  {
    category: 'Hardware', Icon: IconLaptop,
    items: [
      { id: 'mac-pro-14', name: 'MacBook Pro 14"',     supplier: 'Apple',    price: 2199,  sku: 'APPMBP14M3PRO', desc: 'M3 Pro · 18 GB · 512 GB. Standard dev config.' },
      { id: 'mac-pro-16', name: 'MacBook Pro 16"',     supplier: 'Apple',    price: 2999,  sku: 'APPMBP16M3MAX', desc: 'M3 Max · 36 GB · 1 TB. Power user config.' },
      { id: 'dell-u27',   name: 'Dell UltraSharp 27"', supplier: 'Dell',     price: 549,   sku: 'DELLU2723QE',   desc: '4K USB-C monitor, 90 W PD. Standard desk monitor.' },
      { id: 'dock-uc',    name: 'CalDigit TS4 Dock',   supplier: 'CalDigit', price: 299,   sku: 'CDTS4',         desc: 'Thunderbolt 4, 18 ports. Standard docking station.' },
      { id: 'iphone-15',  name: 'iPhone 15 Pro',       supplier: 'Apple',    price: 1199,  sku: 'APPIPH15P256',  desc: '256 GB. Standard corporate mobile.' },
    ],
  },
  {
    category: 'Software', Icon: IconApp,
    items: [
      { id: 'ms365-e3',   name: 'Microsoft 365 E3',   supplier: 'Microsoft', price: 36, sku: 'MS365E3',   desc: 'Per user / month. Teams, Outlook, Office, SharePoint.', per: '/mo' },
      { id: 'github-ent', name: 'GitHub Enterprise',  supplier: 'GitHub',    price: 21, sku: 'GHENT',     desc: 'Per user / month. Advanced Security + GHAS.', per: '/mo' },
      { id: 'figma-org',  name: 'Figma Organization', supplier: 'Figma',     price: 45, sku: 'FIGMAORG',  desc: 'Per editor / month. Unlimited projects.', per: '/mo' },
      { id: 'slack-pro',  name: 'Slack Pro',          supplier: 'Salesforce',price: 8,  sku: 'SLKPRO',    desc: 'Per user / month. Standard workspace.', per: '/mo' },
    ],
  },
  {
    category: 'Cloud', Icon: IconCloud,
    items: [
      { id: 'aws-ri', name: 'AWS Reserved Instance', supplier: 'Amazon Web Services', price: 0, sku: 'AWS-RI',  desc: 'Variable — submit for budget allocation. Agent reviews utilisation first.', variable: true },
      { id: 'gcp-cu', name: 'GCP Committed Use',     supplier: 'Google Cloud',        price: 0, sku: 'GCP-CUD', desc: 'Variable — commit discount contract. Agent checks prior spend.', variable: true },
    ],
  },
  {
    category: 'Services', Icon: IconWrench,
    items: [
      { id: 'soc2', name: 'SOC 2 Type II audit', supplier: 'Deloitte',  price: 35000, sku: 'SOC2T2',     desc: 'Annual audit. Fixed price per framework agreement.' },
      { id: 'pen',  name: 'Penetration test',    supplier: 'NCC Group', price: 18000, sku: 'PENTESTANN', desc: 'Annual web + infra pentest. Standard scope.' },
    ],
  },
]

const FORM_CONFIG = {
  purchase: { title: 'Purchase request',    hint: 'New supplier or one-off spend.' },
  renew:    { title: 'Contract renewal',    hint: 'Extend or renegotiate an agreement.' },
  onboard:  { title: 'Supplier onboarding', hint: 'Bring a new vendor into the system.' },
  other:    { title: 'Other request',       hint: 'Anything else.' },
}

const QUICK_TILES = [
  { id: 'purchase', label: 'Ad-hoc purchase',    sub: 'New supplier or one-off spend',      Icon: IconBag },
  { id: 'renew',    label: 'Renew a contract',   sub: 'Extend or renegotiate an agreement', Icon: IconRefresh },
  { id: 'onboard',  label: 'Onboard a supplier', sub: 'Bring a new vendor into the system', Icon: IconBuilding },
  { id: 'other',    label: 'Something else',     sub: 'Any other procurement request',      Icon: IconZap },
]

// ─── Agent activity feed (static) ─────────────────────────────────────────────
const AGENT_FEED = [
  { time: '11:32', title: 'Auto-approved Figma Organization × 6',           branch: 'DACH',    value: 270 },
  { time: '11:28', title: 'Released Q2 commit on AWS reserved (us-east-1)', branch: 'Global',  value: 9400 },
  { time: '11:14', title: 'Reordered Dell UltraSharp 27" × 4',              branch: 'Nordics', value: 2196 },
  { time: '10:51', title: 'Closed Slack Pro renewal — same terms',           branch: 'Iberia',  value: 1248 },
  { time: '10:39', title: 'Auto-approved MS 365 E3 × 12 onboardings',       branch: 'DACH',    value: 432 },
  { time: '10:22', title: 'Cleared shelfware: 14 Salesforce seats',          branch: 'Benelux', value: -2380, dim: true },
  { time: '09:57', title: 'Onboarded NCC Group — DPA + NDA signed',          branch: 'UK & IE', value: 0,    dim: true },
]

// ─── Sidebar ──────────────────────────────────────────────────────────────────
const NAV_PRIMARY = [
  { id: 'board',   label: 'Operations',  Icon: IconBoard,   countKey: 'open' },
  { id: 'orders',  label: 'Orders',      Icon: IconTruck,   countKey: 'orders' },
  { id: 'catalog', label: 'Catalog',     Icon: IconCatalog },
  { id: 'mine',    label: 'My requests', Icon: IconList },
  { id: 'home',    label: 'New request', Icon: IconPlus },
]

// ─── PO Status config ──────────────────────────────────────────────────────────
const PO_STATUS = {
  sent:         { label: 'Sent to supplier',  dot: '#2B5F7A', bg: '#E6EEF2', fg: '#2B5F7A' },
  acknowledged: { label: 'Acknowledged',      dot: '#B07219', bg: '#F7EFDE', fg: '#8F5C12' },
  delivered:    { label: 'Delivered',         dot: '#3D7A5A', bg: '#EEF3EE', fg: '#3D7A5A' },
  invoiced:     { label: 'Invoiced',          dot: '#8B6AA1', bg: '#F0EBF6', fg: '#6B4F8A' },
  closed:       { label: 'Closed',            dot: '#A89B8B', bg: '#EFEBE1', fg: '#75695F' },
  draft:        { label: 'Draft',             dot: '#C9BFAE', bg: '#F5F1EA', fg: '#A89B8B' },
  cancelled:    { label: 'Cancelled',         dot: '#B5462E', bg: '#F6E5DE', fg: '#B5462E' },
}

const PoStatusPill = ({ status }) => {
  const s = PO_STATUS[status] || PO_STATUS.draft
  return (
    <span className="pill" style={{ background: s.bg, color: s.fg }}>
      <span className="pill__dot" style={{ background: s.dot }} />
      {s.label}
    </span>
  )
}

const Sidebar = ({ tab, onNav, counts, openByStatus, onJumpSection, user, onSwitchUser }) => {
  const sidebarTab = tab === 'request' ? 'home' : tab
  const initials = user ? user.name.split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase() : '?'
  const branch = user ? (BRANCHES.find(b => b.id === user.branchId)?.label || '') : ''

  return (
    <aside className="sidebar">
      <div className="sidebar__brand">
        <div className="sidebar__brand-mark">
          <svg width="16" height="16" viewBox="0 0 64 64" fill="none">
            <path d="M16 18 H48 V25 H37 V48 H29 V25 H16 Z" fill="#B07219"/>
            <path d="M22 18 L42 18 L42 25 L33 25 L33 32 L25 32 L25 25 L22 25 Z" fill="#D89E40" opacity="0.85"/>
          </svg>
        </div>
        <span className="sidebar__brand-word">TrueSpend</span>
      </div>

      <div className="sidebar__sectionhead">Workspace</div>
      <nav className="sidebar__nav">
        {NAV_PRIMARY.map(({ id, label, Icon, countKey }) => {
          const active = sidebarTab === id
          const count = countKey ? counts[countKey] : null
          return (
            <button
              key={id}
              className={'sidebar__link' + (active ? ' sidebar__link--active' : '')}
              onClick={() => onNav(id)}
            >
              <span className="sidebar__link-icon"><Icon size={16} /></span>
              <span>{label}</span>
              {count != null && count > 0 && (
                <span className={'sidebar__count' + (countKey === 'open' ? ' sidebar__count--urgent' : '')}>
                  {count}
                </span>
              )}
            </button>
          )
        })}
      </nav>

      {sidebarTab === 'board' && openByStatus && Object.keys(openByStatus).length > 0 && (
        <div style={{ padding: '6px 12px 0', marginTop: 8 }}>
          {[
            { status: 'signature_required', label: 'Signature required', dot: '#B5462E' },
            { status: 'pending_review',     label: 'Pending review',     dot: '#C99119' },
            { status: 'escalated',          label: 'Escalated',          dot: '#2B5F7A' },
            { status: 'pending_confirm',    label: 'Quick confirm',      dot: '#B07219' },
          ].map(s => {
            const c = openByStatus[s.status] || 0
            if (!c) return null
            return (
              <button key={s.status} className="sidebar__sub" onClick={() => onJumpSection(s.status)}>
                <span className="sidebar__sub-dot" style={{ background: s.dot }} />
                <span>{s.label}</span>
                <span className="sidebar__sub-count">{c}</span>
              </button>
            )
          })}
        </div>
      )}

      <div className="sidebar__sectionhead">Reference</div>
      <nav className="sidebar__nav">
        {[
          { label: 'Suppliers',  Icon: IconBuilding, url: 'https://grafana-production-49fc.up.railway.app/d/3c77930d-33a5-4f55-b104-766e171573bf/suppliers' },
          { label: 'Budgets',    Icon: IconWrench,   url: 'https://grafana-production-49fc.up.railway.app/d/06389734-1dd7-4bae-89c0-dcce8b1c8d09/budgets' },
          { label: 'Contracts',  Icon: IconRefresh,  url: 'https://grafana-production-49fc.up.railway.app/d/7731a334-ca87-4301-a364-9b816c58b64c/contracts' },
          { label: 'Expiring',   Icon: IconClock,    url: 'https://grafana-production-49fc.up.railway.app/d/a1b2c3d4-expiry-dash-0001/expiring-contracts-and-licenses' },
          { label: 'PO Status',  Icon: IconTruck,    url: 'https://grafana-production-49fc.up.railway.app/d/po-board-dash-0001/purchase-orders' },
        ].map(({ label, Icon, url }) => (
          <button key={label} className="sidebar__link" onClick={() => window.open(url, '_blank')}>
            <span className="sidebar__link-icon"><Icon size={16} /></span>
            <span>{label}</span>
          </button>
        ))}
      </nav>

      <div className="sidebar__user">
        <div className="sidebar__avatar">{initials}</div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div className="sidebar__user-name">{user?.name || 'Guest'}</div>
          <div className="sidebar__user-sub">{branch}</div>
        </div>
        <button className="iconbtn" title="Switch user" style={{ width: 26, height: 26 }} onClick={onSwitchUser}>
          <IconChevDown size={14} />
        </button>
      </div>
    </aside>
  )
}

// ─── TopBar ───────────────────────────────────────────────────────────────────
const TopBar = ({ crumbs, cartCount = 0, onOpenCart }) => (
  <div className="topbar">
    <div className="topbar__crumbs">
      {crumbs.map((c, i) => (
        <span key={i} style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
          {i > 0 && <IconChev size={12} style={{ color: '#A89B8B' }} />}
          {i === crumbs.length - 1 ? <strong>{c}</strong> : <span>{c}</span>}
        </span>
      ))}
    </div>
    <div className="topbar__right">
      <div className="searchbar">
        <span className="searchbar__icon">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
            <circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/>
          </svg>
        </span>
        <input placeholder="Search requests, suppliers, refs…" />
        <span className="searchbar__kbd">⌘ K</span>
      </div>
      {cartCount > 0 && (
        <button className="btn btn--ink btn--sm" onClick={onOpenCart} style={{ position: 'relative', gap: 8 }}>
          <IconBag size={14} />
          Cart
          <span style={{
            background: '#B07219', color: '#fff',
            fontSize: 10, fontWeight: 700, lineHeight: 1,
            padding: '2px 5px', borderRadius: 99,
            fontVariantNumeric: 'tabular-nums',
          }}>{cartCount}</span>
        </button>
      )}
      <button className="iconbtn" title="Notifications">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
          <path d="M18 8a6 6 0 1 0-12 0c0 7-3 9-3 9h18s-3-2-3-9"/>
          <path d="M13.7 21a2 2 0 0 1-3.4 0"/>
        </svg>
      </button>
    </div>
  </div>
)

// ─── Agent Rail ────────────────────────────────────────────────────────────────
const AgentRail = () => (
  <aside className="rail">
    <div className="rail__head">
      <span className="rail__head-dot" />
      Agent · today
    </div>
    <div className="rail__feed">
      {AGENT_FEED.map((e, i) => (
        <div key={i} className="rail__entry">
          <div className="rail__entry-time">{e.time}</div>
          <div className="rail__entry-title">{e.title}</div>
          <div className="rail__entry-meta">
            <span>{e.branch}</span>
            {e.value !== 0 && (
              <>
                <span style={{ width: 3, height: 3, borderRadius: '50%', background: '#C9BFAE', display: 'inline-block' }} />
                <span className="money" style={{ fontSize: 12, color: e.value < 0 ? '#3D7A5A' : (e.dim ? '#75695F' : '#3D3633') }}>
                  {e.value < 0 ? '−' : ''}{fmt(Math.abs(e.value))}
                </span>
              </>
            )}
          </div>
        </div>
      ))}
    </div>
  </aside>
)

// ─── Stats Strip ──────────────────────────────────────────────────────────────
const StatsStrip = ({ tickets }) => {
  const totalValue = tickets.reduce((s, t) => s + (t.value_eur || 0), 0)
  return (
    <div className="stats">
      <div className="stat">
        <div className="stat__label">Need you</div>
        <div className="stat__val">{tickets.length}</div>
        <div className="stat__hint">Across {BOARD_SECTIONS.filter(s => tickets.some(t => t.status === s.status)).length} sections</div>
      </div>
      <div className="stat">
        <div className="stat__label">Value at decision</div>
        <div className="stat__val">{fmt(totalValue)}</div>
        <div className="stat__hint">Total notional in your queue</div>
      </div>
      <div className="stat">
        <div className="stat__label">Closed today by agent</div>
        <div className="stat__val">47 <em>auto</em></div>
        <div className="stat__hint">€248.500 · 0 errors</div>
      </div>
      <div className="stat">
        <div className="stat__label">Confidence floor</div>
        <div className="stat__val stat__val--gold">92%</div>
        <div className="stat__hint">Below floor → routed here</div>
      </div>
    </div>
  )
}

// ─── Ticket Row ───────────────────────────────────────────────────────────────
const TicketRow = ({ ticket, isOpen, onToggle, onAction }) => {
  return (
    <>
      <div className={'trow' + (isOpen ? ' trow--open' : '')} onClick={() => onToggle(ticket.id)}>
        <div className="trow__status">
          <StatusPill status={ticket.status} />
        </div>
        <div className="trow__main">
          <div className="trow__title">{ticket.title}</div>
          <div className="trow__meta">
            <span className="ref">{ticket.reference}</span>
            <span className="dot" />
            <span>{timeAgo(ticket.created_at)}</span>
            {ticket.category && <><span className="dot" /><span>{ticket.category}</span></>}
          </div>
        </div>
        <div>
          <div className="trow__supplier">{ticket.supplier_name || '—'}</div>
          <div className="trow__supplier-meta">{ticket.submitted_by || ''}</div>
        </div>
        <div>
          <div className="trow__value">{ticket.value_eur ? fmt(ticket.value_eur) : '—'}</div>
          {ticket.confidence_score && (
            <div className="trow__conf">conf. {Math.round(ticket.confidence_score * 100)}%</div>
          )}
        </div>
        <div className="trow__actions" onClick={e => e.stopPropagation()}>
          {ticket.status === 'signature_required' && (<>
            <button className="btn btn--ink btn--sm" onClick={() => onAction(ticket.id, 'sign')}>Sign &amp; send</button>
            <button className="btn btn--danger btn--sm" onClick={() => onAction(ticket.id, 'decline')}>Decline</button>
          </>)}
          {ticket.status === 'pending_review' && (<>
            <button className="btn btn--success btn--sm" onClick={() => onAction(ticket.id, 'approve')}>Approve</button>
            <button className="btn btn--danger btn--sm" onClick={() => onAction(ticket.id, 'reject')}>Reject</button>
          </>)}
          {ticket.status === 'escalated' && (
            <button className="btn btn--secondary btn--sm" onClick={() => onAction(ticket.id, 'ack')}>Acknowledge</button>
          )}
          {ticket.status === 'pending_confirm' && (
            <button className="btn btn--primary btn--sm" onClick={() => onAction(ticket.id, 'confirm')}>Confirm</button>
          )}
        </div>
      </div>

      {isOpen && (
        <div className="tbrief">
          <div>
            <div className="tbrief__h">Description</div>
            <div className="tbrief__body">{ticket.description || ticket.title}</div>
          </div>
          {ticket.reasoning && (
            <div>
              <div className="tbrief__h">Agent reasoning</div>
              <div className="tbrief__body">{ticket.reasoning}</div>
            </div>
          )}
        </div>
      )}
    </>
  )
}

// ─── Operations Board ─────────────────────────────────────────────────────────
const OperationsBoard = ({ sectionJump, onCountChange }) => {
  const [tickets, setTickets] = useState(null)
  const [openId, setOpenId]   = useState(null)

  const load = useCallback(async () => {
    try {
      const data = await pgFetch('/open_tickets_board?order=created_at.asc')
      setTickets(data)
      onCountChange(data.length)
    } catch {
      setTickets([])
    }
  }, [onCountChange])

  useEffect(() => { load() }, [load])
  useEffect(() => {
    const t = setInterval(load, 30000)
    return () => clearInterval(t)
  }, [load])

  useEffect(() => {
    if (sectionJump) {
      const el = document.getElementById('sec-' + sectionJump)
      if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' })
    }
  }, [sectionJump])

  const handleAction = async (id, action) => {
    const statusMap = { approve: 'approved', reject: 'rejected', sign: 'approved', decline: 'rejected', confirm: 'approved', ack: 'closed' }
    try {
      await pgPatch(`/tickets?id=eq.${id}`, { status: statusMap[action] || 'approved' })
      load()
    } catch {}
  }

  const today = new Date().toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric' })

  if (tickets === null) {
    return (
      <div className="content content--with-rail step-in">
        <div style={{ padding: '80px 0', textAlign: 'center', color: '#75695F' }}>Loading…</div>
        <AgentRail />
      </div>
    )
  }

  if (tickets.length === 0) {
    return (
      <div className="content content--with-rail step-in">
        <div>
          <div className="pagehead">
            <div>
              <div className="pagehead__eyebrow">Operations · {today}</div>
              <h1 className="pagehead__title">All clear.</h1>
              <div className="pagehead__sub">Nothing needs you right now. The agent is handling everything in the queue.</div>
            </div>
            <div className="pagehead__actions">
              <button className="btn btn--tertiary" onClick={load}><IconRotateCw size={14}/> Refresh</button>
            </div>
          </div>
          <div style={{ background: '#FFFEFB', border: '1px solid #E5DDD0', borderRadius: 8, padding: '80px 24px', textAlign: 'center' }}>
            <IconCheck size={44} color="#3D7A5A" strokeWidth={1.25} />
            <h2 style={{ fontFamily: "'Instrument Serif', serif", fontSize: 32, letterSpacing: '-0.025em', color: '#161413', margin: '18px 0 6px' }}>
              Nothing <em style={{ fontStyle: 'normal', color: '#8F5C12' }}>needs you</em>.
            </h2>
            <p style={{ fontSize: 13.5, color: '#75695F', maxWidth: 360, margin: '0 auto', lineHeight: 1.6 }}>
              Come back when there's something worth your attention.
            </p>
          </div>
        </div>
        <AgentRail />
      </div>
    )
  }

  const openByStatus = tickets.reduce((acc, t) => { acc[t.status] = (acc[t.status] || 0) + 1; return acc }, {})

  return (
    <div className="content content--with-rail step-in">
      <div>
        <div className="pagehead">
          <div>
            <div className="pagehead__eyebrow">Operations · {today}</div>
            <h1 className="pagehead__title">
              {tickets.length} {tickets.length === 1 ? 'thing' : 'things'} <em>need you</em>.
            </h1>
            <div className="pagehead__sub">Everything else, the agent closed. Expand any row for the brief.</div>
          </div>
          <div className="pagehead__actions">
            <button className="btn btn--tertiary" onClick={load}><IconRotateCw size={14}/> Refresh</button>
            <button className="btn btn--secondary">Export</button>
          </div>
        </div>

        <StatsStrip tickets={tickets} />

        {BOARD_SECTIONS.map(sec => {
          const inSec = tickets.filter(t => t.status === sec.status)
          if (!inSec.length) return null
          return (
            <section key={sec.id} id={'sec-' + sec.status} className={'section' + (sec.urgent ? ' section--urgent' : '')}>
              <div className="section__head">
                <span className="section__icon"><sec.Icon size={16}/></span>
                <span className="section__title">{sec.title}</span>
                <span className="section__count">{inSec.length}</span>
                <span className="section__hint">{sec.hint}</span>
              </div>
              <div className="tlist">
                {inSec.map(t => (
                  <TicketRow
                    key={t.id}
                    ticket={t}
                    isOpen={openId === t.id}
                    onToggle={(id) => setOpenId(openId === id ? null : id)}
                    onAction={handleAction}
                  />
                ))}
              </div>
            </section>
          )
        })}
      </div>
      <AgentRail />
    </div>
  )
}

// ─── Home ──────────────────────────────────────────────────────────────────────
const HomeScreen = ({ user, onCatalog, onRequestType }) => {
  const firstName = user?.name?.split(' ')[0] || 'there'
  return (
    <div className="content step-in" style={{ maxWidth: 980 }}>
      <div className="pagehead">
        <div>
          <div className="pagehead__eyebrow">{new Date().toLocaleDateString('en-GB', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })}</div>
          <h1 className="greeting__hello">Hi, <em>{firstName}.</em></h1>
          <div className="greeting__sub">What do you need to get done?</div>
        </div>
      </div>

      <div style={{
        background: '#161413', borderRadius: 10, padding: '28px 32px',
        display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 24,
        marginBottom: 32,
      }}>
        <div>
          <div style={{ fontSize: 10.5, letterSpacing: '0.16em', textTransform: 'uppercase', color: '#B07219', marginBottom: 10, fontWeight: 500 }}>
            Catalog
          </div>
          <h2 style={{ fontFamily: "'Instrument Serif', serif", fontSize: 32, letterSpacing: '-0.025em', color: '#F7F4ED', margin: 0, lineHeight: 1.1, maxWidth: 480 }}>
            Standard items. <span style={{ color: '#B07219' }}>Instant approval.</span>
          </h2>
          <div style={{ fontSize: 13, color: 'rgba(247,244,237,0.6)', marginTop: 10 }}>
            Contract on file. Budget check only. No waiting.
          </div>
        </div>
        <button className="btn btn--primary btn--lg" onClick={onCatalog}>
          Browse catalog <IconChev size={14}/>
        </button>
      </div>

      <div style={{ fontSize: 11, fontWeight: 500, letterSpacing: '0.14em', textTransform: 'uppercase', color: '#75695F', marginBottom: 14 }}>
        Or submit a request
      </div>
      <div className="tile-grid">
        {QUICK_TILES.map(({ id, label, sub, Icon }) => (
          <button key={id} className="tile" onClick={() => onRequestType(id)}>
            <div className="tile__icon"><Icon size={18} /></div>
            <div className="tile__body">
              <div className="tile__title">{label}</div>
              <div className="tile__sub">{sub}</div>
            </div>
          </button>
        ))}
      </div>
    </div>
  )
}

// ─── Cart Modal ───────────────────────────────────────────────────────────────
const CartModal = ({ cart, onClose, onUpdateQty, onRemove, onPlace }) => {
  const [notes, setNotes] = useState('')
  if (!cart.length) return (
    <div className="modal-scrim" onClick={onClose}>
      <div className="modal" onClick={e => e.stopPropagation()}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 22 }}>
          <div style={{ fontFamily: "'Instrument Serif', serif", fontSize: 24, color: '#161413', letterSpacing: '-0.025em' }}>Cart</div>
          <button onClick={onClose} className="iconbtn"><IconX size={16} /></button>
        </div>
        <div style={{ textAlign: 'center', padding: '40px 0', color: '#75695F', fontSize: 14 }}>Your cart is empty.</div>
      </div>
    </div>
  )

  const total = cart.reduce((s, l) => s + (l.item.variable ? 0 : l.item.price * l.qty), 0)
  const itemCount = cart.reduce((s, l) => s + l.qty, 0)

  return (
    <div className="modal-scrim" onClick={onClose}>
      <div className="modal" style={{ maxWidth: 520 }} onClick={e => e.stopPropagation()}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
          <div>
            <div style={{ fontSize: 11, letterSpacing: '0.14em', textTransform: 'uppercase', color: '#75695F', marginBottom: 4 }}>Order</div>
            <div style={{ fontFamily: "'Instrument Serif', serif", fontSize: 24, color: '#161413', letterSpacing: '-0.025em' }}>
              {itemCount} item{itemCount !== 1 ? 's' : ''}
            </div>
          </div>
          <button onClick={onClose} className="iconbtn"><IconX size={16} /></button>
        </div>

        <div style={{ borderTop: '1px solid #E5DDD0', borderBottom: '1px solid #E5DDD0', marginBottom: 18 }}>
          {cart.map((line, i) => (
            <div key={line.item.id} style={{
              display: 'grid', gridTemplateColumns: '1fr auto auto auto',
              alignItems: 'center', gap: 12, padding: '14px 0',
              borderBottom: i < cart.length - 1 ? '1px solid #EEE7DA' : 'none',
            }}>
              <div>
                <div style={{ fontSize: 13.5, fontWeight: 600, color: '#161413', letterSpacing: '-0.005em' }}>{line.item.name}</div>
                <div style={{ fontSize: 12, color: '#75695F', marginTop: 2 }}>{line.item.supplier}</div>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <button className="btn btn--secondary btn--sm" style={{ width: 28, height: 28, padding: 0 }} onClick={() => onUpdateQty(line.item.id, line.qty - 1)}>
                  <IconMinus size={12} />
                </button>
                <span style={{ minWidth: 20, textAlign: 'center', fontSize: 14, fontWeight: 600, color: '#161413', fontVariantNumeric: 'tabular-nums' }}>{line.qty}</span>
                <button className="btn btn--secondary btn--sm" style={{ width: 28, height: 28, padding: 0 }} onClick={() => onUpdateQty(line.item.id, line.qty + 1)}>
                  <IconPlus size={12} />
                </button>
              </div>
              <div className="money" style={{ fontSize: 14, minWidth: 72, textAlign: 'right' }}>
                {line.item.variable ? 'Variable' : fmt(line.item.price * line.qty)}
              </div>
              <button className="iconbtn" style={{ width: 24, height: 24 }} onClick={() => onRemove(line.item.id)}>
                <IconX size={12} />
              </button>
            </div>
          ))}
        </div>

        {total > 0 && (
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 18 }}>
            <span style={{ fontSize: 13, color: '#75695F' }}>Total</span>
            <span className="money" style={{ fontSize: 20 }}>{fmt(total)}</span>
          </div>
        )}

        <div className="field">
          <label className="field__label">Notes <span style={{ color: '#75695F', fontWeight: 400 }}>(optional)</span></label>
          <input className="input" placeholder="Asset tags, delivery notes, etc." value={notes} onChange={e => setNotes(e.target.value)} />
        </div>

        <div style={{ background: '#F7EFDE', border: '1px solid #E9DAB5', borderRadius: 4, padding: '10px 12px', fontSize: 12.5, color: '#8F5C12', marginBottom: 18 }}>
          Fast-path order. Budget check only — auto-approved if budget available.
        </div>

        <button className="btn btn--primary btn--block btn--lg" onClick={() => onPlace(cart, notes, total)}>
          Place order{total > 0 ? ` — ${fmt(total)}` : ''}
        </button>
      </div>
    </div>
  )
}

// ─── Catalog ──────────────────────────────────────────────────────────────────
const CatalogScreen = ({ cart, onAddToCart, onOpenCart }) => {
  const [activeCat, setActiveCat] = useState(CATALOG[0].category)
  const cat = CATALOG.find(c => c.category === activeCat)
  const cartCount = cart.reduce((s, l) => s + l.qty, 0)

  return (
    <div className="content step-in" style={{ maxWidth: 1180 }}>
      <div className="pagehead">
        <div>
          <div className="pagehead__eyebrow">Catalog</div>
          <h1 className="pagehead__title">Pre-negotiated.</h1>
          <div className="pagehead__sub">Contract on file. Budget check only. Order completes the same day.</div>
        </div>
        <div className="pagehead__actions">
          {cartCount > 0 && (
            <button className="btn btn--ink btn--lg" onClick={onOpenCart}>
              <IconBag size={15} />
              Review order — {cartCount} item{cartCount !== 1 ? 's' : ''}
            </button>
          )}
        </div>
      </div>

      <div className="tabs">
        {CATALOG.map(c => (
          <button key={c.category} className={'tab' + (activeCat === c.category ? ' tab--active' : '')} onClick={() => setActiveCat(c.category)}>
            {c.category}
          </button>
        ))}
      </div>

      <div className="cat-grid">
        {cat.items.map(item => {
          const inCart = cart.find(l => l.item.id === item.id)
          return (
            <div key={item.id} className="cat-item" style={inCart ? { borderColor: '#B07219', boxShadow: '0 0 0 1px #B07219' } : {}}>
              <div className="cat-item__name">{item.name}</div>
              <div className="cat-item__desc">{item.desc}</div>
              <div className="cat-item__meta">
                <span>{item.supplier}</span>
                <span style={{ width: 3, height: 3, borderRadius: '50%', background: '#C9BFAE', display: 'inline-block' }} />
                <span className="ref" style={{ color: '#A89B8B' }}>{item.sku}</span>
              </div>
              <div className="cat-item__foot">
                <span className="cat-item__price">
                  {item.variable ? 'Variable' : fmt(item.price)}
                  {item.per && !item.variable && <span className="cat-item__price-mo">{item.per}</span>}
                </span>
                {inCart ? (
                  <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                    <button className="btn btn--secondary btn--sm" style={{ width: 28, height: 28, padding: 0 }} onClick={() => onAddToCart(item, -1)}>
                      <IconMinus size={12} />
                    </button>
                    <span style={{ minWidth: 20, textAlign: 'center', fontSize: 13, fontWeight: 600, color: '#161413', fontVariantNumeric: 'tabular-nums' }}>{inCart.qty}</span>
                    <button className="btn btn--primary btn--sm" style={{ width: 28, height: 28, padding: 0 }} onClick={() => onAddToCart(item, 1)}>
                      <IconPlus size={12} />
                    </button>
                  </div>
                ) : (
                  <button className="btn btn--secondary btn--sm" onClick={() => onAddToCart(item, 1)}>Add</button>
                )}
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}

// ─── Orders Board ─────────────────────────────────────────────────────────────
const PO_SECTIONS = [
  { id: 'active',    label: 'In flight',      statuses: ['sent','acknowledged'],  hint: 'Sent to supplier — awaiting delivery.' },
  { id: 'delivered', label: 'Pending invoice', statuses: ['delivered'],            hint: 'Goods received — invoice expected.' },
  { id: 'invoiced',  label: 'Invoiced',        statuses: ['invoiced'],             hint: 'Invoice matched — payment instruction pending.' },
  { id: 'closed',    label: 'Closed',          statuses: ['closed','draft'],       hint: 'Completed or draft POs.' },
]

const OrdersBoard = ({ onCountChange }) => {
  const [pos,    setPos]    = useState(null)
  const [openId, setOpenId] = useState(null)
  const [filter, setFilter] = useState('active')  // 'active' | 'all'

  const load = useCallback(async () => {
    try {
      const data = await pgFetch('/purchase_orders_board?order=sort_order.asc,created_at.desc')
      setPos(data)
      const live = data.filter(p => ['sent','acknowledged','delivered','invoiced'].includes(p.po_status))
      onCountChange(live.length)
    } catch {
      setPos([])
      onCountChange(0)
    }
  }, [onCountChange])

  useEffect(() => { load() }, [load])

  const today = new Date().toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric' })

  if (pos === null) return (
    <div className="content content--with-rail step-in">
      <div style={{ padding: '80px 0', textAlign: 'center', color: '#75695F' }}>Loading…</div>
    </div>
  )

  const displayed = filter === 'active'
    ? pos.filter(p => ['sent','acknowledged','delivered','invoiced'].includes(p.po_status))
    : pos

  const totalValue = displayed.reduce((s, p) => s + parseFloat(p.amount_eur || 0), 0)
  const sections   = PO_SECTIONS.filter(sec =>
    filter === 'all' || sec.id !== 'closed'
  )

  return (
    <div className="content step-in" style={{ maxWidth: 1180 }}>
      {/* Header */}
      <div className="pagehead">
        <div>
          <div className="pagehead__eyebrow">Orders · {today}</div>
          <h1 className="pagehead__title">
            {displayed.length} {displayed.length === 1 ? 'order' : 'orders'}.
          </h1>
          <div className="pagehead__sub">Every approved purchase order. Immutable — no deletions.</div>
        </div>
        <div className="pagehead__actions">
          <button className={`btn btn--sm ${filter === 'active' ? 'btn--ink' : 'btn--tertiary'}`} onClick={() => setFilter('active')}>In flight</button>
          <button className={`btn btn--sm ${filter === 'all'    ? 'btn--ink' : 'btn--tertiary'}`} onClick={() => setFilter('all')}>All orders</button>
          <button className="btn btn--tertiary btn--sm" onClick={load}><IconRotateCw size={14}/></button>
        </div>
      </div>

      {/* Stats strip */}
      <div className="stats" style={{ marginBottom: 24 }}>
        <div className="stat">
          <div className="stat__label">In flight</div>
          <div className="stat__val">{pos.filter(p=>['sent','acknowledged'].includes(p.po_status)).length}</div>
          <div className="stat__hint">Sent, awaiting delivery</div>
        </div>
        <div className="stat">
          <div className="stat__label">Pending invoice</div>
          <div className="stat__val">{pos.filter(p=>p.po_status==='delivered').length}</div>
          <div className="stat__hint">Delivered, invoice due</div>
        </div>
        <div className="stat">
          <div className="stat__label">Total value</div>
          <div className="stat__val">{fmt(totalValue)}</div>
          <div className="stat__hint">{filter === 'active' ? 'In-flight orders' : 'All open orders'}</div>
        </div>
        <div className="stat">
          <div className="stat__label">Overdue</div>
          <div className="stat__val stat__val--gold">
            {pos.filter(p => p.expected_delivery && new Date(p.expected_delivery) < new Date() && ['sent','acknowledged'].includes(p.po_status)).length}
          </div>
          <div className="stat__hint">Past expected delivery</div>
        </div>
      </div>

      {/* Sections */}
      {sections.map(sec => {
        const inSec = displayed.filter(p => sec.statuses.includes(p.po_status))
        if (!inSec.length) return null
        return (
          <section key={sec.id} className="section" style={{ marginBottom: 24 }}>
            <div className="section__head">
              <span className="section__icon"><IconPackage size={16}/></span>
              <span className="section__title">{sec.label}</span>
              <span className="section__count">{inSec.length}</span>
              <span className="section__hint">{sec.hint}</span>
            </div>
            <div className="tlist">
              {/* Header row */}
              <div className="trow" style={{ background: '#EFEBE1', cursor: 'default', fontSize: 11, fontWeight: 600, letterSpacing: '0.1em', textTransform: 'uppercase', color: '#75695F' }}>
                <div>Status</div>
                <div>Order</div>
                <div>Supplier</div>
                <div style={{ textAlign: 'right' }}>Value</div>
                <div style={{ textAlign: 'right' }}>Expected</div>
              </div>
              {inSec.map(po => {
                const isOpen = openId === po.id
                const overdue = po.expected_delivery && new Date(po.expected_delivery) < new Date() && ['sent','acknowledged'].includes(po.po_status)
                return (
                  <div key={po.id}>
                    <div className="trow" style={{ cursor: 'pointer' }} onClick={() => setOpenId(isOpen ? null : po.id)}>
                      <div><PoStatusPill status={po.po_status} /></div>
                      <div className="trow__main">
                        <div className="trow__title" style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                          <span style={{ fontFamily: "'Geist Mono', monospace", fontSize: 12, color: '#8F5C12', fontWeight: 700 }}>{po.po_number}</span>
                          {po.pdf_url && (
                            <a href={po.pdf_url} target="_blank" rel="noreferrer"
                              onClick={e => e.stopPropagation()}
                              style={{ display: 'inline-flex', alignItems: 'center', gap: 3, fontSize: 11, color: '#2B5F7A', textDecoration: 'none', padding: '1px 6px', borderRadius: 3, background: '#E6EEF2', border: '1px solid #C5D5DE' }}>
                              <IconFile size={10}/> PDF
                            </a>
                          )}
                        </div>
                        <div className="trow__meta">
                          <span>{po.description?.substring(0, 55)}</span>
                          {po.ticket_reference && <><span className="dot"/><span className="ref">{po.ticket_reference}</span></>}
                          {po.branch_name && <><span className="dot"/><span>{po.branch_name}</span></>}
                        </div>
                      </div>
                      <div>
                        <div className="trow__supplier">{po.supplier_name || '—'}</div>
                        {po.submitted_by && <div className="trow__supplier-meta">{po.submitted_by}</div>}
                      </div>
                      <div style={{ textAlign: 'right' }}>
                        <div className="trow__value">{po.amount_eur ? fmt(po.amount_eur) : '—'}</div>
                        {po.currency && po.currency !== 'EUR' && <div style={{ fontSize: 11, color: '#A89B8B' }}>{po.currency}</div>}
                      </div>
                      <div style={{ textAlign: 'right', display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: 6 }}>
                        {po.expected_delivery ? (
                          <span style={{ fontSize: 12, color: overdue ? '#B5462E' : '#75695F', fontWeight: overdue ? 600 : 400 }}>
                            {overdue ? '⚠ ' : ''}{new Date(po.expected_delivery).toLocaleDateString('en-GB', { day: 'numeric', month: 'short' })}
                          </span>
                        ) : <span style={{ fontSize: 12, color: '#C9BFAE' }}>—</span>}
                        <IconChevDown size={14} style={{ color: '#A89B8B', transform: isOpen ? 'rotate(180deg)' : 'none', transition: 'transform 0.15s', flexShrink: 0 }} />
                      </div>
                    </div>

                    {/* Expanded PO detail */}
                    {isOpen && (
                      <div style={{ padding: '18px 24px 22px', background: '#FDFAF5', borderTop: '1px solid #EEE7DA' }}>
                        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 24 }}>
                          {/* Left: order detail */}
                          <div>
                            <div style={{ fontSize: 10.5, fontWeight: 600, letterSpacing: '0.14em', textTransform: 'uppercase', color: '#75695F', marginBottom: 12 }}>Order detail</div>
                            <div style={{ display: 'flex', flexDirection: 'column', gap: 7 }}>
                              {[
                                ['PO Number',   po.po_number],
                                ['Supplier',    po.supplier_name],
                                ['Branch',      po.branch_name],
                                ['Category',    po.category],
                                ['PO Date',     po.po_date ? new Date(po.po_date).toLocaleDateString('en-GB') : '—'],
                                ['Expected',    po.expected_delivery ? new Date(po.expected_delivery).toLocaleDateString('en-GB') : '—'],
                                ['Delivered',   po.delivered_at ? new Date(po.delivered_at).toLocaleDateString('en-GB') : '—'],
                                ['Value',       po.amount_eur ? fmt(po.amount_eur) : '—'],
                                ['Requested by',po.submitted_by || '—'],
                                ['Ticket',      po.ticket_reference || '—'],
                              ].map(([label, val]) => (
                                <div key={label} style={{ display: 'flex', gap: 12, fontSize: 12.5 }}>
                                  <span style={{ minWidth: 100, color: '#75695F', flexShrink: 0 }}>{label}</span>
                                  <span style={{ color: '#161413', fontWeight: 500 }}>{val}</span>
                                </div>
                              ))}
                            </div>
                          </div>
                          {/* Right: description + notes + PDF */}
                          <div>
                            <div style={{ fontSize: 10.5, fontWeight: 600, letterSpacing: '0.14em', textTransform: 'uppercase', color: '#75695F', marginBottom: 12 }}>Description</div>
                            <div style={{ fontSize: 13, color: '#3D3633', lineHeight: 1.6, marginBottom: 16 }}>
                              {po.description || '—'}
                            </div>
                            {po.notes && (
                              <>
                                <div style={{ fontSize: 10.5, fontWeight: 600, letterSpacing: '0.14em', textTransform: 'uppercase', color: '#75695F', marginBottom: 8 }}>Notes</div>
                                <div style={{ fontSize: 12.5, color: '#75695F', lineHeight: 1.5 }}>{po.notes}</div>
                              </>
                            )}
                            {po.pdf_url ? (
                              <a href={po.pdf_url} target="_blank" rel="noreferrer" style={{ display: 'inline-flex', alignItems: 'center', gap: 6, marginTop: 14, padding: '8px 14px', borderRadius: 6, background: '#161413', color: '#F7F4ED', fontSize: 12.5, fontWeight: 600, textDecoration: 'none' }}>
                                <IconFile size={13}/> Download PO PDF
                              </a>
                            ) : (
                              <div style={{ marginTop: 14, padding: '10px 12px', borderRadius: 6, background: '#F5F1EA', border: '1px solid #E5DDD0', fontSize: 12, color: '#A89B8B' }}>
                                PDF not yet generated — available once PO is sent to supplier.
                              </div>
                            )}
                          </div>
                        </div>
                      </div>
                    )}
                  </div>
                )
              })}
            </div>
          </section>
        )
      })}

      {displayed.length === 0 && (
        <div style={{ background: '#FFFEFB', border: '1px solid #E5DDD0', borderRadius: 8, padding: '64px 24px', textAlign: 'center' }}>
          <h2 style={{ fontFamily: "'Instrument Serif', serif", fontSize: 28, color: '#161413', margin: '0 0 8px' }}>No orders yet.</h2>
          <p style={{ fontSize: 13.5, color: '#75695F' }}>Approved requests generate a PO automatically.</p>
        </div>
      )}
    </div>
  )
}

// ─── Signal badge ──────────────────────────────────────────────────────────────
const SIGNAL_LABEL = { policy: 'Policy', supplier: 'Supplier', contract: 'Contract', request: 'Request', consumption: 'Budget' }

const SignalBadge = ({ signal, green, weight, notes }) => (
  <div style={{
    display: 'flex', alignItems: 'flex-start', gap: 10,
    padding: '10px 14px', borderRadius: 6,
    background: green ? '#EEF3EE' : '#F6E5DE',
    border: `1px solid ${green ? '#C5D9C8' : '#E8C3B5'}`,
    fontSize: 12.5,
  }}>
    <span style={{
      flexShrink: 0, width: 18, height: 18, borderRadius: '50%',
      background: green ? '#3D7A5A' : '#B5462E',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      marginTop: 1,
    }}>
      {green
        ? <svg width="9" height="9" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"><path d="M5 12l5 5L20 7"/></svg>
        : <svg width="8" height="8" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"><path d="M18 6L6 18M6 6l12 12"/></svg>
      }
    </span>
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: notes ? 2 : 0 }}>
        <span style={{ fontWeight: 600, color: '#161413', letterSpacing: '-0.01em' }}>
          {SIGNAL_LABEL[signal] || signal}
        </span>
        <span style={{ fontSize: 11, color: '#A89B8B', fontVariantNumeric: 'tabular-nums' }}>
          {Math.round(parseFloat(weight) * 100)}%
        </span>
      </div>
      {notes && <div style={{ color: '#4A4340', lineHeight: 1.45 }}>{notes}</div>}
    </div>
  </div>
)

// ─── Request detail panel ──────────────────────────────────────────────────────
const RequestDetail = ({ ticket }) => {
  const [detail, setDetail] = useState(null)  // { decision, signals }

  useEffect(() => {
    pgFetch(`/decisions?ticket_id=eq.${ticket.id}&order=created_at.desc&limit=1`)
      .then(async (decisions) => {
        if (!decisions.length) { setDetail({}); return }
        const dec = decisions[0]
        const signals = await pgFetch(`/trace_log?decision_id=eq.${dec.id}&order=created_at.asc`)
        setDetail({ decision: dec, signals })
      })
      .catch(() => setDetail({}))
  }, [ticket.id])

  // Parse description into line items (format: "Name × qty (SKU), ...")
  const parseItems = (desc) => {
    if (!desc) return null
    // Try to detect catalog item format: "Name × N (SKU)"
    const parts = desc.split(/,\s*(?=[A-Z])/)
    if (parts.length > 1 && parts[0].includes('×')) return parts
    return null
  }

  const items = parseItems(ticket.description)
  const DISP_LABEL = { auto_execute: 'Auto-executed', one_touch: 'One-touch', escalate: 'Escalated', auto_approved: 'Auto-approved' }
  const DISP_COLOR = { auto_execute: '#3D7A5A', one_touch: '#B07219', escalate: '#2B5F7A' }

  return (
    <div style={{ padding: '20px 24px 24px', background: '#FDFAF5', borderTop: '1px solid #EEE7DA' }}>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 24 }}>

        {/* Left: What was ordered */}
        <div>
          <div style={{ fontSize: 10.5, fontWeight: 600, letterSpacing: '0.14em', textTransform: 'uppercase', color: '#75695F', marginBottom: 12 }}>
            What was ordered
          </div>
          {items ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
              {items.map((line, i) => {
                const m = line.match(/^(.+?)\s*×\s*(\d+)\s*(?:\(([^)]+)\))?/)
                if (!m) return <div key={i} style={{ fontSize: 13, color: '#3D3633' }}>{line}</div>
                const [, name, qty, sku] = m
                return (
                  <div key={i} style={{
                    display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                    padding: '9px 12px', background: '#FFFEFB',
                    border: '1px solid #E5DDD0', borderRadius: 6,
                  }}>
                    <div>
                      <div style={{ fontSize: 13, fontWeight: 600, color: '#161413', letterSpacing: '-0.005em' }}>{name.trim()}</div>
                      {sku && <div style={{ fontSize: 11, color: '#A89B8B', fontFamily: "'Geist Mono', monospace", marginTop: 1 }}>{sku}</div>}
                    </div>
                    <div style={{ fontSize: 12, fontWeight: 700, color: '#3D3633', letterSpacing: '-0.01em' }}>× {qty}</div>
                  </div>
                )
              })}
            </div>
          ) : (
            <div style={{ fontSize: 13.5, color: '#3D3633', lineHeight: 1.6, padding: '10px 0' }}>
              {ticket.description || ticket.title}
            </div>
          )}

          {ticket.category && (
            <div style={{ marginTop: 12, display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              <span style={{ fontSize: 11, padding: '3px 8px', borderRadius: 4, background: '#EFEBE1', color: '#75695F', fontWeight: 500 }}>
                {ticket.category}
              </span>
              {ticket.submitted_by && (
                <span style={{ fontSize: 11, padding: '3px 8px', borderRadius: 4, background: '#EFEBE1', color: '#75695F' }}>
                  {ticket.submitted_by}
                </span>
              )}
            </div>
          )}
        </div>

        {/* Right: Approval trail */}
        <div>
          <div style={{ fontSize: 10.5, fontWeight: 600, letterSpacing: '0.14em', textTransform: 'uppercase', color: '#75695F', marginBottom: 12 }}>
            Approval trail
          </div>

          {detail === null && (
            <div style={{ fontSize: 12.5, color: '#A89B8B', padding: '10px 0' }}>Loading…</div>
          )}

          {detail !== null && !detail.decision && (() => {
            // Map status → step index (0-based) in the pipeline
            const STEPS = [
              { key: 'received',  label: 'Received',         sub: 'Ticket created in DB' },
              { key: 'reasoning', label: 'Agent reasoning',  sub: 'Running 5 signals via Claude' },
              { key: 'decision',  label: 'Decision written', sub: 'Disposition + confidence scored' },
              { key: 'routed',    label: 'Routed',           sub: 'Board updated or auto-executed' },
              { key: 'done',      label: 'Closed',           sub: 'Approved, rejected, or executed' },
            ]
            const STATUS_STEP = {
              reasoning:         1,
              pending_review:    3, pending_confirm: 3, signature_required: 3, escalated: 3,
              approved:          4, rejected: 4, auto_executed: 4, closed: 4,
            }
            const currentStep = STATUS_STEP[ticket.status] ?? 1
            const isStuck = ticket.status === 'reasoning'
            const stuckMin = Math.round((Date.now() - new Date(ticket.created_at)) / 60000)

            return (
              <div>
                {/* Pipeline steps */}
                <div style={{ display: 'flex', flexDirection: 'column', gap: 0 }}>
                  {STEPS.map((step, i) => {
                    const done    = i < currentStep
                    const active  = i === currentStep
                    const pending = i > currentStep
                    return (
                      <div key={step.key} style={{ display: 'flex', gap: 12, alignItems: 'stretch' }}>
                        {/* Timeline spine */}
                        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', width: 20, flexShrink: 0 }}>
                          <div style={{
                            width: 18, height: 18, borderRadius: '50%', flexShrink: 0,
                            background: done ? '#3D7A5A' : active ? (isStuck ? '#B07219' : '#2B5F7A') : '#E5DDD0',
                            border: `2px solid ${done ? '#3D7A5A' : active ? (isStuck ? '#B07219' : '#2B5F7A') : '#D4C9B8'}`,
                            display: 'flex', alignItems: 'center', justifyContent: 'center',
                            zIndex: 1,
                          }}>
                            {done && <svg width="8" height="8" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"><path d="M5 12l5 5L20 7"/></svg>}
                            {active && !isStuck && <div style={{ width: 6, height: 6, borderRadius: '50%', background: 'white' }} />}
                            {active && isStuck && <div style={{ width: 6, height: 6, borderRadius: '50%', background: 'white' }} />}
                          </div>
                          {i < STEPS.length - 1 && (
                            <div style={{
                              width: 2, flex: 1, minHeight: 16,
                              background: done ? '#3D7A5A' : '#E5DDD0',
                              margin: '2px 0',
                            }} />
                          )}
                        </div>

                        {/* Step label */}
                        <div style={{ paddingBottom: i < STEPS.length - 1 ? 14 : 0, paddingTop: 0, flex: 1 }}>
                          <div style={{
                            fontSize: 12.5, fontWeight: active ? 700 : done ? 600 : 400,
                            color: done ? '#3D7A5A' : active ? (isStuck ? '#8F5C12' : '#161413') : '#A89B8B',
                            letterSpacing: '-0.005em',
                            display: 'flex', alignItems: 'center', gap: 6,
                          }}>
                            {step.label}
                            {active && isStuck && (
                              <span style={{
                                fontSize: 10, padding: '1px 6px', borderRadius: 3,
                                background: '#F7EFDE', color: '#8F5C12', border: '1px solid #E9DAB5',
                                fontWeight: 600, letterSpacing: '0.04em',
                              }}>
                                STUCK {stuckMin}m
                              </span>
                            )}
                            {active && !isStuck && (
                              <span style={{
                                fontSize: 10, padding: '1px 6px', borderRadius: 3,
                                background: '#E6EEF2', color: '#2B5F7A', border: '1px solid #C5D5DE',
                                fontWeight: 600, letterSpacing: '0.04em',
                              }}>
                                NOW
                              </span>
                            )}
                          </div>
                          <div style={{ fontSize: 11.5, color: pending ? '#C9BFAE' : '#75695F', marginTop: 1 }}>{step.sub}</div>
                        </div>
                      </div>
                    )
                  })}
                </div>

                {/* Stuck explanation */}
                {isStuck && (
                  <div style={{
                    marginTop: 14, padding: '10px 12px', borderRadius: 6,
                    background: '#F7EFDE', border: '1px solid #E9DAB5',
                    fontSize: 12, color: '#8F5C12', lineHeight: 1.5,
                  }}>
                    The agent received the request but hasn't written a decision yet. This usually means the n8n workflow is still running or hit an error. The Operations Board will update automatically once it completes.
                  </div>
                )}
              </div>
            )
          })()}

          {detail?.decision && (
            <>
              {/* Decision summary */}
              <div style={{
                padding: '12px 14px', borderRadius: 6, marginBottom: 12,
                background: '#FFFEFB', border: '1px solid #E5DDD0',
              }}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 6 }}>
                  <span style={{
                    fontSize: 12, fontWeight: 700, letterSpacing: '-0.005em',
                    color: DISP_COLOR[detail.decision.disposition] || '#3D3633',
                  }}>
                    {DISP_LABEL[detail.decision.disposition] || detail.decision.disposition}
                  </span>
                  <span style={{ fontSize: 12, color: '#75695F', fontVariantNumeric: 'tabular-nums' }}>
                    {Math.round(parseFloat(detail.decision.confidence) * 100)}% confidence
                  </span>
                </div>
                {detail.decision.recommendation && (
                  <div style={{ fontSize: 12.5, color: '#3D3633', lineHeight: 1.45 }}>
                    {detail.decision.recommendation}
                  </div>
                )}
                {detail.decision.reasoning && (
                  <div style={{ fontSize: 12, color: '#75695F', lineHeight: 1.45, marginTop: 6, borderTop: '1px solid #EEE7DA', paddingTop: 6 }}>
                    {detail.decision.reasoning}
                  </div>
                )}
              </div>

              {/* Signal cards */}
              {detail.signals?.length > 0 && (
                <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                  {detail.signals.map((s, i) => (
                    <SignalBadge key={i} signal={s.signal} green={s.green} weight={s.weight} notes={s.notes} />
                  ))}
                </div>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  )
}

// ─── My Requests ──────────────────────────────────────────────────────────────
const MyRequestsScreen = ({ user }) => {
  const [tickets, setTickets] = useState(null)
  const [openId,  setOpenId]  = useState(null)

  const load = useCallback(() => {
    if (!user?.email) { setTickets([]); return }
    pgFetch(`/tickets?submitted_by_email=eq.${encodeURIComponent(user.email)}&order=created_at.desc&limit=50`)
      .then(setTickets)
      .catch(() => setTickets([]))
  }, [user?.email])

  useEffect(() => { load() }, [load])

  return (
    <div className="content step-in" style={{ maxWidth: 1180 }}>
      <div className="pagehead">
        <div>
          <div className="pagehead__eyebrow">My requests</div>
          <h1 className="pagehead__title">{tickets ? `${tickets.length} total.` : 'Loading…'}</h1>
          <div className="pagehead__sub">Everything you've submitted, with where the agent took it.</div>
        </div>
        <div className="pagehead__actions">
          <button className="btn btn--tertiary" onClick={() => { setTickets(null); load() }}>
            <IconRotateCw size={14}/> Refresh
          </button>
        </div>
      </div>

      {tickets && tickets.length > 0 && (
        <div className="tlist" style={{ marginTop: 0 }}>
          <div className="trow" style={{ background: '#EFEBE1', borderBottom: '1px solid #E5DDD0', cursor: 'default' }}>
            <div className="eyebrow">Status</div>
            <div className="eyebrow">Request</div>
            <div className="eyebrow">Supplier</div>
            <div className="eyebrow" style={{ textAlign: 'right' }}>Value</div>
            <div className="eyebrow" style={{ textAlign: 'right' }}>Ref</div>
          </div>
          {tickets.map(t => (
            <div key={t.id}>
              <div
                className="trow"
                style={{ cursor: 'pointer' }}
                onClick={() => setOpenId(openId === t.id ? null : t.id)}
              >
                <div><StatusPill status={t.status} /></div>
                <div className="trow__main">
                  <div className="trow__title">{t.title}</div>
                  <div className="trow__meta">
                    <span className="ref">{t.reference}</span>
                    <span className="dot" />
                    <span>{timeAgo(t.created_at)}</span>
                  </div>
                </div>
                <div><div className="trow__supplier">{t.supplier_name || '—'}</div></div>
                <div><div className="trow__value">{t.value_eur ? fmt(t.value_eur) : '—'}</div></div>
                <div style={{ textAlign: 'right', display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: 8 }}>
                  <span style={{ fontFamily: "'Geist Mono', monospace", fontSize: 12, color: '#8F5C12' }}>{t.reference}</span>
                  <IconChevDown size={14} style={{ color: '#A89B8B', transform: openId === t.id ? 'rotate(180deg)' : 'none', transition: 'transform 0.15s' }} />
                </div>
              </div>
              {openId === t.id && <RequestDetail ticket={t} />}
            </div>
          ))}
        </div>
      )}

      {tickets && tickets.length === 0 && (
        <div style={{ background: '#FFFEFB', border: '1px solid #E5DDD0', borderRadius: 8, padding: '64px 24px', textAlign: 'center' }}>
          <h2 style={{ fontFamily: "'Instrument Serif', serif", fontSize: 28, letterSpacing: '-0.025em', color: '#161413', margin: '0 0 8px' }}>No requests yet.</h2>
          <p style={{ fontSize: 13.5, color: '#75695F' }}>Everything you submit will appear here.</p>
        </div>
      )}
    </div>
  )
}

// ─── Request Form ──────────────────────────────────────────────────────────────
const RequestForm = ({ type, user, onBack, onSuccess }) => {
  const cfg = FORM_CONFIG[type] || FORM_CONFIG.other
  const [loading, setLoading] = useState(false)
  const [supplier, setSupplier] = useState('')
  const [amount,   setAmount]   = useState('')
  const [desc,     setDesc]     = useState('')
  const [notes,    setNotes]    = useState('')
  const [category, setCategory] = useState('hardware')

  const submit = async () => {
    if (loading) return
    setLoading(true)
    const ref = 'TS-' + new Date().getFullYear() + '-' + String(Math.floor(Math.random() * 9000) + 1000)
    try {
      await fetch(N8N_WEBHOOK, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          title: supplier ? `${type === 'purchase' ? 'Purchase' : type === 'renew' ? 'Renew' : type === 'onboard' ? 'Onboard' : 'Request'} — ${supplier}` : desc || 'New request',
          description: desc || notes || '',
          ticket_type: type,
          submitted_by: user?.name || '',
          submitted_by_email: user?.email || '',
          supplier_name: supplier,
          value_eur: parseFloat(amount) || 0,
          category,
          branch_id: user?.branchId || null,
        })
      })
      onSuccess(ref)
    } catch {
      onSuccess(ref)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="content step-in" style={{ maxWidth: 680 }}>
      <button onClick={onBack} className="btn btn--tertiary btn--sm" style={{ marginBottom: 14, padding: '4px 8px' }}>
        <IconArrowL size={14} /> Back
      </button>
      <div className="pagehead">
        <div>
          <div className="pagehead__eyebrow">New request</div>
          <h1 className="pagehead__title">{cfg.title}.</h1>
          <div className="pagehead__sub">{cfg.hint} The agent runs five signals — most close without you.</div>
        </div>
      </div>

      <div className="card" style={{ padding: 28 }}>
        {type === 'purchase' && <>
          <div className="field">
            <label className="field__label">Supplier <span style={{ color: '#B07219', marginLeft: 2 }}>*</span></label>
            <input className="input" value={supplier} onChange={e => setSupplier(e.target.value)} placeholder="Supplier or vendor name" />
          </div>
          <div className="field">
            <label className="field__label">Amount <span style={{ color: '#B07219', marginLeft: 2 }}>*</span></label>
            <div style={{ position: 'relative' }}>
              <span style={{ position: 'absolute', left: 13, top: '50%', transform: 'translateY(-50%)', color: '#75695F', fontSize: 14 }}>€</span>
              <input className="input" style={{ paddingLeft: 28 }} value={amount} onChange={e => setAmount(e.target.value)} inputMode="decimal" placeholder="0" />
            </div>
          </div>
          <div className="field">
            <label className="field__label">Category</label>
            <select className="select" value={category} onChange={e => setCategory(e.target.value)}>
              <option value="hardware">Hardware</option>
              <option value="saas_license">Software / SaaS</option>
              <option value="cloud_compute">Cloud</option>
              <option value="professional_services">Services</option>
              <option value="other">Other</option>
            </select>
          </div>
          <div className="field">
            <label className="field__label">What's it for? <span style={{ color: '#B07219', marginLeft: 2 }}>*</span></label>
            <input className="input" value={desc} onChange={e => setDesc(e.target.value)} placeholder="Brief description" />
          </div>
          <div className="field">
            <label className="field__label">Business justification</label>
            <textarea className="textarea" rows={3} value={notes} onChange={e => setNotes(e.target.value)} placeholder="Why is this needed? What does it replace or enable?" />
          </div>
        </>}

        {type === 'renew' && <>
          <div className="field">
            <label className="field__label">Supplier <span style={{ color: '#B07219', marginLeft: 2 }}>*</span></label>
            <input className="input" value={supplier} onChange={e => setSupplier(e.target.value)} placeholder="Acme Corp" />
          </div>
          <div className="field">
            <label className="field__label">Contract value <span style={{ color: '#B07219', marginLeft: 2 }}>*</span></label>
            <div style={{ position: 'relative' }}>
              <span style={{ position: 'absolute', left: 13, top: '50%', transform: 'translateY(-50%)', color: '#75695F', fontSize: 14 }}>€</span>
              <input className="input" style={{ paddingLeft: 28 }} value={amount} onChange={e => setAmount(e.target.value)} inputMode="decimal" placeholder="0" />
            </div>
          </div>
          <div className="field">
            <label className="field__label">Notes</label>
            <textarea className="textarea" rows={3} value={notes} onChange={e => setNotes(e.target.value)} placeholder="Expiry, key terms, requested changes…" />
          </div>
        </>}

        {type === 'onboard' && <>
          <div className="field">
            <label className="field__label">Company name <span style={{ color: '#B07219', marginLeft: 2 }}>*</span></label>
            <input className="input" value={supplier} onChange={e => setSupplier(e.target.value)} placeholder="New Vendor Ltd" />
          </div>
          <div className="field">
            <label className="field__label">Country <span style={{ color: '#B07219', marginLeft: 2 }}>*</span></label>
            <input className="input" value={desc} onChange={e => setDesc(e.target.value)} placeholder="e.g. Germany" />
          </div>
          <div className="field">
            <label className="field__label">Category <span style={{ color: '#B07219', marginLeft: 2 }}>*</span></label>
            <select className="select" value={category} onChange={e => setCategory(e.target.value)}>
              <option value="hardware">Hardware</option>
              <option value="saas_license">SaaS</option>
              <option value="cloud_compute">Cloud</option>
              <option value="professional_services">Services</option>
              <option value="other">Other</option>
            </select>
          </div>
          <div className="field">
            <label className="field__label">Justification <span style={{ color: '#B07219', marginLeft: 2 }}>*</span></label>
            <textarea className="textarea" rows={3} value={notes} onChange={e => setNotes(e.target.value)} placeholder="Why do we need this vendor?" />
          </div>
        </>}

        {type === 'other' && <>
          <div className="field">
            <label className="field__label">Title <span style={{ color: '#B07219', marginLeft: 2 }}>*</span></label>
            <input className="input" value={supplier} onChange={e => setSupplier(e.target.value)} placeholder="Short summary" />
          </div>
          <div className="field">
            <label className="field__label">Description <span style={{ color: '#B07219', marginLeft: 2 }}>*</span></label>
            <textarea className="textarea" rows={4} value={desc} onChange={e => setDesc(e.target.value)} placeholder="What do you need and why?" />
          </div>
        </>}

        <div style={{ background: '#EFEBE1', border: '1px solid #E5DDD0', borderRadius: 4, padding: '10px 12px', fontSize: 12.5, color: '#75695F', marginBottom: 18, lineHeight: 1.5 }}>
          Full review — five signals, then auto-execute or one-touch decision. Median time to resolution: 4 minutes.
        </div>

        <button className="btn btn--primary btn--block btn--lg" onClick={submit} disabled={loading}>
          {loading ? 'Submitting…' : 'Submit request'}
        </button>
      </div>
    </div>
  )
}

// ─── Success ──────────────────────────────────────────────────────────────────
const SuccessScreen = ({ result, onDone }) => (
  <div className="content step-in" style={{ maxWidth: 680 }}>
    <div className="success">
      <svg width="88" height="88" viewBox="0 0 88 88" fill="none">
        <circle cx="44" cy="44" r="40" stroke="#3D7A5A" strokeWidth="1.5" className="success__circle" />
        <path d="M28 45 l11 11 21-22" stroke="#3D7A5A" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" className="success__mark" />
      </svg>
      <h1 className="success__h">
        {result.isOrder ? <>Order placed. <em>That's it.</em></> : <>Submitted. <em>The agent's on it.</em></>}
      </h1>
      <div className="success__ref">
        <span className="success__ref-label">Ref</span>
        <span className="success__ref-val">{result.ref}</span>
      </div>
      <p className="success__msg">
        {result.isOrder
          ? <>Budget check running. You'll hear back at <b>{result.email}</b>.</>
          : <>Five signals running. You'll hear back at <b>{result.email}</b>.</>
        }
      </p>
      <div style={{ marginTop: 32, display: 'flex', gap: 10 }}>
        <button className="btn btn--secondary" onClick={onDone}>Back to operations</button>
      </div>
    </div>
  </div>
)

// ─── User Setup Modal ──────────────────────────────────────────────────────────
const UserSetupModal = ({ onSave }) => {
  const [name,     setName]     = useState('')
  const [email,    setEmail]    = useState('')
  const [branchId, setBranchId] = useState(BRANCHES[0].id)
  const save = () => {
    if (!name.trim() || !email.trim()) return
    onSave({ name: name.trim(), email: email.trim(), branchId })
  }
  return (
    <div className="modal-scrim">
      <div className="modal">
        <div style={{ fontFamily: "'Instrument Serif', serif", fontSize: 28, letterSpacing: '-0.025em', color: '#161413', marginBottom: 6 }}>Welcome.</div>
        <div style={{ fontSize: 13, color: '#75695F', marginBottom: 24 }}>Tell us who you are — stored locally, never sent anywhere.</div>
        <div className="field">
          <label className="field__label">Your name</label>
          <input className="input" placeholder="Eva Müller" value={name} onChange={e => setName(e.target.value)} />
        </div>
        <div className="field">
          <label className="field__label">Work email</label>
          <input className="input" type="email" placeholder="eva@company.com" value={email} onChange={e => setEmail(e.target.value)} />
        </div>
        <div className="field">
          <label className="field__label">Branch</label>
          <select className="select" value={branchId} onChange={e => setBranchId(e.target.value)}>
            {BRANCHES.map(b => <option key={b.id} value={b.id}>{b.label}</option>)}
          </select>
        </div>
        <button className="btn btn--primary btn--block btn--lg" onClick={save}>Get started</button>
      </div>
    </div>
  )
}

// ─── App ──────────────────────────────────────────────────────────────────────
export default function App() {
  const [user,        setUser]        = useLocalStorage('truespend_user', null)
  const [tab,         setTab]         = useState('board')
  const [reqType,     setReqType]     = useState(null)
  const [success,     setSuccess]     = useState(null)
  const [boardCount,  setBoardCount]  = useState(0)
  const [ordersCount, setOrdersCount] = useState(0)
  const [sectionJump, setSectionJump] = useState(null)
  const [openByStatus, setOpenByStatus] = useState({})
  const [cart,        setCart]        = useState([])   // [{ item, qty }]
  const [cartOpen,    setCartOpen]    = useState(false)

  const navigate = (t) => { setTab(t); setReqType(null); setSuccess(null); setSectionJump(null) }
  const startRequest = (type) => { setReqType(type); setTab('request') }

  const handleAddToCart = (item, delta) => {
    setCart(prev => {
      const existing = prev.find(l => l.item.id === item.id)
      if (!existing) return delta > 0 ? [...prev, { item, qty: 1 }] : prev
      const newQty = existing.qty + delta
      if (newQty <= 0) return prev.filter(l => l.item.id !== item.id)
      return prev.map(l => l.item.id === item.id ? { ...l, qty: newQty } : l)
    })
  }

  const handleUpdateCartQty = (itemId, qty) => {
    if (qty <= 0) setCart(prev => prev.filter(l => l.item.id !== itemId))
    else setCart(prev => prev.map(l => l.item.id === itemId ? { ...l, qty } : l))
  }

  const placeOrder = async (cartLines, notes, total) => {
    setCartOpen(false)
    const ref = 'TS-' + new Date().getFullYear() + '-' + String(Math.floor(Math.random() * 9000) + 1000)
    const title = cartLines.length === 1
      ? `Purchase — ${cartLines[0].item.name}${cartLines[0].qty > 1 ? ` × ${cartLines[0].qty}` : ''}`
      : `Purchase — ${cartLines.length} catalog items`
    const desc = cartLines.map(l => `${l.item.name} × ${l.qty} (${l.item.sku})`).join(', ') + (notes ? `. Notes: ${notes}` : '')
    try {
      await fetch(N8N_WEBHOOK, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          title,
          description: desc,
          ticket_type: 'purchase',
          submitted_by: user?.name || '',
          submitted_by_email: user?.email || '',
          supplier_name: cartLines.length === 1 ? cartLines[0].item.supplier : 'Multiple',
          value_eur: total,
          category: 'hardware',
          branch_id: user?.branchId || null,
        })
      })
    } catch {}
    setCart([])
    setSuccess({ ref, email: user?.email, isOrder: true })
  }

  const handleCountChange = useCallback((count) => {
    setBoardCount(count)
  }, [])

  const crumbs = (() => {
    if (success)          return ['Submitted']
    if (tab === 'board')  return ['Operations']
    if (tab === 'orders') return ['Orders']
    if (tab === 'catalog')return ['Catalog']
    if (tab === 'mine')   return ['My requests']
    if (tab === 'home')   return ['New request']
    if (tab === 'request')return ['New request', FORM_CONFIG[reqType]?.title || 'Request']
    return ['Operations']
  })()

  const counts = { open: boardCount, orders: ordersCount }

  return (
    <>
      {!user && <UserSetupModal onSave={setUser} />}

      <div className="app">
        <Sidebar
          tab={tab}
          onNav={navigate}
          counts={counts}
          openByStatus={openByStatus}
          onJumpSection={(st) => { setTab('board'); setSectionJump(st) }}
          user={user}
          onSwitchUser={() => setUser(null)}
        />

        <main className="main">
          <TopBar crumbs={crumbs} cartCount={cart.reduce((s, l) => s + l.qty, 0)} onOpenCart={() => setCartOpen(true)} />

          {success && (
            <SuccessScreen result={success} onDone={() => { setSuccess(null); navigate('board') }} />
          )}

          {!success && tab === 'board' && (
            <OperationsBoard
              sectionJump={sectionJump}
              onCountChange={handleCountChange}
            />
          )}
          {!success && tab === 'orders'  && <OrdersBoard onCountChange={setOrdersCount} />}
          {!success && tab === 'catalog' && <CatalogScreen cart={cart} onAddToCart={handleAddToCart} onOpenCart={() => setCartOpen(true)} />}
          {!success && tab === 'mine'    && <MyRequestsScreen user={user} />}
          {!success && tab === 'home'    && <HomeScreen user={user} onCatalog={() => navigate('catalog')} onRequestType={startRequest} />}
          {!success && tab === 'request' && reqType && (
            <RequestForm
              type={reqType}
              user={user}
              onBack={() => navigate('home')}
              onSuccess={(ref) => setSuccess({ ref, email: user?.email, isOrder: false })}
            />
          )}
        </main>
      </div>

      {cartOpen && (
        <CartModal
          cart={cart}
          onClose={() => setCartOpen(false)}
          onUpdateQty={handleUpdateCartQty}
          onRemove={(id) => setCart(prev => prev.filter(l => l.item.id !== id))}
          onPlace={placeOrder}
        />
      )}
    </>
  )
}
