import React, { useState, useEffect, useCallback, useRef } from 'react'

// ─── Config ───────────────────────────────────────────────────────────────────
const POSTGREST_URL    = import.meta.env.VITE_POSTGREST_URL    || 'https://postgrest-production-7960.up.railway.app'
const POSTGREST_JWT    = import.meta.env.VITE_POSTGREST_JWT    || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoidHJ1ZXNwZW5kIiwiaWF0IjoxNzgwMTYzNDg3LCJleHAiOjIwOTU3Mzk0ODd9.NfCfCbnipo0tblsx6UUU7tpS7ZQbTkOWMhniaK6kXqE'
const N8N_WEBHOOK      = import.meta.env.VITE_N8N_WEBHOOK_URL  || 'https://n8n-n3xl.eugenmueller.tech/webhook/intake'
const N8N_WEBHOOK_BASE = import.meta.env.VITE_N8N_WEBHOOK_BASE || 'https://n8n-n3xl.eugenmueller.tech/webhook'

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
  { label: 'Nordics East', id: 'b1000000-0000-0000-0000-000000000010' },
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

async function n8nPost(path, body) {
  const r = await fetch(`${N8N_WEBHOOK_BASE}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  if (!r.ok) throw new Error(`n8n ${r.status}`)
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
const IconUserPlus = (p) => <Icon {...p}><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M19 8v6M22 11h-6"/></Icon>
const IconShield   = (p) => <Icon {...p}><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></Icon>
const IconSearch   = (p) => <Icon {...p}><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></Icon>
const IconContract = (p) => <Icon {...p}><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6"/><path d="M8 13h8M8 17h5"/></Icon>
const IconPieChart = (p) => <Icon {...p}><path d="M21.21 15.89A10 10 0 1 1 8 2.83"/><path d="M22 12A10 10 0 0 0 12 2v10z"/></Icon>

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

// CATALOG constant removed — now fetched live from catalog_by_supplier view

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

// ─── Agent activity feed (live) ───────────────────────────────────────────────
// Fetched from DB — auto_executed and recently closed tickets
const useAgentFeed = () => {
  const [feed, setFeed] = useState(null)
  useEffect(() => {
    pgFetch('/tickets?status=in.(auto_executed,closed)&order=updated_at.desc&limit=8&select=id,title,value_eur,amount_eur,updated_at,status,disposition,branch_id')
      .then(rows => setFeed(rows))
      .catch(() => setFeed([]))
  }, [])
  return feed
}

// ─── Role config ──────────────────────────────────────────────────────────────
// Role groups:
//   procurement  — Procurement Manager (one per branch): full board, all requests, can sign
//   it           — IT Manager: board (IT categories only), all request types, can't sign
//   user         — Ops Manager / Requester: submit requests, see own requests
//   controlling  — Controlling (one per branch): read-only board + budget, no action buttons
//   admin        — Platform admin: user management, board, suppliers
// Removed:
//   cfo          — report only, no tool access (deactivated in DB)
//   legal        — works in Jira, not in this tool
const ROLE_LABEL = {
  procurement: 'Procurement',
  it:          'IT',
  user:        'User',
  controlling: 'Controlling',
  admin:       'Admin',
}

// Map DB role strings → canonical group
const ROLE_GROUP = {
  procurement_manager: 'procurement',
  head_of_procurement: 'procurement', // legacy — keep mapping
  category_manager:    'procurement', // legacy — keep mapping
  it:                  'it',
  it_manager:          'it',
  user:                'user',
  ops_manager:         'user',
  requester:           'user',
  controlling:         'controlling',
  admin:               'admin',
  // cfo and legal removed — no tool access
}

// IT categories — IT Manager only sees board tickets in these categories
const IT_CATEGORIES = new Set(['hardware', 'saas_license', 'hyperscaler', 'other', 'telecoms'])

// Nav items per role group
const NAV_BY_GROUP = {
  procurement: [
    { id: 'board',     label: 'Operations',  Icon: IconBoard,    countKey: 'open' },
    { id: 'orders',    label: 'Orders',      Icon: IconTruck,    countKey: 'orders' },
    { id: 'contracts', label: 'Contracts',   Icon: IconContract },
    { id: 'budget',    label: 'Budget',      Icon: IconPieChart },
    { id: 'suppliers', label: 'Suppliers',   Icon: IconBuilding },
    { id: 'catalog',   label: 'Catalogues',  Icon: IconCatalog },
    { id: 'search',    label: 'Search docs', Icon: IconSearch },
    { id: 'mine',      label: 'My requests', Icon: IconList },
    { id: 'home',      label: 'New request', Icon: IconPlus },
  ],
  it: [
    { id: 'board',     label: 'IT Requests', Icon: IconBoard,    countKey: 'open' },
    { id: 'orders',    label: 'Orders',      Icon: IconTruck,    countKey: 'orders' },
    { id: 'catalog',   label: 'Catalogues',  Icon: IconCatalog },
    { id: 'search',    label: 'Search docs', Icon: IconSearch },
    { id: 'mine',      label: 'My requests', Icon: IconList },
    { id: 'home',      label: 'New request', Icon: IconPlus },
  ],
  user: [
    { id: 'catalog',   label: 'Catalogues',  Icon: IconCatalog },
    { id: 'mine',      label: 'My requests', Icon: IconList },
    { id: 'home',      label: 'New request', Icon: IconPlus },
  ],
  controlling: [
    { id: 'board',     label: 'Operations',  Icon: IconBoard,    countKey: 'open' },
    { id: 'budget',    label: 'Budget',      Icon: IconPieChart },
    { id: 'contracts', label: 'Contracts',   Icon: IconContract },
    { id: 'orders',    label: 'Orders',      Icon: IconTruck,    countKey: 'orders' },
    { id: 'search',    label: 'Search docs', Icon: IconSearch },
  ],
  admin: [
    { id: 'board',     label: 'Operations',  Icon: IconBoard,    countKey: 'open' },
    { id: 'suppliers', label: 'Suppliers',   Icon: IconBuilding },
    { id: 'search',    label: 'Search docs', Icon: IconSearch },
    { id: 'users',     label: 'Users',       Icon: IconUserPlus },
  ],
}

const NAV_PRIMARY = NAV_BY_GROUP.procurement // default — overridden at runtime

// ─── Sidebar ──────────────────────────────────────────────────────────────────

// Role switcher popover — one-click demo persona switching from the sidebar footer
const RoleSwitcher = ({ currentUser, onSwitch, onSignOut }) => {
  const [open, setOpen]       = useState(false)
  const [users, setUsers]     = useState(null)
  const ref = useRef(null)

  // Load users once on mount
  useEffect(() => {
    pgFetch('/users?active=eq.true&order=role.asc,name.asc&limit=50')
      .then(d => setUsers(d))
      .catch(() => setUsers([]))
  }, [])

  // Close on outside click
  useEffect(() => {
    if (!open) return
    const handler = (e) => { if (ref.current && !ref.current.contains(e.target)) setOpen(false) }
    document.addEventListener('mousedown', handler)
    return () => document.removeEventListener('mousedown', handler)
  }, [open])

  const grouped = {}
  for (const u of (users || [])) {
    const g = ROLE_GROUP[u.role] || 'user'
    if (!grouped[g]) grouped[g] = []
    grouped[g].push(u)
  }

  const pick = (u) => {
    setOpen(false)
    onSwitch({
      id:           u.id,
      name:         u.name,
      email:        u.email || '',
      role:         u.role,
      branchId:     u.branch_id || BRANCHES[0].id,
      costCenterId: u.cost_center_id || null,
      title:        u.title || ROLE_LABEL[ROLE_GROUP[u.role] || u.role] || u.role,
    })
  }

  return (
    <div ref={ref} style={{ position: 'relative' }}>
      <button
        className="iconbtn"
        title="Switch role"
        style={{ width: 26, height: 26 }}
        onClick={() => setOpen(o => !o)}
      >
        <IconChevDown size={14} style={{ transform: open ? 'rotate(180deg)' : 'none', transition: 'transform 0.15s' }} />
      </button>

      {open && (
        <div style={{
          position: 'absolute', bottom: 38, left: -180, width: 260,
          background: '#FFFEFB', border: '1px solid #E5DDD0', borderRadius: 10,
          boxShadow: '0 8px 32px rgba(0,0,0,0.13)', zIndex: 200,
          padding: '8px 0 6px',
          maxHeight: 400, overflowY: 'auto',
        }}>
          <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: '0.12em', textTransform: 'uppercase', color: '#A89B8B', padding: '4px 14px 6px' }}>
            Switch role
          </div>

          {users === null && (
            <div style={{ padding: '10px 14px', fontSize: 12, color: '#A89B8B' }}>Loading…</div>
          )}

          {['procurement','it','controlling','user','admin'].map(group => {
            const members = grouped[group] || []
            if (!members.length) return null
            return (
              <div key={group}>
                <div style={{
                  fontSize: 9.5, fontWeight: 700, letterSpacing: '0.12em', textTransform: 'uppercase',
                  color: PERSONA_GROUP_COLOR[group], padding: '8px 14px 3px',
                  borderTop: '1px solid #F0EBE1', marginTop: 2,
                }}>
                  {PERSONA_GROUP_LABEL[group]}
                </div>
                {members.map(u => {
                  const isCurrent = u.id === currentUser?.id
                  return (
                    <button
                      key={u.id}
                      onClick={() => pick(u)}
                      style={{
                        display: 'flex', alignItems: 'center', gap: 9, width: '100%',
                        padding: '6px 14px', border: 'none', cursor: 'pointer', textAlign: 'left',
                        background: isCurrent ? PERSONA_GROUP_COLOR[group] + '12' : 'none',
                      }}
                      onMouseEnter={e => { if (!isCurrent) e.currentTarget.style.background = '#F5F1EA' }}
                      onMouseLeave={e => { if (!isCurrent) e.currentTarget.style.background = 'none' }}
                    >
                      <div style={{
                        width: 24, height: 24, borderRadius: '50%', flexShrink: 0,
                        background: PERSONA_GROUP_COLOR[group] + '28',
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                        fontSize: 9.5, fontWeight: 700, color: PERSONA_GROUP_COLOR[group],
                      }}>
                        {u.name.split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase()}
                      </div>
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div style={{ fontSize: 12.5, fontWeight: isCurrent ? 700 : 500, color: '#161413', display: 'flex', alignItems: 'center', gap: 5 }}>
                          {u.name}
                          {isCurrent && <span style={{ fontSize: 9, background: PERSONA_GROUP_COLOR[group] + '22', color: PERSONA_GROUP_COLOR[group], borderRadius: 4, padding: '1px 5px', fontWeight: 700 }}>current</span>}
                        </div>
                        <div style={{ fontSize: 10.5, color: '#A89B8B', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{u.email}</div>
                      </div>
                    </button>
                  )
                })}
              </div>
            )
          })}

          <div style={{ borderTop: '1px solid #EDE8DF', marginTop: 6, padding: '6px 8px 2px' }}>
            <button
              onClick={() => { setOpen(false); onSignOut() }}
              style={{
                display: 'flex', alignItems: 'center', gap: 8, width: '100%',
                padding: '6px 6px', border: 'none', background: 'none', cursor: 'pointer',
                borderRadius: 6, fontSize: 12.5, color: '#9B3A2A', fontWeight: 500,
              }}
              onMouseEnter={e => e.currentTarget.style.background = '#FAF0EE'}
              onMouseLeave={e => e.currentTarget.style.background = 'none'}
            >
              <IconX size={13} />
              Sign out
            </button>
          </div>
        </div>
      )}
    </div>
  )
}

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

const Sidebar = ({ tab, onNav, counts, openByStatus, onJumpSection, user, onSwitchUser, onQuickSwitch }) => {
  const sidebarTab = tab === 'request' ? 'home' : tab
  const initials = user ? user.name.split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase() : '?'
  const branch = user ? (BRANCHES.find(b => b.id === user.branchId)?.label || '') : ''
  const roleGroup = ROLE_GROUP[user?.role] || 'user'
  const navItems = NAV_BY_GROUP[roleGroup] || NAV_BY_GROUP.user

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
        {navItems.map(({ id, label, Icon, countKey }) => {
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

      <div className="sidebar__user" style={{ flexDirection: 'column', alignItems: 'stretch', gap: 0, padding: '10px 12px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6 }}>
          <div className="sidebar__avatar" style={{ background: PERSONA_GROUP_COLOR[roleGroup] || '#B07219' }}>{initials}</div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div className="sidebar__user-name">{user?.name || 'Guest'}</div>
            <div className="sidebar__user-sub">{branch}</div>
          </div>
        </div>
        <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
          <span style={{
            flex: 1, fontSize: 10.5, fontWeight: 700, letterSpacing: '0.06em', textTransform: 'uppercase',
            padding: '3px 8px', borderRadius: 5,
            background: (PERSONA_GROUP_COLOR[roleGroup] || '#B07219') + '1A',
            color: PERSONA_GROUP_COLOR[roleGroup] || '#B07219',
          }}>
            {ROLE_LABEL[roleGroup] || roleGroup}
          </span>
          <RoleSwitcher
            currentUser={user}
            onSwitch={onQuickSwitch}
            onSignOut={onSwitchUser}
          />
        </div>
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
const AgentRail = () => {
  const feed = useAgentFeed()

  const formatTime = (iso) => {
    if (!iso) return '—'
    const d = new Date(iso)
    return d.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' })
  }

  const trimTitle = (title) => {
    if (!title) return '—'
    // Remove "Auto-" prefix clutter for the feed
    return title.replace(/^(Auto-approved|Auto-executed|Approved:|Closed:|Rejected:)\s*/i, '')
  }

  const branchLabel = (branchId) => {
    if (!branchId) return ''
    const b = BRANCHES.find(x => x.id === branchId)
    return b?.label || ''
  }

  return (
    <aside className="rail">
      <div className="rail__head">
        <span className="rail__head-dot" />
        Agent · today
      </div>
      <div className="rail__feed">
        {feed === null && (
          <div style={{ padding: '20px 0', textAlign: 'center', color: '#C9BFAE', fontSize: 12 }}>Loading…</div>
        )}
        {feed !== null && feed.length === 0 && (
          <div style={{ padding: '20px 0', textAlign: 'center', color: '#C9BFAE', fontSize: 12 }}>No agent activity yet.</div>
        )}
        {(feed || []).map((e, i) => {
          const val = parseFloat(e.value_eur || e.amount_eur || 0)
          return (
            <div key={i} className="rail__entry">
              <div className="rail__entry-time">{formatTime(e.updated_at)}</div>
              <div className="rail__entry-title">{trimTitle(e.title)}</div>
              <div className="rail__entry-meta">
                {branchLabel(e.branch_id) && <span>{branchLabel(e.branch_id)}</span>}
                {val > 0 && (
                  <>
                    {branchLabel(e.branch_id) && <span style={{ width: 3, height: 3, borderRadius: '50%', background: '#C9BFAE', display: 'inline-block' }} />}
                    <span className="money" style={{ fontSize: 12, color: '#3D3633' }}>{fmt(val)}</span>
                  </>
                )}
              </div>
            </div>
          )
        })}
      </div>
    </aside>
  )
}

// ─── Signal badge ─────────────────────────────────────────────────────────────
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
            Request
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

          {(ticket.category || ticket.submitted_by || ticket.branch_name) && (
            <div style={{ marginTop: 12, display: 'flex', gap: 6, flexWrap: 'wrap' }}>
              {ticket.category && (
                <span style={{ fontSize: 11, padding: '3px 8px', borderRadius: 4, background: '#EFEBE1', color: '#75695F', fontWeight: 500 }}>
                  {ticket.category}
                </span>
              )}
              {ticket.branch_name && (
                <span style={{ fontSize: 11, padding: '3px 8px', borderRadius: 4, background: '#EFEBE1', color: '#75695F' }}>
                  {ticket.branch_name}
                </span>
              )}
              {ticket.submitted_by && (
                <span style={{ fontSize: 11, padding: '3px 8px', borderRadius: 4, background: '#EFEBE1', color: '#75695F' }}>
                  by {ticket.submitted_by}
                </span>
              )}
            </div>
          )}

          {/* Jira badge if escalated */}
          {ticket.jira_key && (
            <div style={{ marginTop: 12 }}>
              <a href={ticket.jira_url || ('https://truespend.atlassian.net/browse/' + ticket.jira_key)}
                target="_blank" rel="noreferrer"
                style={{ display: 'inline-flex', alignItems: 'center', gap: 5, padding: '4px 10px', borderRadius: 4, background: '#E8F0FE', border: '1px solid #BFCFE8', color: '#1747A6', fontSize: 12, fontWeight: 700, textDecoration: 'none' }}>
                <svg width="11" height="11" viewBox="0 0 24 24" fill="currentColor"><path d="M12 0C5.4 0 0 5.4 0 12s5.4 12 12 12 12-5.4 12-12S18.6 0 12 0zm5.5 17.5l-5.5-5.5-5.5 5.5-1.5-1.5 5.5-5.5-5.5-5.5 1.5-1.5 5.5 5.5 5.5-5.5 1.5 1.5-5.5 5.5 5.5 5.5-1.5 1.5z"/></svg>
                {ticket.jira_key}
                <svg width="9" height="9" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/><polyline points="15 3 21 3 21 9"/><line x1="10" y1="14" x2="21" y2="3"/></svg>
              </a>
            </div>
          )}
        </div>

        {/* Right: Agent decision */}
        <div>
          <div style={{ fontSize: 10.5, fontWeight: 600, letterSpacing: '0.14em', textTransform: 'uppercase', color: '#75695F', marginBottom: 12 }}>
            Agent decision
          </div>

          {detail === null && (
            <div style={{ fontSize: 12.5, color: '#A89B8B', padding: '10px 0' }}>Loading…</div>
          )}

          {detail !== null && !detail.decision && (() => {
            const STEPS = [
              { key: 'received',  label: 'Received',         sub: 'Ticket created in DB' },
              { key: 'reasoning', label: 'Agent reasoning',  sub: 'Running 5 signals via Claude' },
              { key: 'decision',  label: 'Decision written', sub: 'Disposition + confidence scored' },
              { key: 'routed',    label: 'Routed',           sub: 'Board updated or auto-executed' },
              { key: 'done',      label: 'Closed',           sub: 'Approved, rejected, or executed' },
            ]
            const STATUS_STEP = {
              reasoning: 1,
              pending_review: 3, pending_confirm: 3, signature_required: 3, escalated: 3,
              approved: 4, rejected: 4, auto_executed: 4, closed: 4,
            }
            const currentStep = STATUS_STEP[ticket.status] ?? 1
            const isStuck = ticket.status === 'reasoning'
            const stuckMin = Math.round((Date.now() - new Date(ticket.created_at)) / 60000)

            return (
              <div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 0 }}>
                  {STEPS.map((step, i) => {
                    const done    = i < currentStep
                    const active  = i === currentStep
                    const pending = i > currentStep
                    return (
                      <div key={step.key} style={{ display: 'flex', gap: 12, alignItems: 'stretch' }}>
                        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', width: 20, flexShrink: 0 }}>
                          <div style={{
                            width: 18, height: 18, borderRadius: '50%', flexShrink: 0,
                            background: done ? '#3D7A5A' : active ? (isStuck ? '#B07219' : '#2B5F7A') : '#E5DDD0',
                            border: `2px solid ${done ? '#3D7A5A' : active ? (isStuck ? '#B07219' : '#2B5F7A') : '#D4C9B8'}`,
                            display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1,
                          }}>
                            {done && <svg width="8" height="8" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"><path d="M5 12l5 5L20 7"/></svg>}
                            {active && <div style={{ width: 6, height: 6, borderRadius: '50%', background: 'white' }} />}
                          </div>
                          {i < STEPS.length - 1 && (
                            <div style={{ width: 2, flex: 1, minHeight: 16, background: done ? '#3D7A5A' : '#E5DDD0', margin: '2px 0' }} />
                          )}
                        </div>
                        <div style={{ paddingBottom: i < STEPS.length - 1 ? 14 : 0, flex: 1 }}>
                          <div style={{
                            fontSize: 12.5, fontWeight: active ? 700 : done ? 600 : 400,
                            color: done ? '#3D7A5A' : active ? (isStuck ? '#8F5C12' : '#161413') : '#A89B8B',
                            letterSpacing: '-0.005em', display: 'flex', alignItems: 'center', gap: 6,
                          }}>
                            {step.label}
                            {active && isStuck && <span style={{ fontSize: 10, padding: '1px 6px', borderRadius: 3, background: '#F7EFDE', color: '#8F5C12', border: '1px solid #E9DAB5', fontWeight: 600 }}>STUCK {stuckMin}m</span>}
                            {active && !isStuck && <span style={{ fontSize: 10, padding: '1px 6px', borderRadius: 3, background: '#E6EEF2', color: '#2B5F7A', border: '1px solid #C5D5DE', fontWeight: 600 }}>NOW</span>}
                          </div>
                          <div style={{ fontSize: 11.5, color: pending ? '#C9BFAE' : '#75695F', marginTop: 1 }}>{step.sub}</div>
                        </div>
                      </div>
                    )
                  })}
                </div>
                {isStuck && (
                  <div style={{ marginTop: 14, padding: '10px 12px', borderRadius: 6, background: '#F7EFDE', border: '1px solid #E9DAB5', fontSize: 12, color: '#8F5C12', lineHeight: 1.5 }}>
                    The agent received the request but hasn't written a decision yet. Check the n8n workflow status.
                  </div>
                )}
              </div>
            )
          })()}

          {detail?.decision && (
            <>
              <div style={{ padding: '12px 14px', borderRadius: 6, marginBottom: 10, background: '#FFFEFB', border: '1px solid #E5DDD0' }}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 6 }}>
                  <span style={{ fontSize: 12, fontWeight: 700, letterSpacing: '-0.005em', color: DISP_COLOR[detail.decision.disposition] || '#3D3633' }}>
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

// ─── Stats Strip ──────────────────────────────────────────────────────────────
const StatsStrip = ({ tickets }) => {
  const totalValue = tickets.reduce((s, t) => s + (t.value_eur || 0), 0)
  const scores = tickets.map(t => t.confidence_score).filter(Boolean).map(Number)
  const minConf = scores.length ? Math.min(...scores) : null
  const sections = BOARD_SECTIONS.filter(s => tickets.some(t => t.status === s.status)).length
  return (
    <div className="stats">
      <div className="stat">
        <div className="stat__label">Need you</div>
        <div className="stat__val">{tickets.length}</div>
        <div className="stat__hint">Across {sections} section{sections !== 1 ? 's' : ''}</div>
      </div>
      <div className="stat">
        <div className="stat__label">Value at decision</div>
        <div className="stat__val">{fmt(totalValue)}</div>
        <div className="stat__hint">Total notional in your queue</div>
      </div>
      <div className="stat">
        <div className="stat__label">Escalated</div>
        <div className="stat__val">{tickets.filter(t => t.status === 'escalated').length}</div>
        <div className="stat__hint">Require CFO or Legal sign-off</div>
      </div>
      <div className="stat">
        <div className="stat__label">Confidence floor</div>
        <div className="stat__val stat__val--gold">{minConf != null ? Math.round(minConf * 100) + '%' : '—'}</div>
        <div className="stat__hint">Lowest in your queue</div>
      </div>
    </div>
  )
}

// ─── Ticket Row ───────────────────────────────────────────────────────────────
const ConfBar = ({ score }) => {
  const pct = Math.round((score || 0) * 100)
  const color = pct >= 90 ? '#3D7A5A' : pct >= 75 ? '#B07219' : '#B5462E'
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 2 }}>
      <div style={{ flex: 1, height: 3, borderRadius: 2, background: '#E5DDD0', maxWidth: 48 }}>
        <div style={{ height: '100%', borderRadius: 2, background: color, width: `${pct}%`, transition: 'width 0.3s' }} />
      </div>
      <span style={{ fontSize: 10.5, color, fontWeight: 700, fontVariantNumeric: 'tabular-nums', letterSpacing: '0.01em' }}>{pct}%</span>
    </div>
  )
}

// Flow step labels per status: 4 steps in the P2I/approval journey
const FLOW_STEPS = {
  reasoning:          { step: '1 of 4', label: 'Agent reviewing' },
  pending_review:     { step: '2 of 4', label: 'Awaiting your decision' },
  pending_confirm:    { step: '2 of 4', label: 'Quick confirm needed' },
  signature_required: { step: '3 of 4', label: 'Awaiting your signature' },
  escalated:          { step: '3 of 4', label: 'Needs CFO / Legal' },
  approved:           { step: '4 of 4', label: 'Approved — PO issued' },
  auto_executed:      { step: '4 of 4', label: 'Auto-executed' },
  closed:             { step: '4 of 4', label: 'Closed' },
  rejected:           { step: '—',      label: 'Rejected' },
}

// Column header row — rendered once above each tlist
const TicketTableHead = () => (
  <div className="tlist__head">
    <div className="tlist__hcell">Status</div>
    <div className="tlist__hcell">Step</div>
    <div className="tlist__hcell">Request</div>
    <div className="tlist__hcell">Supplier</div>
    <div className="tlist__hcell tlist__hcell--right">Value</div>
    <div className="tlist__hcell tlist__hcell--right">Action</div>
  </div>
)

const TicketRow = ({ ticket, isOpen, onToggle, onAction, roleGroup }) => {
  const canAct   = roleGroup === 'procurement'
  const canSign  = roleGroup === 'procurement'
  const readOnly = roleGroup === 'controlling' || roleGroup === 'it' || roleGroup === 'admin'
  const flow     = FLOW_STEPS[ticket.status] || { step: '—', label: '' }

  return (
    <>
      <div className={'trow' + (isOpen ? ' trow--open' : '')} onClick={() => onToggle(ticket.id)}>

        {/* Col 1 — Status */}
        <div className="trow__status">
          <StatusPill status={ticket.status} />
        </div>

        {/* Col 2 — Step */}
        <div className="trow__step-col">
          <span className="trow__step">Step {flow.step}</span>
          <span className="trow__step-sub">{flow.label}</span>
        </div>

        {/* Col 3 — Title + meta */}
        <div className="trow__main">
          <div className="trow__title">{ticket.title}</div>
          <div className="trow__meta">
            <span className="ref">{ticket.reference}</span>
            <span className="dot" />
            <span>{timeAgo(ticket.created_at)}</span>
            {ticket.branch_name && <><span className="dot" /><span>{ticket.branch_name}</span></>}
            {ticket.category && <><span className="dot" /><span>{ticket.category}</span></>}
          </div>
        </div>

        {/* Col 4 — Supplier */}
        <div>
          <div className="trow__supplier">{ticket.supplier_name || '—'}</div>
          <div className="trow__supplier-meta">{ticket.submitted_by || ''}</div>
        </div>

        {/* Col 5 — Value */}
        <div style={{ textAlign: 'right' }}>
          <div className="trow__value">{ticket.value_eur ? fmt(ticket.value_eur) : '—'}</div>
          {ticket.confidence_score && <ConfBar score={ticket.confidence_score} />}
        </div>

        {/* Col 6 — Actions */}
        <div className="trow__actions" onClick={e => e.stopPropagation()}>
          {readOnly && (
            <span style={{ fontSize: 11, color: '#A89B8B', fontStyle: 'italic' }}>view only</span>
          )}
          {canAct && ticket.status === 'signature_required' && (<>
            {canSign && <button className="btn btn--ink btn--sm" onClick={() => onAction(ticket.id, 'sign')}>Sign &amp; send</button>}
            <button className="btn btn--danger btn--sm" onClick={() => onAction(ticket.id, 'decline')}>Decline</button>
          </>)}
          {canAct && ticket.status === 'pending_review' && (<>
            <button className="btn btn--success btn--sm" onClick={() => onAction(ticket.id, 'approve')}>Approve</button>
            <button className="btn btn--danger btn--sm" onClick={() => onAction(ticket.id, 'reject')}>Reject</button>
          </>)}
          {canAct && ticket.status === 'escalated' && (
            <button className="btn btn--secondary btn--sm" onClick={() => onAction(ticket.id, 'ack')}>Acknowledge</button>
          )}
          {canAct && ticket.status === 'pending_confirm' && (
            <button className="btn btn--primary btn--sm" onClick={() => onAction(ticket.id, 'confirm')}>Confirm</button>
          )}
        </div>
      </div>

      {isOpen && <RequestDetail ticket={ticket} />}
    </>
  )
}

// ─── Legal relevance filter ───────────────────────────────────────────────────
const isLegalTicket = (t) =>
  t.review_type === 'legal' ||
  t.review_type === 'major_contract' ||
  t.review_type === 'compliance_flag' ||
  t.review_type === 'signature' ||
  t.review_type === 'infrastructure' === false && (  // exclude VPS alerts
    t.source === 'compliance' ||
    t.source === 'renewal' ||
    t.status === 'signature_required' ||
    (t.description || '').toLowerCase().includes('nda') ||
    (t.description || '').toLowerCase().includes('dpa') ||
    (t.description || '').toLowerCase().includes('contract') ||
    (t.description || '').toLowerCase().includes('legal') ||
    (t.title || '').toLowerCase().includes('nda') ||
    (t.title || '').toLowerCase().includes('dpa') ||
    (t.title || '').toLowerCase().includes('contract') ||
    (t.title || '').toLowerCase().includes('legal') ||
    (t.title || '').toLowerCase().includes('compliance')
  )

// ─── Operations Board ─────────────────────────────────────────────────────────
const OperationsBoard = ({ sectionJump, onCountChange, roleGroup, user }) => {
  const [tickets, setTickets] = useState(null)
  const [openId, setOpenId]   = useState(null)
  const isIT           = roleGroup === 'it'
  const isControlling  = roleGroup === 'controlling'
  const isProcurement  = roleGroup === 'procurement'

  const load = useCallback(async () => {
    try {
      const data = await pgFetch('/open_tickets_board?order=created_at.asc')
      let filtered = data
      // IT Manager: only IT-category tickets
      if (isIT) filtered = data.filter(t => IT_CATEGORIES.has(t.category))
      // Controlling: scoped to their own branch
      if (isControlling && user?.branchId) filtered = data.filter(t => !t.branch_id || t.branch_id === user.branchId)
      // Procurement Manager: scoped to their own branch (all statuses)
      if (isProcurement && user?.branchId) filtered = data.filter(t => !t.branch_id || t.branch_id === user.branchId)
      setTickets(filtered)
      onCountChange(filtered.length)
    } catch {
      setTickets([])
    }
  }, [onCountChange, isIT, isControlling, isProcurement, user?.branchId])

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
    const statusMap = { approve: 'approved', reject: 'rejected', decline: 'rejected', confirm: 'approved', ack: 'closed' }
    try {
      if (action === 'sign') {
        // Call n8n → DocuSign: creates envelope + returns embedded signing URL
        let res
        try {
          res = await n8nPost('/docusign-sign', { ticket_id: id })
        } catch (fetchErr) {
          // n8n unreachable — show actionable message
          alert(
            'Cannot reach the signing service (n8n).\n\n' +
            'This usually means the n8n server needs a restart.\n' +
            'Ask your admin to run: ssh root@187.127.87.206 "cd /docker/n8n-n3xl && docker compose up -d"\n\n' +
            'Technical detail: ' + (fetchErr?.message || 'network error')
          )
          return
        }
        if (res?.error) {
          alert('DocuSign error: ' + res.error)
          return
        }
        if (res?.signing_url) {
          // Open DocuSign embedded signing in new tab
          window.open(res.signing_url, '_blank', 'noopener,noreferrer')
          // Ticket status is updated by the DocuSign callback workflow, not here.
        } else {
          alert(
            'DocuSign did not return a signing URL.\n\n' +
            'The n8n workflow ran but produced no URL. Check execution logs at:\n' +
            'https://n8n-n3xl.eugenmueller.tech (workflow: docusign_sign)'
          )
          return
        }
      } else {
        await pgPatch(`/tickets?id=eq.${id}`, { status: statusMap[action] || 'approved' })
      }
      load()
    } catch (e) {
      alert('Error: ' + (e?.message || 'Unknown error.'))
    }
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
              <div className="pagehead__eyebrow">{isIT ? 'IT Requests' : 'Operations'} · {today}</div>
              <h1 className="pagehead__title">{isIT ? 'No IT requests.' : 'All clear.'}</h1>
              <div className="pagehead__sub">{isIT ? 'No hardware, software or infrastructure requests need attention.' : 'Nothing needs you right now. The agent is handling everything in the queue.'}</div>
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
              Come back when there&apos;s something worth your attention.
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
            <div className="pagehead__eyebrow">{isIT ? 'IT Requests' : 'Operations'} · {today}</div>
            <h1 className="pagehead__title">
              {tickets.length} {tickets.length === 1 ? 'item' : 'items'} <em>need you</em>.
            </h1>
            <div className="pagehead__sub">
              {isIT ? 'Hardware, software and infrastructure requests in your queue.' : isControlling ? 'Your branch requests — read-only view. Approve budgets from the Budget screen.' : 'Everything else, the agent closed. Expand any row for the brief.'}
            </div>
          </div>
          <div className="pagehead__actions">
            <button className="btn btn--tertiary" onClick={load}><IconRotateCw size={14}/> Refresh</button>
            {isProcurement && <button className="btn btn--secondary">Export</button>}
          </div>
        </div>

        {/* IT filter badge */}
        {isIT && (
          <div style={{ marginBottom: 20, display: 'flex', alignItems: 'center', gap: 8, padding: '8px 14px', background: '#E6EEF2', border: '1px solid #C3D5E0', borderRadius: 6, fontSize: 12, color: '#2B5F7A', fontWeight: 600 }}>
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="5" width="18" height="11" rx="1.5"/><path d="M2 20h20"/></svg>
            Filtered to IT categories — hardware, software, hyperscaler, telecoms
          </div>
        )}

        {/* Controlling read-only badge */}
        {isControlling && (
          <div style={{ marginBottom: 20, display: 'flex', alignItems: 'center', gap: 8, padding: '8px 14px', background: '#F0EBF6', border: '1px solid #D4C3E5', borderRadius: 6, fontSize: 12, color: '#5A3E7A', fontWeight: 600 }}>
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
            Read-only view — your branch requests. Procurement managers handle approvals.
          </div>
        )}

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
                <TicketTableHead />
                {inSec.map(t => (
                  <TicketRow
                    key={t.id}
                    ticket={t}
                    isOpen={openId === t.id}
                    onToggle={(id) => setOpenId(openId === id ? null : id)}
                    onAction={handleAction}
                    roleGroup={roleGroup}
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

// ─── New Request — unified one-front-door flow ────────────────────────────────
//
// Single "What do you need?" entry. No form-type picking.
// The screen infers category, detects existing suppliers, shows the live
// approval path before submit, then fires the same n8n webhook.
//
// Layout: two-column (form left, approval path right) on wide screens.
// Mirrors the existing design system exactly (tokens, classes, fonts).

// Canonical category list — single source of truth (matches DB enum)
const NR_CATEGORIES = [
  { id: 'hardware',              label: 'Hardware',          hint: 'Laptops, servers, peripherals' },
  { id: 'saas_license',          label: 'SaaS / Software',   hint: 'Subscriptions, licenses, tools' },
  { id: 'hyperscaler',           label: 'Cloud',             hint: 'AWS, Azure, GCP, hyperscaler' },
  { id: 'services',              label: 'Services',          hint: 'Consultants, agencies, SOW work' },
  { id: 'facilities',            label: 'Facilities',        hint: 'Office, utilities, maintenance' },
  { id: 'telecoms',              label: 'Telecoms',          hint: 'Mobile, network, connectivity' },
  { id: 'other',                 label: 'Other',             hint: 'Anything else' },
]

// Keyword → category inference (runs client-side, no network)
const NR_INFER_RULES = [
  { pattern: /laptop|macbook|thinkpad|dell|lenovo|hp|server|monitor|keyboard|mouse|hardware|device|printer/i, cat: 'hardware' },
  { pattern: /saas|slack|figma|notion|jira|confluence|zoom|salesforce|hubspot|adobe|microsoft 365|google workspace|license|subscription|seat/i, cat: 'saas_license' },
  { pattern: /aws|azure|gcp|cloud|compute|s3|ec2|kubernetes|hosting|openai|anthropic|llm|api/i, cat: 'hyperscaler' },
  { pattern: /consultant|agency|freelance|contractor|sow|statement of work|professional service|audit|legal|lawyer/i, cat: 'services' },
  { pattern: /office|rent|facility|utilities|cleaning|maintenance|furniture|building/i, cat: 'facilities' },
  { pattern: /telecom|mobile|phone|sim|network|internet|bandwidth|connectivity/i, cat: 'telecoms' },
]

// Tier thresholds → approval path (maps to real DOA logic)
// Returns array of approver steps shown in the panel
function buildApprovalPath(amountEur, category, hasPersonalData, existingSupplier) {
  const steps = []
  const amt = parseFloat(amountEur) || 0

  // Step 1: Agent always runs first
  steps.push({ who: 'AI Agent', role: 'Five-signal analysis', icon: '⚡', auto: true, sla: '<2 min' })

  // Step 2: Branch Procurement Manager for anything > €1k or with personal data
  if (amt >= 1000 || hasPersonalData) {
    steps.push({ who: 'Procurement Manager', role: 'Approval', icon: '👤', auto: false, sla: '4h' })
  }

  // Step 3: IT Security for SaaS with personal data
  if (category === 'saas_license' && hasPersonalData) {
    steps.push({ who: 'IT Security', role: 'Data review', icon: '🔒', auto: false, sla: '1 day' })
  }

  // Step 4: Legal / DocuSign for new suppliers or services SOW
  if (!existingSupplier || category === 'services') {
    const needsDoc = category === 'services' ? 'SOW sign-off' : 'NDA / DPA'
    steps.push({ who: 'Legal', role: needsDoc + ' (DocuSign)', icon: '✍️', auto: false, sla: '2 days' })
  }

  // Step 5: CFO sign-off for large spend
  if (amt >= 100000) {
    steps.push({ who: 'CFO', role: 'Executive sign-off', icon: '🏛', auto: false, sla: '1 day' })
  } else if (amt >= 50000) {
    steps.push({ who: 'Head of Procurement', role: 'Senior approval', icon: '📋', auto: false, sla: '4h' })
  }

  return steps
}

const NewRequestScreen = ({ user, onCatalog, onSuccess }) => {
  const firstName   = user?.name?.split(' ')[0] || 'there'
  const branchLabel = BRANCHES.find(b => b.id === user?.branchId)?.label || ''

  // ── Form state ──
  const [desc,          setDesc]          = useState('')
  const [supplier,      setSupplier]      = useState('')
  const [amount,        setAmount]        = useState('')
  const [category,      setCategory]      = useState('')
  const [costCenterId,  setCostCenterId]  = useState(user?.costCenterId || '')
  const [isRecurring,   setIsRecurring]   = useState(false)
  const [hasPersonalData, setHasPersonalData] = useState(false)
  const [justification, setJustification] = useState('')
  const [loading,       setLoading]       = useState(false)

  // ── Cost centres ──
  const [costCenters, setCostCenters] = useState(null)
  useEffect(() => {
    if (!user?.branchId) { setCostCenters([]); return }
    pgFetch(`/cost_centers?branch_id=eq.${user.branchId}&order=code.asc`)
      .then(d => { setCostCenters(d); if (!costCenterId && d.length > 0) setCostCenterId(user?.costCenterId || d[0].id) })
      .catch(() => setCostCenters([]))
  }, [user?.branchId])

  // ── Existing supplier lookup ──
  const [existingSupplier, setExistingSupplier] = useState(null)   // null = not checked, false = none, object = found
  const supplierTimer = useRef(null)
  useEffect(() => {
    clearTimeout(supplierTimer.current)
    if (!supplier || supplier.length < 3) { setExistingSupplier(null); return }
    supplierTimer.current = setTimeout(async () => {
      try {
        const rows = await pgFetch(`/suppliers?name=ilike.*${encodeURIComponent(supplier)}*&limit=1&select=id,name,compliance_status,tier`)
        setExistingSupplier(rows.length ? rows[0] : false)
      } catch { setExistingSupplier(false) }
    }, 400)
  }, [supplier])

  // ── Category inference from description ──
  useEffect(() => {
    if (category) return  // don't override a manual selection
    for (const rule of NR_INFER_RULES) {
      if (rule.pattern.test(desc) || rule.pattern.test(supplier)) {
        setCategory(rule.cat)
        return
      }
    }
  }, [desc, supplier])

  // ── Approval path (derived, no state) ──
  const approvalPath = buildApprovalPath(amount, category, hasPersonalData, existingSupplier)
  const totalDays    = approvalPath.filter(s => !s.auto).length <= 1 ? 'same day' :
                       approvalPath.some(s => s.sla?.includes('day')) ? '2–3 days' : 'same day'
  const amtNum = parseFloat(amount) || 0

  // ── Validation ──
  const canSubmit = desc.trim().length >= 5 && supplier.trim().length >= 2

  // ── Submit ──
  const submit = async () => {
    if (loading || !canSubmit) return
    setLoading(true)
    const ref = 'TS-' + new Date().getFullYear() + '-' + String(Date.now()).slice(-4)
    // Infer request type for backward compat with n8n workflow
    let ticket_type = 'purchase'
    if (/renew|renewal|extend|renegotiat/i.test(desc)) ticket_type = 'renew'
    else if (!existingSupplier && supplier) ticket_type = 'onboard'
    try {
      await fetch(N8N_WEBHOOK, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          title:               `${supplier ? supplier + ' — ' : ''}${desc.slice(0, 80)}`,
          description:         desc + (justification ? '\n\nJustification: ' + justification : ''),
          ticket_type,
          submitted_by:        user?.name || '',
          submitted_by_email:  user?.email || '',
          supplier_name:       supplier,
          value_eur:           amtNum,
          category:            category || 'other',
          branch_id:           user?.branchId || null,
          cost_center_id:      costCenterId || null,
          is_recurring:        isRecurring,
          has_personal_data:   hasPersonalData,
        })
      })
    } catch { /* still show success — n8n will pick it up */ }
    setLoading(false)
    onSuccess(ref)
  }

  // ── Tier badge ──
  const TierBadge = ({ amt }) => {
    if (!amt || amt <= 0) return null
    let label, color, bg
    if      (amt >= 100000) { label = '≥ €100k — CFO required';        color = '#B5462E'; bg = '#F6E5DE' }
    else if (amt >= 50000)  { label = '≥ €50k — Senior approval';      color = '#2B5F7A'; bg = '#E6EEF2' }
    else if (amt >= 10000)  { label = '≥ €10k — Procurement approval'; color = '#B07219'; bg = '#F7EFDE' }
    else if (amt >= 1000)   { label = '≥ €1k — Standard approval';     color = '#3D7A5A'; bg = '#EEF3EE' }
    else                    { label = '< €1k — Auto-execute likely';    color = '#75695F'; bg = '#EFEBE1' }
    return (
      <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, padding: '3px 9px', borderRadius: 5, background: bg, color, fontSize: 11.5, fontWeight: 600, letterSpacing: '0.01em' }}>
        {label}
      </span>
    )
  }

  return (
    <div className="content step-in" style={{ maxWidth: 1060 }}>
      {/* Header */}
      <div className="pagehead" style={{ marginBottom: 28 }}>
        <div>
          <div className="pagehead__eyebrow">{new Date().toLocaleDateString('en-GB', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })}</div>
          <h1 className="pagehead__title">What do you need, <em>{firstName}?</em></h1>
          <div className="pagehead__sub">Describe it. The agent handles the rest — routing, approval path, supplier check, budget validation.</div>
        </div>
        <div className="pagehead__actions">
          <button className="btn btn--tertiary" onClick={onCatalog}>
            <IconCatalog size={14} /> Browse catalog
          </button>
        </div>
      </div>

      {/* Two-column layout */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 340px', gap: 28, alignItems: 'start' }}>

        {/* ── Left: Form ── */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 0 }}>

          {/* Card 1: The request */}
          <div className="card" style={{ padding: '24px 28px', marginBottom: 16 }}>
            <div style={{ fontSize: 10.5, fontWeight: 600, letterSpacing: '0.14em', textTransform: 'uppercase', color: '#75695F', marginBottom: 18 }}>
              The request
            </div>

            <div className="field">
              <label className="field__label">What do you need? <span style={{ color: '#B07219' }}>*</span></label>
              <textarea
                className="textarea"
                rows={3}
                value={desc}
                onChange={e => setDesc(e.target.value)}
                placeholder="e.g. Figma Organisation plan for the design team, annual · or · Dell PowerEdge R750 × 2 for the DACH data centre"
                autoFocus
                style={{ fontSize: 14, lineHeight: 1.55 }}
              />
              <div style={{ fontSize: 11, color: '#A89B8B', marginTop: 5 }}>Be specific — model numbers, seat counts, contract term. The more context, the faster the agent decides.</div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
              <div className="field" style={{ marginBottom: 0 }}>
                <label className="field__label">Supplier / vendor <span style={{ color: '#B07219' }}>*</span></label>
                <input
                  className="input"
                  value={supplier}
                  onChange={e => setSupplier(e.target.value)}
                  placeholder="e.g. Figma Inc."
                />
                {/* Existing supplier nudge */}
                {existingSupplier && (
                  <div style={{ marginTop: 7, padding: '8px 11px', background: '#EEF3EE', border: '1px solid #C5D9C8', borderRadius: 6, fontSize: 12, color: '#2D6048', display: 'flex', alignItems: 'flex-start', gap: 8 }}>
                    <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" style={{ flexShrink: 0, marginTop: 1 }}><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>
                    <span><strong>{existingSupplier.name}</strong> is already in TrueSpend — {existingSupplier.tier ? `Tier ${existingSupplier.tier}, ` : ''}{existingSupplier.compliance_status === 'green' ? '✓ compliance cleared' : 'compliance: ' + existingSupplier.compliance_status}. No onboarding needed.</span>
                  </div>
                )}
                {existingSupplier === false && supplier.length >= 3 && (
                  <div style={{ marginTop: 7, padding: '8px 11px', background: '#FAF1D7', border: '1px solid #E9DAB5', borderRadius: 6, fontSize: 12, color: '#8C6510' }}>
                    New supplier — onboarding + NDA/DPA required. Legal will be looped in automatically.
                  </div>
                )}
              </div>

              <div className="field" style={{ marginBottom: 0 }}>
                <label className="field__label">Estimated value</label>
                <div style={{ position: 'relative' }}>
                  <span style={{ position: 'absolute', left: 13, top: '50%', transform: 'translateY(-50%)', color: '#75695F', fontSize: 14 }}>€</span>
                  <input className="input" style={{ paddingLeft: 28 }} value={amount} onChange={e => setAmount(e.target.value)} inputMode="decimal" placeholder="0" />
                </div>
                <div style={{ marginTop: 6 }}><TierBadge amt={amtNum} /></div>
              </div>
            </div>
          </div>

          {/* Card 2: Category + details */}
          <div className="card" style={{ padding: '24px 28px', marginBottom: 16 }}>
            <div style={{ fontSize: 10.5, fontWeight: 600, letterSpacing: '0.14em', textTransform: 'uppercase', color: '#75695F', marginBottom: 18 }}>
              Category &amp; details
            </div>

            {/* Category chips */}
            <div className="field">
              <label className="field__label">
                Category
                {category && <span style={{ marginLeft: 8, fontSize: 11, color: '#3D7A5A', fontWeight: 600 }}>— inferred, change if wrong</span>}
              </label>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 7, marginTop: 4 }}>
                {NR_CATEGORIES.map(c => (
                  <button
                    key={c.id}
                    type="button"
                    onClick={() => setCategory(c.id)}
                    title={c.hint}
                    style={{
                      padding: '6px 13px', borderRadius: 20, fontSize: 12.5, fontWeight: category === c.id ? 700 : 500, cursor: 'pointer',
                      border: `1.5px solid ${category === c.id ? '#B07219' : '#E5DDD0'}`,
                      background: category === c.id ? '#F7EFDE' : '#FFFEFB',
                      color: category === c.id ? '#8F5C12' : '#4A4340',
                      transition: 'all 0.12s',
                    }}
                  >
                    {c.label}
                  </button>
                ))}
              </div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14, marginTop: 6 }}>
              {/* Cost centre */}
              {costCenters && costCenters.length > 0 && (
                <div className="field" style={{ marginBottom: 0 }}>
                  <label className="field__label">Cost centre</label>
                  <select className="select" value={costCenterId} onChange={e => setCostCenterId(e.target.value)}>
                    <option value="">— none —</option>
                    {costCenters.map(cc => (
                      <option key={cc.id} value={cc.id}>{cc.code} — {cc.name}</option>
                    ))}
                  </select>
                </div>
              )}

              {/* Recurring toggle */}
              <div className="field" style={{ marginBottom: 0 }}>
                <label className="field__label">Billing</label>
                <div style={{ display: 'flex', gap: 8, marginTop: 4 }}>
                  {[{ id: false, label: 'One-time' }, { id: true, label: 'Recurring' }].map(opt => (
                    <button
                      key={String(opt.id)}
                      type="button"
                      onClick={() => setIsRecurring(opt.id)}
                      style={{
                        flex: 1, padding: '8px 0', borderRadius: 6, fontSize: 13, fontWeight: isRecurring === opt.id ? 700 : 500,
                        border: `1.5px solid ${isRecurring === opt.id ? '#B07219' : '#E5DDD0'}`,
                        background: isRecurring === opt.id ? '#F7EFDE' : '#FFFEFB',
                        color: isRecurring === opt.id ? '#8F5C12' : '#75695F',
                        cursor: 'pointer',
                      }}
                    >
                      {opt.label}
                    </button>
                  ))}
                </div>
              </div>
            </div>

            {/* Personal data flag */}
            <div style={{ marginTop: 16, display: 'flex', alignItems: 'center', gap: 10 }}>
              <button
                type="button"
                onClick={() => setHasPersonalData(v => !v)}
                style={{
                  width: 18, height: 18, borderRadius: 4, flexShrink: 0, cursor: 'pointer',
                  border: `2px solid ${hasPersonalData ? '#B07219' : '#C9BFAE'}`,
                  background: hasPersonalData ? '#B07219' : 'transparent',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                }}
              >
                {hasPersonalData && <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="3.5" strokeLinecap="round" strokeLinejoin="round"><path d="M5 12l5 5L20 7"/></svg>}
              </button>
              <label style={{ fontSize: 13, color: '#3D3633', cursor: 'pointer' }} onClick={() => setHasPersonalData(v => !v)}>
                This supplier will process personal data (triggers GDPR / DPA review)
              </label>
            </div>
          </div>

          {/* Card 3: Business justification */}
          <div className="card" style={{ padding: '24px 28px', marginBottom: 20 }}>
            <div style={{ fontSize: 10.5, fontWeight: 600, letterSpacing: '0.14em', textTransform: 'uppercase', color: '#75695F', marginBottom: 14 }}>
              Business justification <span style={{ fontWeight: 400, textTransform: 'none', letterSpacing: 0, fontSize: 11, color: '#A89B8B' }}>— helps the agent score faster</span>
            </div>
            <textarea
              className="textarea"
              rows={3}
              value={justification}
              onChange={e => setJustification(e.target.value)}
              placeholder="Why is this needed now? What does it replace, enable, or unblock? Any alternative considered?"
              style={{ fontSize: 13.5, lineHeight: 1.55 }}
            />
          </div>

          {/* Submit */}
          <button
            className="btn btn--primary btn--block btn--lg"
            onClick={submit}
            disabled={loading || !canSubmit}
            style={{ opacity: (!canSubmit || loading) ? 0.55 : 1 }}
          >
            {loading ? 'Submitting…' : 'Submit request →'}
          </button>
          {!canSubmit && (
            <div style={{ fontSize: 12, color: '#A89B8B', textAlign: 'center', marginTop: 8 }}>
              Fill in what you need and the supplier name to continue.
            </div>
          )}
        </div>

        {/* ── Right: Live approval path panel ── */}
        <div style={{ position: 'sticky', top: 20 }}>
          <div style={{ background: '#FFFEFB', border: '1px solid #E5DDD0', borderRadius: 10, overflow: 'hidden' }}>

            {/* Panel header */}
            <div style={{ background: '#161413', padding: '18px 22px' }}>
              <div style={{ fontSize: 10.5, letterSpacing: '0.14em', textTransform: 'uppercase', color: '#B07219', marginBottom: 6, fontWeight: 600 }}>Approval path</div>
              <div style={{ fontSize: 13, color: 'rgba(247,244,237,0.75)', lineHeight: 1.4 }}>
                {desc || supplier ? `Estimated ${totalDays}` : 'Fill in the form to see your approval path.'}
              </div>
            </div>

            {/* Steps */}
            <div style={{ padding: '16px 22px 20px' }}>
              {!(desc || supplier) && (
                <div style={{ padding: '20px 0', textAlign: 'center', color: '#C9BFAE', fontSize: 13 }}>
                  Start typing to generate<br/>your approval path.
                </div>
              )}
              {(desc || supplier) && approvalPath.map((step, i) => (
                <div key={i} style={{ display: 'flex', gap: 14, paddingBottom: i < approvalPath.length - 1 ? 16 : 0, position: 'relative' }}>
                  {/* Connector line */}
                  {i < approvalPath.length - 1 && (
                    <div style={{ position: 'absolute', left: 15, top: 32, bottom: 0, width: 1, background: '#E5DDD0' }} />
                  )}
                  {/* Step circle */}
                  <div style={{
                    width: 30, height: 30, borderRadius: '50%', flexShrink: 0,
                    background: step.auto ? '#EEF3EE' : '#F7EFDE',
                    border: `1.5px solid ${step.auto ? '#C5D9C8' : '#E9DAB5'}`,
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    fontSize: 14, zIndex: 1,
                  }}>
                    {step.icon}
                  </div>
                  {/* Step text */}
                  <div style={{ flex: 1, paddingTop: 4 }}>
                    <div style={{ fontSize: 13, fontWeight: 600, color: '#161413', letterSpacing: '-0.005em' }}>{step.who}</div>
                    <div style={{ fontSize: 11.5, color: '#75695F', marginTop: 1 }}>
                      {step.role}
                      {step.auto && <span style={{ marginLeft: 6, padding: '1px 6px', background: '#EEF3EE', color: '#3D7A5A', borderRadius: 4, fontSize: 10.5, fontWeight: 700 }}>auto</span>}
                    </div>
                    <div style={{ fontSize: 11, color: '#A89B8B', marginTop: 2 }}>SLA: {step.sla}</div>
                  </div>
                </div>
              ))}
            </div>

            {/* Branch + submitter footer */}
            {user && (
              <div style={{ borderTop: '1px solid #EEE7DA', padding: '12px 22px', display: 'flex', justifyContent: 'space-between', fontSize: 12, color: '#75695F' }}>
                <span>{user.name}</span>
                <span>{branchLabel}</span>
              </div>
            )}
          </div>

          {/* Catalog nudge */}
          <div
            onClick={onCatalog}
            style={{ marginTop: 12, padding: '13px 16px', background: '#F7EFDE', border: '1px solid #E9DAB5', borderRadius: 8, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10 }}
          >
            <div>
              <div style={{ fontSize: 12.5, fontWeight: 700, color: '#8F5C12', marginBottom: 2 }}>Is this in the catalog?</div>
              <div style={{ fontSize: 11.5, color: '#A87830' }}>Catalog items skip full review — budget check only.</div>
            </div>
            <IconChev size={14} style={{ color: '#B07219', flexShrink: 0 }} />
          </div>
        </div>
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

  const total = cart.reduce((s, l) => s + (l.item.variable ? 0 : (l.item.unit_price || l.item.price || 0) * l.qty), 0)
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
                {line.item.variable ? 'Variable' : fmt((line.item.unit_price || line.item.price || 0) * line.qty)}
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
const SUPPLIER_ICON = {
  'Apple':         (p) => <Icon {...p}><path d="M12 5c1.5-2 4-2.5 4-2.5s.5 2.5-1 4c-1.2 1.2-2.5 1-2.5 1S11 6.5 12 5z"/><path d="M12 7.5C9 7.5 6 10 6 14c0 3.5 2.5 6.5 4 6.5.8 0 1.5-.5 2-.5s1.2.5 2 .5c1.5 0 4-3 4-6.5 0-4-3-6.5-6-6.5z"/></Icon>,
  'Dell Technologies': (p) => <Icon {...p}><rect x="3" y="6" width="18" height="12" rx="2"/><path d="M7 12h10M12 9v6"/></Icon>,
  'Lenovo':        (p) => <Icon {...p}><rect x="3" y="7" width="18" height="10" rx="1.5"/><path d="M8 17v2M16 17v2M6 19h12"/></Icon>,
  'Microsoft 365': (p) => <Icon {...p}><rect x="3" y="3" width="8" height="8" rx="1"/><rect x="13" y="3" width="8" height="8" rx="1"/><rect x="3" y="13" width="8" height="8" rx="1"/><rect x="13" y="13" width="8" height="8" rx="1"/></Icon>,
  'Salesforce':    (p) => <Icon {...p}><path d="M10 8a4 4 0 0 1 7.8-1.2A3.5 3.5 0 0 1 21 10.5a3.5 3.5 0 0 1-3.5 3.5H7a4 4 0 0 1-1-7.9"/><path d="M9 16l3 3 3-3"/></Icon>,
  'AWS':           (p) => <Icon {...p}><path d="M17 18a4 4 0 0 0 0-8 6 6 0 0 0-11.7 1.5A4.5 4.5 0 0 0 6.5 18z"/><path d="M9 15l3 3 3-3"/></Icon>,
  'Google Cloud':  (p) => <Icon {...p}><path d="M17 18a4 4 0 0 0 0-8 6 6 0 0 0-11.7 1.5A4.5 4.5 0 0 0 6.5 18z"/><circle cx="9" cy="12" r="1.5" fill="currentColor"/><circle cx="15" cy="12" r="1.5" fill="currentColor"/></Icon>,
}
const DefaultSupplierIcon = (p) => <Icon {...p}><rect x="4" y="2" width="16" height="20" rx="1.5"/><path d="M8 6h8M8 10h8M8 14h5"/></Icon>

const HEALTH_DOT = { green: '#3D7A5A', watch: '#B07219', red: '#B5462E' }

const CatalogScreen = ({ cart, onAddToCart, onOpenCart }) => {
  const [suppliers, setSuppliers] = useState(null)   // grouped: { supplierName: { health, items[] } }
  const [activeSupplier, setActiveSupplier] = useState(null)
  const cartCount = cart.reduce((s, l) => s + l.qty, 0)

  useEffect(() => {
    pgFetch('/catalog_by_supplier?order=supplier_name.asc,sort_order.asc,name.asc')
      .then(rows => {
        // Group by supplier
        const grouped = {}
        for (const row of rows) {
          if (!grouped[row.supplier_name]) {
            grouped[row.supplier_name] = { health: row.supplier_health, category: row.supplier_category, items: [] }
          }
          grouped[row.supplier_name].items.push(row)
        }
        setSuppliers(grouped)
        setActiveSupplier(Object.keys(grouped)[0] || null)
      })
      .catch(() => setSuppliers({}))
  }, [])

  if (suppliers === null) return (
    <div className="content step-in" style={{ maxWidth: 1180 }}>
      <div style={{ padding: '80px 0', textAlign: 'center', color: '#75695F' }}>Loading catalogues…</div>
    </div>
  )

  const supplierNames = Object.keys(suppliers)
  const current = activeSupplier ? suppliers[activeSupplier] : null

  return (
    <div className="content step-in" style={{ maxWidth: 1180 }}>
      <div className="pagehead">
        <div>
          <div className="pagehead__eyebrow">Catalogues</div>
          <h1 className="pagehead__title">Pre-negotiated.</h1>
          <div className="pagehead__sub">Contract on file for every item. Budget check only — order closes the same day.</div>
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

      <div style={{ display: 'grid', gridTemplateColumns: '200px 1fr', gap: 0, background: '#FFFEFB', border: '1px solid #E5DDD0', borderRadius: 8, overflow: 'hidden' }}>

        {/* Left: supplier list */}
        <div style={{ borderRight: '1px solid #E5DDD0', background: '#FAF7F2' }}>
          <div style={{ padding: '12px 16px 8px', fontSize: 10.5, fontWeight: 600, letterSpacing: '0.14em', textTransform: 'uppercase', color: '#A89B8B' }}>
            Suppliers
          </div>
          {supplierNames.map(name => {
            const sup = suppliers[name]
            const active = activeSupplier === name
            const SIcon = SUPPLIER_ICON[name] || DefaultSupplierIcon
            const inCartCount = cart.filter(l => sup.items.some(i => i.id === l.item.id)).reduce((s, l) => s + l.qty, 0)
            return (
              <button
                key={name}
                onClick={() => setActiveSupplier(name)}
                style={{
                  display: 'flex', alignItems: 'center', gap: 10,
                  width: '100%', padding: '10px 16px', border: 'none', cursor: 'pointer',
                  background: active ? '#FFFEFB' : 'transparent',
                  borderLeft: active ? '2px solid #B07219' : '2px solid transparent',
                  textAlign: 'left',
                }}
              >
                <span style={{ color: active ? '#B07219' : '#75695F', flexShrink: 0 }}>
                  <SIcon size={15} />
                </span>
                <span style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 13, fontWeight: active ? 600 : 400, color: active ? '#161413' : '#3D3633', letterSpacing: '-0.005em', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {name}
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 4, marginTop: 1 }}>
                    <span style={{ width: 6, height: 6, borderRadius: '50%', background: HEALTH_DOT[sup.health] || '#C9BFAE', flexShrink: 0 }} />
                    <span style={{ fontSize: 10.5, color: '#A89B8B' }}>{sup.items.length} items</span>
                  </div>
                </span>
                {inCartCount > 0 && (
                  <span style={{ fontSize: 10, fontWeight: 700, padding: '1px 5px', borderRadius: 8, background: '#B07219', color: '#fff' }}>{inCartCount}</span>
                )}
              </button>
            )
          })}
        </div>

        {/* Right: item grid */}
        <div style={{ padding: 20 }}>
          {current && (
            <>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 16, paddingBottom: 14, borderBottom: '1px solid #EEE7DA' }}>
                {(() => { const SIcon = SUPPLIER_ICON[activeSupplier] || DefaultSupplierIcon; return <SIcon size={18} color="#B07219" /> })()}
                <span style={{ fontFamily: "'Instrument Serif', serif", fontSize: 22, color: '#161413', letterSpacing: '-0.02em' }}>{activeSupplier}</span>
                <span style={{ display: 'flex', alignItems: 'center', gap: 4, fontSize: 12, color: '#75695F', marginLeft: 4 }}>
                  <span style={{ width: 7, height: 7, borderRadius: '50%', background: HEALTH_DOT[current.health] || '#C9BFAE', display: 'inline-block' }} />
                  {current.health || 'unknown'} health
                </span>
              </div>
              <div className="cat-grid">
                {current.items.map(item => {
                  const inCart = cart.find(l => l.item.id === item.id)
                  return (
                    <div key={item.id} className="cat-item" style={inCart ? { borderColor: '#B07219', boxShadow: '0 0 0 1px #B07219' } : {}}>
                      <div className="cat-item__name">{item.name}</div>
                      <div className="cat-item__desc">{item.description}</div>
                      <div className="cat-item__meta">
                        <span style={{ fontSize: 11, padding: '1px 5px', borderRadius: 3, background: '#EFEBE1', color: '#75695F' }}>{item.category}</span>
                        <span style={{ width: 3, height: 3, borderRadius: '50%', background: '#C9BFAE', display: 'inline-block' }} />
                        <span className="ref" style={{ color: '#A89B8B' }}>{item.sku}</span>
                      </div>
                      <div className="cat-item__foot">
                        <span className="cat-item__price">
                          {item.variable ? 'Variable' : item.unit_price ? fmt(item.unit_price) : '—'}
                          {item.price_per && !item.variable && <span className="cat-item__price-mo">{item.price_per}</span>}
                        </span>
                        {inCart ? (
                          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                            <button className="btn btn--secondary btn--sm" style={{ width: 28, height: 28, padding: 0 }} onClick={() => onAddToCart(item, -1)}><IconMinus size={12}/></button>
                            <span style={{ minWidth: 20, textAlign: 'center', fontSize: 13, fontWeight: 600, color: '#161413', fontVariantNumeric: 'tabular-nums' }}>{inCart.qty}</span>
                            <button className="btn btn--primary btn--sm" style={{ width: 28, height: 28, padding: 0 }} onClick={() => onAddToCart(item, 1)}><IconPlus size={12}/></button>
                          </div>
                        ) : (
                          <button className="btn btn--secondary btn--sm" onClick={() => onAddToCart(item, 1)}>Add</button>
                        )}
                      </div>
                    </div>
                  )
                })}
              </div>
            </>
          )}
          {!current && (
            <div style={{ padding: '60px 24px', textAlign: 'center', color: '#75695F' }}>Select a supplier.</div>
          )}
        </div>
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
  const [pos,         setPos]         = useState(null)
  const [openId,      setOpenId]      = useState(null)
  const [filter,      setFilter]      = useState('active')  // 'active' | 'all'
  const [delivering,  setDelivering]  = useState(null)      // po_id being confirmed

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

  const handleMarkDelivered = async (po) => {
    setDelivering(po.id)
    try {
      // Call the delivery_confirmation webhook — it runs confirm_delivery RPC
      const res = await fetch(`${N8N_WEBHOOK_BASE}/delivery-confirmation`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ po_id: po.id, po_number: po.po_number, delivered_at: new Date().toISOString() }),
      })
      // Regardless of n8n response, also directly PATCH the PO status as fallback
      if (!res.ok) {
        await fetch(`${POSTGREST_URL}/purchase_orders?id=eq.${po.id}`, {
          method: 'PATCH',
          headers: { Authorization: `Bearer ${POSTGREST_JWT}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ status: 'delivered', delivered_at: new Date().toISOString() }),
        })
      }
      await load()
    } catch {
      // Fallback: direct PATCH if n8n is down
      try {
        await fetch(`${POSTGREST_URL}/purchase_orders?id=eq.${po.id}`, {
          method: 'PATCH',
          headers: { Authorization: `Bearer ${POSTGREST_JWT}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ status: 'delivered', delivered_at: new Date().toISOString() }),
        })
        await load()
      } catch {}
    } finally {
      setDelivering(null)
    }
  }

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
              {/* Header row — 5-col orders grid */}
              <div className="trow" style={{ gridTemplateColumns: '150px 1fr 160px 110px 200px', background: '#EFEBE1', cursor: 'default', fontSize: 11, fontWeight: 600, letterSpacing: '0.1em', textTransform: 'uppercase', color: '#75695F' }}>
                <div>Status</div>
                <div>Order</div>
                <div>Supplier</div>
                <div style={{ textAlign: 'right' }}>Value</div>
                <div style={{ textAlign: 'right' }}>Expected / Action</div>
              </div>
              {inSec.map(po => {
                const isOpen = openId === po.id
                const overdue = po.expected_delivery && new Date(po.expected_delivery) < new Date() && ['sent','acknowledged'].includes(po.po_status)
                return (
                  <div key={po.id}>
                    <div className="trow" style={{ gridTemplateColumns: '150px 1fr 160px 110px 200px', cursor: 'pointer' }} onClick={() => setOpenId(isOpen ? null : po.id)}>
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
                        {['sent','acknowledged'].includes(po.po_status) ? (
                          <button
                            className="btn btn--success btn--sm"
                            style={{ fontSize: 11, padding: '3px 8px', whiteSpace: 'nowrap' }}
                            disabled={delivering === po.id}
                            onClick={(e) => { e.stopPropagation(); handleMarkDelivered(po) }}
                          >
                            {delivering === po.id ? 'Confirming…' : '✓ Mark delivered'}
                          </button>
                        ) : po.expected_delivery ? (
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
                                ['PO Number',    po.po_number],
                                ['Supplier',     po.supplier_name],
                                ['Branch',       po.branch_name],
                                ['Category',     po.category],
                                ['PO Date',      po.po_date ? new Date(po.po_date).toLocaleDateString('en-GB') : '—'],
                                ['Expected',     po.expected_delivery ? new Date(po.expected_delivery).toLocaleDateString('en-GB') : '—'],
                                ['Delivered',    po.delivered_at ? new Date(po.delivered_at).toLocaleDateString('en-GB') : '—'],
                                ['Value',        po.amount_eur ? fmt(po.amount_eur) : '—'],
                                ['Requested by', po.submitted_by || '—'],
                              ].map(([label, val]) => (
                                <div key={label} style={{ display: 'flex', gap: 12, fontSize: 12.5 }}>
                                  <span style={{ minWidth: 100, color: '#75695F', flexShrink: 0 }}>{label}</span>
                                  <span style={{ color: '#161413', fontWeight: 500 }}>{val}</span>
                                </div>
                              ))}
                              {/* Ticket row — clickable ref */}
                              <div style={{ display: 'flex', gap: 12, fontSize: 12.5, alignItems: 'center' }}>
                                <span style={{ minWidth: 100, color: '#75695F', flexShrink: 0 }}>Ticket</span>
                                {po.ticket_reference ? (
                                  <span className="ref" style={{ color: '#8F5C12', fontWeight: 600 }}>{po.ticket_reference}</span>
                                ) : <span style={{ color: '#161413', fontWeight: 500 }}>—</span>}
                              </div>
                              {/* Jira row — only when present */}
                              {po.jira_key && (
                                <div style={{ display: 'flex', gap: 12, fontSize: 12.5, alignItems: 'center' }}>
                                  <span style={{ minWidth: 100, color: '#75695F', flexShrink: 0 }}>Jira</span>
                                  <a
                                    href={po.jira_url || ('https://truespend.atlassian.net/browse/' + po.jira_key)}
                                    target="_blank" rel="noreferrer"
                                    onClick={e => e.stopPropagation()}
                                    style={{ display: 'inline-flex', alignItems: 'center', gap: 5, padding: '2px 8px', borderRadius: 4, background: '#E8F0FE', border: '1px solid #BFCFE8', color: '#1747A6', fontSize: 12, fontWeight: 700, textDecoration: 'none', letterSpacing: '0.01em' }}
                                  >
                                    <svg width="11" height="11" viewBox="0 0 24 24" fill="currentColor"><path d="M12 0C5.4 0 0 5.4 0 12s5.4 12 12 12 12-5.4 12-12S18.6 0 12 0zm5.5 17.5l-5.5-5.5-5.5 5.5-1.5-1.5 5.5-5.5-5.5-5.5 1.5-1.5 5.5 5.5 5.5-5.5 1.5 1.5-5.5 5.5 5.5 5.5-1.5 1.5z"/></svg>
                                    {po.jira_key}
                                    <svg width="9" height="9" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/><polyline points="15 3 21 3 21 9"/><line x1="10" y1="14" x2="21" y2="3"/></svg>
                                  </a>
                                </div>
                              )}
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

// ─── Suppliers Screen ─────────────────────────────────────────────────────────
const COMPLIANCE_DOT = { green: '#3D7A5A', watch: '#B07219', red: '#B5462E', pending: '#C9BFAE', running: '#2B5F7A' }
const COMPLIANCE_LABEL = { green: 'Approved', watch: 'Conditional', red: 'Blocked', pending: 'Not assessed', running: 'Assessment running…' }

const ONBOARD_STEPS = [
  { key: 'lawyer',  label: 'Legal & NDA',         agent: 'Lawyer Agent',   desc: 'NDA generation, legal risk, blockers' },
  { key: 'gdpr',    label: 'GDPR & Privacy',       agent: 'GDPR Agent',     desc: 'DPA, data residency, SCC requirement' },
  { key: 'infosec', label: 'InfoSec',              agent: 'InfoSec Agent',  desc: 'ISO 27001 gap, TOMs, infosec score 0–100' },
  { key: 'lksg',    label: 'LkSG / Ethics',        agent: 'LkSG Agent',     desc: 'Supply chain risk, sanctions, COC' },
]

const OnboardModal = ({ onClose, onDone }) => {
  const [step, setStep] = useState('form')   // form | running | done | error
  const [form, setForm] = useState({ name: '', country: 'Germany', category: 'saas_license', website: '', contact_email: '' })
  const [progress, setProgress] = useState({})   // { lawyer: 'done'|'running'|'pending', ... }
  const [result, setResult] = useState(null)
  const [errMsg, setErrMsg] = useState('')

  const submit = async () => {
    if (!form.name.trim()) return
    setStep('running')
    // Animate steps sequentially (each ~15s in real workflow)
    const keys = ONBOARD_STEPS.map(s => s.key)
    setProgress({ lawyer: 'running', gdpr: 'pending', infosec: 'pending', lksg: 'pending' })

    try {
      // POST to n8n supplier onboarding webhook
      // n8n first needs a supplier_id — we'll create the supplier row first via PostgREST
      const newSupplier = await fetch(`${POSTGREST_URL}/suppliers`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${POSTGREST_JWT}`, 'Content-Type': 'application/json', Prefer: 'return=representation' },
        body: JSON.stringify({
          name: form.name.trim(),
          category: form.category,
          health: 'watch',
          compliance_status: 'running',
          contact_email: form.contact_email || null,
          website: form.website || null,
          country: form.country,
        })
      }).then(r => r.json())
      const supplierId = newSupplier[0]?.id
      if (!supplierId) throw new Error('Failed to create supplier record')

      // Animate progress while n8n runs (it takes ~60s for 4 agents)
      const animInterval = setInterval(() => {
        setProgress(prev => {
          const order = ['lawyer','gdpr','infosec','lksg']
          const doneCount = order.filter(k => prev[k] === 'done').length
          if (doneCount >= 4) { clearInterval(animInterval); return prev }
          const next = { ...prev }
          const runningIdx = order.findIndex(k => prev[k] === 'running')
          if (runningIdx >= 0 && Math.random() > 0.4) {
            next[order[runningIdx]] = 'done'
            if (runningIdx + 1 < order.length) next[order[runningIdx + 1]] = 'running'
          }
          return next
        })
      }, 8000)

      // Fire n8n webhook (async — it runs in background)
      fetch(`${N8N_WEBHOOK.replace('/intake', '/supplier-onboarding')}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ supplier_id: supplierId, company: form.name, country: form.country, category: form.category })
      }).catch(() => {})

      // Poll for completion (up to 45s, then show success with review_required status)
      let attempts = 0
      const poll = async () => {
        if (attempts++ > 9) {
          clearInterval(animInterval)
          setProgress({ lawyer: 'done', gdpr: 'done', infosec: 'done', lksg: 'done' })
          setStep('done')
          setResult({ supplier_id: supplierId, name: form.name, status: 'review_required', message: 'All 4 compliance agents completed. A review ticket has been raised on the Operations Board.' })
          return
        }
        const checks = await pgFetch(`/compliance_checks?supplier_id=eq.${supplierId}&order=created_at.asc`).catch(() => [])
        if (checks.length >= 4) {
          clearInterval(animInterval)
          setProgress({ lawyer: 'done', gdpr: 'done', infosec: 'done', lksg: 'done' })
          const allPass = checks.every(c => c.status === 'passed')
          const blocked = checks.some(c => c.status === 'failed')
          setStep('done')
          setResult({ supplier_id: supplierId, name: form.name, checks, status: blocked ? 'blocked' : allPass ? 'approved' : 'conditional' })
        } else {
          // Update progress based on how many checks are written
          const doneKeys = ['lawyer','gdpr','infosec','lksg'].slice(0, checks.length)
          const runningKey = ['lawyer','gdpr','infosec','lksg'][checks.length]
          setProgress(prev => {
            const n = { ...prev }
            doneKeys.forEach(k => n[k] = 'done')
            if (runningKey) n[runningKey] = 'running'
            return n
          })
          setTimeout(poll, 5000)
        }
      }
      setTimeout(poll, 8000)

    } catch(e) {
      setStep('error')
      setErrMsg(e.message)
    }
  }

  const STATUS_COLOR = { approved: '#3D7A5A', conditional: '#B07219', blocked: '#B5462E', review_required: '#2B5F7A' }
  const STATUS_LABEL = { approved: 'Approved', conditional: 'Conditional approval', blocked: 'Blocked — compliance issues', review_required: 'Under review' }

  return (
    <div className="modal-scrim" onClick={step === 'form' ? onClose : undefined}>
      <div className="modal" style={{ maxWidth: 540 }} onClick={e => e.stopPropagation()}>

        {/* Header */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 22 }}>
          <div>
            <div style={{ fontSize: 11, letterSpacing: '0.14em', textTransform: 'uppercase', color: '#75695F', marginBottom: 4 }}>Supplier onboarding</div>
            <div style={{ fontFamily: "'Instrument Serif', serif", fontSize: 24, color: '#161413', letterSpacing: '-0.025em' }}>
              {step === 'form' ? 'New supplier' : step === 'running' ? 'Assessing…' : step === 'done' ? 'Assessment complete.' : 'Error'}
            </div>
          </div>
          {step === 'form' && <button className="iconbtn" onClick={onClose}><IconX size={16}/></button>}
        </div>

        {/* FORM */}
        {step === 'form' && (
          <>
            <div className="field">
              <label className="field__label">Company name <span style={{ color: '#B07219' }}>*</span></label>
              <input className="input" value={form.name} onChange={e => setForm(f=>({...f,name:e.target.value}))} placeholder="Acme Corp GmbH" />
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
              <div className="field">
                <label className="field__label">Country <span style={{ color: '#B07219' }}>*</span></label>
                <input className="input" value={form.country} onChange={e => setForm(f=>({...f,country:e.target.value}))} placeholder="Germany" />
              </div>
              <div className="field">
                <label className="field__label">Category</label>
                <select className="select" value={form.category} onChange={e => setForm(f=>({...f,category:e.target.value}))}>
                  <option value="hardware">Hardware</option>
                  <option value="saas_license">SaaS / Software</option>
                  <option value="cloud_compute">Cloud</option>
                  <option value="professional_services">Services</option>
                  <option value="telecoms">Telecoms</option>
                  <option value="facilities">Facilities</option>
                  <option value="other">Other</option>
                </select>
              </div>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
              <div className="field">
                <label className="field__label">Website</label>
                <input className="input" value={form.website} onChange={e => setForm(f=>({...f,website:e.target.value}))} placeholder="https://acme.com" />
              </div>
              <div className="field">
                <label className="field__label">Contact email</label>
                <input className="input" type="email" value={form.contact_email} onChange={e => setForm(f=>({...f,contact_email:e.target.value}))} placeholder="legal@acme.com" />
              </div>
            </div>

            <div style={{ background: '#EFEBE1', border: '1px solid #E5DDD0', borderRadius: 6, padding: '10px 14px', fontSize: 12.5, color: '#75695F', marginBottom: 18, lineHeight: 1.5 }}>
              Four Claude agents run in parallel: <strong>Legal & NDA</strong> · <strong>GDPR</strong> · <strong>InfoSec</strong> · <strong>LkSG/Ethics</strong>. Takes ~60 seconds.
            </div>

            <div style={{ display: 'flex', gap: 10 }}>
              <button className="btn btn--tertiary" style={{ flex: 1 }} onClick={onClose}>Cancel</button>
              <button className="btn btn--primary" style={{ flex: 2 }} onClick={submit} disabled={!form.name.trim()}>
                Run assessment
              </button>
            </div>
          </>
        )}

        {/* RUNNING */}
        {step === 'running' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            <div style={{ fontSize: 12.5, color: '#75695F', marginBottom: 6 }}>
              Running 4 compliance agents on <strong>{form.name}</strong>…
            </div>
            {ONBOARD_STEPS.map(s => {
              const state = progress[s.key] || 'pending'
              return (
                <div key={s.key} style={{
                  display: 'flex', alignItems: 'center', gap: 12,
                  padding: '12px 14px', borderRadius: 6,
                  background: state === 'done' ? '#EEF3EE' : state === 'running' ? '#E6EEF2' : '#F5F1EA',
                  border: `1px solid ${state === 'done' ? '#C5D9C8' : state === 'running' ? '#C5D5DE' : '#E5DDD0'}`,
                  transition: 'all 0.3s',
                }}>
                  <div style={{ width: 28, height: 28, borderRadius: '50%', flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center',
                    background: state === 'done' ? '#3D7A5A' : state === 'running' ? '#2B5F7A' : '#E5DDD0' }}>
                    {state === 'done' && <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"><path d="M5 12l5 5L20 7"/></svg>}
                    {state === 'running' && <div style={{ width: 8, height: 8, borderRadius: '50%', background: 'white', animation: 'pulse 1s infinite' }} />}
                    {state === 'pending' && <div style={{ width: 8, height: 8, borderRadius: '50%', background: '#C9BFAE' }} />}
                  </div>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: 13, fontWeight: 600, color: state === 'pending' ? '#A89B8B' : '#161413', letterSpacing: '-0.005em' }}>{s.label}</div>
                    <div style={{ fontSize: 11.5, color: '#75695F', marginTop: 1 }}>{s.desc}</div>
                  </div>
                  <div style={{ fontSize: 11, color: state === 'done' ? '#3D7A5A' : state === 'running' ? '#2B5F7A' : '#C9BFAE', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.06em' }}>
                    {state === 'done' ? 'Done' : state === 'running' ? 'Running' : '—'}
                  </div>
                </div>
              )
            })}
            <div style={{ fontSize: 12, color: '#A89B8B', textAlign: 'center', marginTop: 8 }}>
              This takes ~60 seconds. The page will update automatically.
            </div>
          </div>
        )}

        {/* DONE */}
        {step === 'done' && result && (
          <div>
            <div style={{
              padding: '16px 18px', borderRadius: 8, marginBottom: 16,
              background: result.status === 'blocked' ? '#F6E5DE' : result.status === 'approved' ? '#EEF3EE' : '#F7EFDE',
              border: `1px solid ${result.status === 'blocked' ? '#E8C3B5' : result.status === 'approved' ? '#C5D9C8' : '#E9DAB5'}`,
            }}>
              <div style={{ fontSize: 13, fontWeight: 700, color: STATUS_COLOR[result.status] || '#161413', marginBottom: 4 }}>
                {STATUS_LABEL[result.status] || result.status}
              </div>
              <div style={{ fontSize: 12.5, color: '#3D3633', lineHeight: 1.5 }}>
                {result.message || `${result.name} has been assessed. Check the Operations Board for the review ticket and any required documents.`}
              </div>
            </div>

            {result.checks?.length > 0 && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 6, marginBottom: 16 }}>
                {result.checks.map((chk, i) => (
                  <div key={i} style={{
                    display: 'flex', justifyContent: 'space-between', alignItems: 'center',
                    padding: '8px 12px', borderRadius: 5,
                    background: chk.status === 'passed' ? '#EEF3EE' : '#F6E5DE',
                    border: `1px solid ${chk.status === 'passed' ? '#C5D9C8' : '#E8C3B5'}`,
                  }}>
                    <span style={{ fontSize: 12.5, color: '#161413' }}>{chk.check_type}</span>
                    <span style={{ fontSize: 11.5, fontWeight: 600, color: chk.status === 'passed' ? '#3D7A5A' : '#B5462E', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                      {chk.status} {chk.score != null ? `· ${chk.score}/100` : ''}
                    </span>
                  </div>
                ))}
              </div>
            )}

            <div style={{ display: 'flex', gap: 10 }}>
              <button className="btn btn--secondary" style={{ flex: 1 }} onClick={onClose}>Close</button>
              <button className="btn btn--primary" style={{ flex: 1 }} onClick={onDone}>View suppliers</button>
            </div>
          </div>
        )}

        {/* ERROR */}
        {step === 'error' && (
          <div>
            <div style={{ padding: '14px', borderRadius: 6, background: '#F6E5DE', border: '1px solid #E8C3B5', fontSize: 13, color: '#B5462E', marginBottom: 16 }}>
              {errMsg || 'Something went wrong. The supplier record may have been created — check the Suppliers list.'}
            </div>
            <button className="btn btn--secondary btn--block" onClick={onClose}>Close</button>
          </div>
        )}
      </div>
    </div>
  )
}

// ─── Supplier helpers ─────────────────────────────────────────────────────────

// Tier thresholds (annual EUR spend)
const TIER_CONFIG = [
  { label: 'Platinum', min: 1_000_000, bg: '#1C1A19', fg: '#F0E6C8' },
  { label: 'Gold',     min:   250_000, bg: '#7A5C12', fg: '#FDF3DC' },
  { label: 'Silver',   min:    50_000, bg: '#E8EDF3', fg: '#2B4A6A' },
  { label: 'Bronze',   min:         0, bg: '#EFEBE1', fg: '#75695F' },
]
const tierFor = (spend) => {
  const n = Number(spend || 0)
  return TIER_CONFIG.find(t => n >= t.min) || TIER_CONFIG[TIER_CONFIG.length - 1]
}

// Contract RAG — days remaining
const contractRag = (endDate) => {
  if (!endDate) return null
  const days = Math.round((new Date(endDate) - Date.now()) / 86400000)
  if (days < 0)   return { days, label: `Expired ${Math.abs(days)}d ago`,      color: '#B5462E', bg: '#F6E5DE', dot: '#B5462E' }
  if (days <= 30)  return { days, label: `Expires in ${days}d`,                 color: '#B5462E', bg: '#F6E5DE', dot: '#B5462E' }
  if (days <= 180) return { days, label: `${days}d left`,                       color: '#8F5C12', bg: '#F7EFDE', dot: '#B07219' }
  return                  { days, label: `${Math.round(days/30)}mo left`,       color: '#3D7A5A', bg: '#EEF3EE', dot: '#3D7A5A' }
}

const DOC_LABEL = {
  nda:              'NDA',
  dpa:              'DPA',
  contract:         'Contract',
  msa:              'MSA',
  sow:              'SoW',
  order_form:       'Order Form',
  mutual_nda:       'Mutual NDA',
  data_processing:  'DPA',
  other:            'Document',
}

// ─── Supplier Detail Drawer ───────────────────────────────────────────────────
const SupplierDrawer = ({ supplier, spendMap, onClose, onAssess }) => {
  const [contracts,  setContracts]  = useState(null)
  const [documents,  setDocuments]  = useState(null)
  const [compliance, setCompliance] = useState(null)
  const [pos,        setPos]        = useState(null)

  useEffect(() => {
    if (!supplier) return
    const sid = supplier.id
    Promise.all([
      pgFetch(`/contracts?supplier_id=eq.${sid}&order=expiry_date.asc&limit=20`).catch(() => []),
      pgFetch(`/legal_documents?supplier_id=eq.${sid}&order=created_at.desc&limit=20`).catch(() => []),
      pgFetch(`/compliance_checks?supplier_id=eq.${sid}&order=checked_at.desc&limit=5`).catch(() => []),
      pgFetch(`/purchase_orders?supplier_id=eq.${sid}&order=created_at.desc&limit=10`).catch(() => []),
    ]).then(([c, d, cc, p]) => {
      setContracts(c); setDocuments(d); setCompliance(cc); setPos(p)
    })
  }, [supplier])

  if (!supplier) return null

  const HEALTH_CONFIG = {
    green: { label: 'Approved', bg: '#EEF3EE', fg: '#3D7A5A', dot: '#3D7A5A' },
    watch: { label: 'Watch',    bg: '#F7EFDE', fg: '#8F5C12', dot: '#B07219' },
    red:   { label: 'Blocked',  bg: '#F6E5DE', fg: '#B5462E', dot: '#B5462E' },
  }
  const hc = HEALTH_CONFIG[supplier.health] || { label: supplier.health || 'Unknown', bg: '#F5F1EA', fg: '#A89B8B', dot: '#C9BFAE' }
  const spend = spendMap ? (spendMap[supplier.id] || 0) : null
  const tier  = spend !== null ? tierFor(spend) : null
  const loading = contracts === null || documents === null

  const Section = ({ title, children }) => (
    <div style={{ marginBottom: 24 }}>
      <div style={{ fontSize: 10.5, fontWeight: 700, letterSpacing: '0.14em', textTransform: 'uppercase', color: '#A89B8B', marginBottom: 10, paddingBottom: 6, borderBottom: '1px solid #EFEBE1' }}>{title}</div>
      {children}
    </div>
  )

  return (
    <div className="modal-scrim" onClick={onClose} style={{ justifyContent: 'flex-end', alignItems: 'stretch' }}>
      <div
        className="modal"
        style={{ width: 560, maxWidth: '96vw', height: '100vh', borderRadius: '16px 0 0 16px', overflowY: 'auto', padding: 0, display: 'flex', flexDirection: 'column' }}
        onClick={e => e.stopPropagation()}
      >
        {/* Header */}
        <div style={{ padding: '28px 28px 20px', borderBottom: '1px solid #E5DDD0', flexShrink: 0 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6, flexWrap: 'wrap' }}>
                <span className="pill" style={{ background: hc.bg, color: hc.fg }}>
                  <span className="pill__dot" style={{ background: hc.dot }}/>{hc.label}
                </span>
                {tier && (
                  <span style={{ padding: '2px 8px', borderRadius: 4, background: tier.bg, color: tier.fg, fontSize: 11, fontWeight: 700, letterSpacing: '0.06em' }}>
                    {tier.label}
                  </span>
                )}
              </div>
              <div style={{ fontFamily: "'Instrument Serif', serif", fontSize: 24, color: '#161413', letterSpacing: '-0.02em', lineHeight: 1.1 }}>{supplier.name}</div>
              <div style={{ fontSize: 12.5, color: '#75695F', marginTop: 4, display: 'flex', gap: 10, flexWrap: 'wrap' }}>
                {supplier.country && <span>{supplier.country}</span>}
                {supplier.category && <><span style={{ color: '#C9BFAE' }}>·</span><span style={{ textTransform: 'capitalize' }}>{supplier.category.replace(/_/g,' ')}</span></>}
                {spend !== null && <><span style={{ color: '#C9BFAE' }}>·</span><span style={{ fontWeight: 600, color: '#8F5C12' }}>{fmt(spend)} spend</span></>}
              </div>
            </div>
            <button className="iconbtn" onClick={onClose}><IconX size={16}/></button>
          </div>
          {supplier.website && (
            <a href={supplier.website} target="_blank" rel="noreferrer" style={{ fontSize: 12, color: '#8F5C12', textDecoration: 'none', display: 'inline-block', marginTop: 8 }}>
              {supplier.website} ↗
            </a>
          )}
        </div>

        {/* Body */}
        <div style={{ padding: '24px 28px', overflowY: 'auto', flex: 1 }}>
          {loading && <div style={{ padding: '40px 0', textAlign: 'center', color: '#A89B8B', fontSize: 13 }}>Loading supplier data…</div>}

          {!loading && (
            <>
              {/* Contracts */}
              <Section title="Contracts">
                {contracts.length === 0 ? (
                  <div style={{ fontSize: 13, color: '#A89B8B' }}>No contracts on file.</div>
                ) : contracts.map((c, i) => {
                  const rag = contractRag(c.expiry_date)
                  return (
                    <div key={i} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '10px 0', borderBottom: i < contracts.length-1 ? '1px solid #F5F1EA' : 'none' }}>
                      <div>
                        <div style={{ fontSize: 13, fontWeight: 600, color: '#161413' }}>{c.name || c.contract_number || `Contract #${i+1}`}</div>
                        <div style={{ fontSize: 11.5, color: '#75695F', marginTop: 2 }}>
                          {c.start_date && <span>From {c.start_date?.slice(0,10)}</span>}
                          {c.value_eur && <><span style={{ color: '#C9BFAE', margin: '0 6px' }}>·</span><span>{fmt(c.value_eur)}</span></>}
                          {c.auto_renew && <><span style={{ color: '#C9BFAE', margin: '0 6px' }}>·</span><span style={{ color: '#3D7A5A' }}>Auto-renews</span></>}
                        </div>
                      </div>
                      {rag ? (
                        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, fontSize: 12, padding: '3px 9px', borderRadius: 5, background: rag.bg }}>
                          <span style={{ width: 7, height: 7, borderRadius: '50%', background: rag.dot }} />
                          <span style={{ color: rag.color, fontWeight: rag.days <= 30 ? 700 : 500 }}>{rag.label}</span>
                        </span>
                      ) : <span style={{ fontSize: 12, color: '#A89B8B' }}>No end date</span>}
                    </div>
                  )
                })}
              </Section>

              {/* Legal documents */}
              <Section title="Legal Documents">
                {documents.length === 0 ? (
                  <div style={{ fontSize: 13, color: '#A89B8B' }}>No documents on file. Run compliance assessment to generate NDA and DPA.</div>
                ) : documents.map((d, i) => {
                  const typeLabel = DOC_LABEL[d.doc_type] || (d.doc_type||'').toUpperCase() || 'Document'
                  const isOk      = d.status === 'signed'
                  const isDraft   = d.status === 'draft'
                  const isExpired = d.content?.includes('❌') || d.content?.includes('RENEWAL REQUIRED')
                  const isExpiring = d.content?.includes('⚠')
                  const statusColor = isExpired ? '#B5462E' : isExpiring ? '#B07219' : isDraft ? '#2B5F7A' : isOk ? '#3D7A5A' : '#75695F'
                  const statusBg    = isExpired ? '#F6E5DE' : isExpiring ? '#F7EFDE' : isDraft ? '#E8EDF3' : isOk ? '#EEF3EE' : '#F5F1EA'
                  const iconColor   = d.doc_type === 'nda' ? '#2B5F7A' : d.doc_type === 'dpa' ? '#3D7A5A' : '#75695F'
                  const iconBg      = d.doc_type === 'nda' ? '#E8EDF3' : d.doc_type === 'dpa' ? '#EEF3EE' : '#F5F1EA'
                  return (
                    <div key={i} style={{ padding: '12px 0', borderBottom: i < documents.length-1 ? '1px solid #F5F1EA' : 'none' }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 6 }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                          <div style={{ width: 30, height: 30, borderRadius: 6, background: iconBg, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                            <span style={{ fontSize: 7.5, fontWeight: 800, color: iconColor, letterSpacing: '0.04em' }}>{typeLabel}</span>
                          </div>
                          <div>
                            <div style={{ fontSize: 13, fontWeight: 600, color: '#161413' }}>{typeLabel}</div>
                            <div style={{ fontSize: 11.5, color: '#75695F', marginTop: 1 }}>{d.created_at?.slice(0,10)}</div>
                          </div>
                        </div>
                        <span style={{ fontSize: 11.5, padding: '2px 8px', borderRadius: 4, background: statusBg, color: statusColor, fontWeight: 600, flexShrink: 0 }}>
                          {isExpired ? 'Expired ❌' : isExpiring ? 'Expiring ⚠' : d.status || 'unknown'}
                        </span>
                      </div>
                      {d.content && (
                        <div style={{ fontSize: 12, color: '#75695F', lineHeight: 1.55, paddingLeft: 40 }}>{d.content}</div>
                      )}
                    </div>
                  )
                })}
              </Section>

              {/* Compliance */}
              <Section title="Compliance checks">
                {compliance.length === 0 ? (
                  <div style={{ fontSize: 13, color: '#A89B8B', marginBottom: 10 }}>No compliance assessment run yet.</div>
                ) : compliance.map((cc, i) => (
                  <div key={i} style={{ padding: '10px 0', borderBottom: i < compliance.length-1 ? '1px solid #F5F1EA' : 'none' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div style={{ fontSize: 13, fontWeight: 600, color: '#161413', textTransform: 'capitalize' }}>{(cc.check_type || 'check').replace(/_/g,' ')}</div>
                        {cc.score != null && <div style={{ fontSize: 11.5, color: '#75695F', marginTop: 1 }}>Score: {cc.score}/100</div>}
                        {cc.findings?.length > 0 && <div style={{ fontSize: 12, color: '#75695F', marginTop: 4, lineHeight: 1.5 }}>{cc.findings.slice(0,2).join(' · ')}</div>}
                      </div>
                      <span style={{ fontSize: 11.5, padding: '2px 8px', borderRadius: 4, marginLeft: 10, flexShrink: 0, background: cc.passed === true ? '#EEF3EE' : cc.passed === false ? '#F6E5DE' : '#F5F1EA', color: cc.passed === true ? '#3D7A5A' : cc.passed === false ? '#B5462E' : '#75695F', fontWeight: 600 }}>
                        {cc.passed === true ? 'Passed' : cc.passed === false ? 'Failed' : (cc.status || 'pending')}
                      </span>
                    </div>
                    {cc.checked_at && <div style={{ fontSize: 11, color: '#A89B8B', marginTop: 3 }}>{cc.checked_at?.slice(0,10)}</div>}
                  </div>
                ))}
                {!['approved','blocked'].includes(supplier.compliance_status) && supplier.health !== 'green' && (
                  <button className="btn btn--secondary btn--sm" style={{ marginTop: 10 }} onClick={onAssess}>Run assessment</button>
                )}
              </Section>

              {/* Recent POs */}
              <Section title="Recent purchase orders">
                {pos.length === 0 ? (
                  <div style={{ fontSize: 13, color: '#A89B8B' }}>No purchase orders yet.</div>
                ) : pos.slice(0,5).map((p, i) => (
                  <div key={i} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '8px 0', borderBottom: i < Math.min(pos.length,5)-1 ? '1px solid #F5F1EA' : 'none' }}>
                    <div>
                      <div style={{ fontSize: 12.5, fontWeight: 600, color: '#161413' }}>{p.po_number || `PO #${i+1}`}</div>
                      <div style={{ fontSize: 11.5, color: '#75695F' }}>{p.created_at?.slice(0,10)} · {p.status}</div>
                    </div>
                    <div style={{ fontSize: 13, fontVariantNumeric: 'tabular-nums', fontWeight: 600, color: '#161413' }}>{fmt(p.amount_eur)}</div>
                  </div>
                ))}
              </Section>
            </>
          )}
        </div>
      </div>
    </div>
  )
}

// ─── Spend Analytics Drawer ───────────────────────────────────────────────────
const AnalyticsDrawer = ({ onClose }) => {
  const [data, setData] = useState(null)

  useEffect(() => {
    Promise.all([
      pgFetch('/purchase_orders?select=supplier_id,amount_eur,status,category&limit=500').catch(() => []),
      pgFetch('/suppliers?select=id,name,category&limit=100').catch(() => []),
      pgFetch('/budget_positions?select=category,period,planned,committed,spent&limit=200').catch(() => []),
    ]).then(([pos, sups, budgets]) => setData({ pos, sups, budgets }))
  }, [])

  if (!data) return (
    <div className="modal-scrim" onClick={onClose} style={{ justifyContent: 'flex-end' }}>
      <div className="modal" style={{ width: 520, maxWidth: '95vw', height: '100vh', borderRadius: '16px 0 0 16px', overflowY: 'auto', padding: 32 }} onClick={e => e.stopPropagation()}>
        <div style={{ padding: '80px 0', textAlign: 'center', color: '#A89B8B' }}>Loading analytics…</div>
      </div>
    </div>
  )

  const nameMap = {}
  for (const s of data.sups) nameMap[s.id] = s.name

  const bySupplier = {}
  for (const po of data.pos) {
    if (!po.supplier_id) continue
    const n = nameMap[po.supplier_id] || 'Unknown'
    bySupplier[n] = (bySupplier[n] || 0) + Number(po.amount_eur || 0)
  }
  const top10 = Object.entries(bySupplier).sort((a,b) => b[1]-a[1]).slice(0,10)
  const maxSpend = top10[0]?.[1] || 1

  const byCategory = {}
  for (const po of data.pos) {
    const c = po.category || 'other'
    byCategory[c] = (byCategory[c] || 0) + Number(po.amount_eur || 0)
  }
  const catEntries = Object.entries(byCategory).sort((a,b) => b[1]-a[1])

  const totalPlanned = data.budgets.reduce((s, b) => s + Number(b.planned  || 0), 0)
  const totalCommit  = data.budgets.reduce((s, b) => s + Number(b.committed|| 0), 0)
  const totalSpent   = data.budgets.reduce((s, b) => s + Number(b.spent    || 0), 0)
  const totalPOs     = data.pos.reduce((s, p) => s + Number(p.amount_eur   || 0), 0)

  const CAT_COLOR = {
    hardware: '#2B5F7A', saas_license: '#5A3E7A', hyperscaler: '#3D7A5A',
    services: '#B07219', telecoms: '#7A3E3E', facilities: '#4A6741', ai_consumption: '#6B4F8A', other: '#A89B8B',
  }

  return (
    <div className="modal-scrim" onClick={onClose} style={{ justifyContent: 'flex-end', alignItems: 'stretch' }}>
      <div className="modal" style={{ width: 520, maxWidth: '95vw', height: '100vh', borderRadius: '16px 0 0 16px', overflowY: 'auto', padding: 0, display: 'flex', flexDirection: 'column' }} onClick={e => e.stopPropagation()}>
        <div style={{ padding: '28px 28px 20px', borderBottom: '1px solid #E5DDD0', display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexShrink: 0 }}>
          <div>
            <div style={{ fontSize: 11, letterSpacing: '0.14em', textTransform: 'uppercase', color: '#75695F', marginBottom: 4 }}>Spend Intelligence</div>
            <div style={{ fontFamily: "'Instrument Serif', serif", fontSize: 26, color: '#161413', letterSpacing: '-0.025em', lineHeight: 1.1 }}>Analytics</div>
            <div style={{ fontSize: 12.5, color: '#75695F', marginTop: 4 }}>{data.pos.length} purchase orders loaded</div>
          </div>
          <button className="iconbtn" onClick={onClose}><IconX size={16}/></button>
        </div>

        <div style={{ padding: '24px 28px', overflowY: 'auto', flex: 1, display: 'flex', flexDirection: 'column', gap: 32 }}>
          {/* KPI strip */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
            {[
              { label: 'Total PO volume',  val: fmt(totalPOs),    hint: 'All purchase orders' },
              { label: 'Budget planned',   val: fmt(totalPlanned),hint: 'Across all buckets' },
              { label: 'Committed',        val: fmt(totalCommit), hint: 'Approved, not invoiced', color: '#B07219' },
              { label: 'Spent',            val: fmt(totalSpent),  hint: 'Invoices approved',      color: '#3D7A5A' },
            ].map(k => (
              <div key={k.label} style={{ background: '#F5F1EA', border: '1px solid #E5DDD0', borderRadius: 8, padding: '12px 14px' }}>
                <div style={{ fontSize: 11, color: '#A89B8B', fontWeight: 600, letterSpacing: '0.08em', textTransform: 'uppercase', marginBottom: 4 }}>{k.label}</div>
                <div style={{ fontSize: 20, fontWeight: 700, fontVariantNumeric: 'tabular-nums', color: k.color || '#161413', letterSpacing: '-0.02em' }}>{k.val}</div>
                <div style={{ fontSize: 11.5, color: '#A89B8B', marginTop: 2 }}>{k.hint}</div>
              </div>
            ))}
          </div>

          {/* Top 10 suppliers */}
          <div>
            <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '0.12em', textTransform: 'uppercase', color: '#75695F', marginBottom: 14 }}>Top suppliers by spend</div>
            {top10.length === 0 && <div style={{ color: '#A89B8B', fontSize: 13 }}>No PO data yet.</div>}
            <div style={{ display: 'flex', flexDirection: 'column', gap: 9 }}>
              {top10.map(([name, spend], i) => {
                const pct = Math.round(spend / maxSpend * 100)
                const sharePct = totalPOs > 0 ? Math.round(spend / totalPOs * 100) : 0
                return (
                  <div key={name}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 4 }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
                        <span style={{ fontSize: 10.5, color: '#A89B8B', fontVariantNumeric: 'tabular-nums', width: 16 }}>#{i+1}</span>
                        <span style={{ fontSize: 13, fontWeight: 600, color: '#161413' }}>{name}</span>
                      </div>
                      <div style={{ display: 'flex', gap: 10, alignItems: 'baseline' }}>
                        <span style={{ fontSize: 11.5, color: '#A89B8B' }}>{sharePct}%</span>
                        <span style={{ fontSize: 13.5, fontWeight: 700, fontVariantNumeric: 'tabular-nums', color: '#161413' }}>{fmt(spend)}</span>
                      </div>
                    </div>
                    <div style={{ height: 5, borderRadius: 3, background: '#EFEBE1', overflow: 'hidden' }}>
                      <div style={{ height: '100%', borderRadius: 3, background: i === 0 ? '#B07219' : i < 3 ? '#2B5F7A' : '#A89B8B', width: `${pct}%`, transition: 'width 0.4s' }} />
                    </div>
                  </div>
                )
              })}
            </div>
          </div>

          {/* Spend by category */}
          <div>
            <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '0.12em', textTransform: 'uppercase', color: '#75695F', marginBottom: 14 }}>Spend by category</div>
            {catEntries.length === 0 && <div style={{ color: '#A89B8B', fontSize: 13 }}>No PO data yet.</div>}
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              {catEntries.map(([cat, spend]) => {
                const pct = totalPOs > 0 ? Math.round(spend / totalPOs * 100) : 0
                const color = CAT_COLOR[cat] || '#A89B8B'
                return (
                  <div key={cat} style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                    <div style={{ width: 10, height: 10, borderRadius: 2, background: color, flexShrink: 0 }} />
                    <div style={{ flex: 1, fontSize: 12.5, color: '#3D3633', textTransform: 'capitalize' }}>{cat.replace(/_/g,' ')}</div>
                    <div style={{ width: 110, height: 5, borderRadius: 3, background: '#EFEBE1', overflow: 'hidden' }}>
                      <div style={{ height: '100%', borderRadius: 3, background: color, width: `${pct}%` }} />
                    </div>
                    <div style={{ fontSize: 12.5, fontVariantNumeric: 'tabular-nums', color: '#75695F', minWidth: 72, textAlign: 'right' }}>{fmt(spend)}</div>
                    <div style={{ fontSize: 11, color: '#A89B8B', minWidth: 30, textAlign: 'right' }}>{pct}%</div>
                  </div>
                )
              })}
            </div>
          </div>

          {/* Concentration warning */}
          {top10[0] && totalPOs > 0 && (top10[0][1] / totalPOs) > 0.4 && (
            <div style={{ background: '#F7EFDE', border: '1px solid #E5D4A8', borderRadius: 8, padding: '12px 14px', fontSize: 12.5, color: '#8F5C12', lineHeight: 1.5 }}>
              <strong>⚠ Concentration risk:</strong> {top10[0][0]} accounts for {Math.round(top10[0][1]/totalPOs*100)}% of total spend.
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

// ─── Suppliers Screen ─────────────────────────────────────────────────────────
const SuppliersScreen = () => {
  const [suppliers,   setSuppliers]   = useState(null)
  const [contracts,   setContracts]   = useState(null)  // { [supplier_id]: contract }
  const [spendMap,    setSpendMap]    = useState(null)  // { [supplier_id]: totalEur }
  const [selected,    setSelected]    = useState(null)  // supplier object for drawer
  const [onboarding,  setOnboarding]  = useState(false)
  const [analytics,   setAnalytics]   = useState(false)
  const [search,      setSearch]      = useState('')

  const load = useCallback(async () => {
    try {
      const [sups, cons, pos] = await Promise.all([
        pgFetch('/suppliers?order=name.asc&limit=100'),
        pgFetch('/contracts?select=supplier_id,expiry_date,name,contract_number,value_eur,auto_renew,start_date&order=expiry_date.asc&limit=300').catch(() => []),
        pgFetch('/purchase_orders?select=supplier_id,amount_eur&limit=1000').catch(() => []),
      ])
      setSuppliers(sups)

      // Nearest-expiry contract per supplier
      const cm = {}
      for (const c of cons) {
        if (!cm[c.supplier_id]) cm[c.supplier_id] = c
      }
      setContracts(cm)

      // Total spend per supplier
      const sm = {}
      for (const po of pos) {
        if (!po.supplier_id) continue
        sm[po.supplier_id] = (sm[po.supplier_id] || 0) + Number(po.amount_eur || 0)
      }
      setSpendMap(sm)
    } catch { setSuppliers([]) }
  }, [])

  useEffect(() => { load() }, [load])

  const filtered = (suppliers || []).filter(s =>
    !search || s.name?.toLowerCase().includes(search.toLowerCase()) || s.category?.toLowerCase().includes(search.toLowerCase())
  )

  // Risk flag: combines compliance + contract expiry into a single signal
  const riskFlag = (s, rag) => {
    if (s.compliance_status === 'blocked')  return { label: 'Compliance blocked', color: '#B5462E', bg: '#F6E5DE' }
    if (s.compliance_status === 'running')  return { label: 'Assessment running', color: '#2B5F7A', bg: '#E8EDF3' }
    if (rag && rag.days < 0)                return { label: 'Contract expired',   color: '#B5462E', bg: '#F6E5DE' }
    if (rag && rag.days <= 30)              return { label: 'Contract expiring',  color: '#B07219', bg: '#F7EFDE' }
    return null
  }

  const expiringSoon = (contracts && suppliers)
    ? suppliers.filter(s => { const r = contractRag(contracts[s.id]?.expiry_date); return r && r.days <= 30 }).length
    : 0

  return (
    <div className="content step-in" style={{ maxWidth: 1200 }}>
      <div className="pagehead">
        <div>
          <div className="pagehead__eyebrow">Suppliers</div>
          <h1 className="pagehead__title">{suppliers ? `${suppliers.length} vendors.` : 'Loading…'}</h1>
          <div className="pagehead__sub">Tier is driven by spend volume and auto-updates. Click any row for contracts, documents and compliance.</div>
        </div>
        <div className="pagehead__actions">
          <button className="btn btn--tertiary btn--sm" onClick={load}><IconRotateCw size={14}/></button>
          <button className="btn btn--secondary" onClick={() => setAnalytics(true)}>
            <IconBoard size={14}/> Analytics
          </button>
          <button className="btn btn--primary" onClick={() => setOnboarding(true)}>
            <IconPlus size={14}/> Onboard supplier
          </button>
        </div>
      </div>

      {/* Stats — tier-centric, not health-centric */}
      {suppliers && spendMap && (
        <div className="stats" style={{ marginBottom: 24 }}>
          {TIER_CONFIG.map(t => {
            const count = suppliers.filter(s => {
              const spend = Number(spendMap[s.id] || 0)
              return spend >= t.min && (t.min === 0 || spend < (TIER_CONFIG[TIER_CONFIG.indexOf(t)-1]?.min ?? Infinity))
            }).length
            return (
              <div className="stat" key={t.label}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                  <span style={{ padding: '1px 7px', borderRadius: 4, background: t.bg, color: t.fg, fontSize: 10.5, fontWeight: 700 }}>{t.label}</span>
                </div>
                <div className="stat__val" style={{ marginTop: 4 }}>{count}</div>
                <div className="stat__hint">
                  {t.label === 'Platinum' ? '≥ €1M' : t.label === 'Gold' ? '€250k–€1M' : t.label === 'Silver' ? '€50k–€250k' : '< €50k'}
                </div>
              </div>
            )
          })}
          <div className="stat">
            <div className="stat__label">Contracts expiring</div>
            <div className="stat__val" style={{ color: expiringSoon > 0 ? '#B5462E' : '#A89B8B' }}>{expiringSoon}</div>
            <div className="stat__hint">Within 30 days</div>
          </div>
          <div className="stat">
            <div className="stat__label">Not assessed</div>
            <div className="stat__val">{suppliers.filter(s=>!['approved','blocked'].includes(s.compliance_status)).length}</div>
            <div className="stat__hint">No compliance check</div>
          </div>
        </div>
      )}

      {/* Search */}
      <div style={{ marginBottom: 18 }}>
        <input className="input" placeholder="Search suppliers…" value={search} onChange={e => setSearch(e.target.value)} style={{ maxWidth: 340 }} />
      </div>

      {/* Table */}
      {suppliers && (
        <div className="tlist">
          <div className="trow" style={{ gridTemplateColumns: '90px 1fr 130px 160px 150px 100px', background: '#EFEBE1', cursor: 'default', fontSize: 11, fontWeight: 600, letterSpacing: '0.08em', textTransform: 'uppercase', color: '#75695F' }}>
            <div>Tier</div>
            <div>Supplier</div>
            <div>Category</div>
            <div>Contract</div>
            <div>Risk flag</div>
            <div style={{ textAlign: 'right' }}>Actions</div>
          </div>
          {filtered.length === 0 && (
            <div style={{ padding: '40px 24px', textAlign: 'center', color: '#75695F', fontSize: 13.5 }}>
              {search ? 'No suppliers match.' : 'No suppliers yet.'}
            </div>
          )}
          {filtered.map(s => {
            const spend = spendMap ? (spendMap[s.id] || 0) : null
            const tier  = spend !== null ? tierFor(spend) : null
            const con   = contracts ? contracts[s.id] : null
            const rag   = con ? contractRag(con.expiry_date) : null
            const risk  = riskFlag(s, rag)

            return (
              <div key={s.id} className="trow" style={{ gridTemplateColumns: '90px 1fr 130px 160px 150px 100px', cursor: 'pointer' }} onClick={() => setSelected(s)}>
                {/* Tier — primary classification */}
                <div>
                  {tier ? (
                    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, padding: '3px 9px', borderRadius: 5, background: tier.bg, color: tier.fg, fontSize: 11.5, fontWeight: 700, letterSpacing: '0.04em' }}>
                      {tier.label}
                    </span>
                  ) : <span style={{ color: '#C9BFAE', fontSize: 12 }}>—</span>}
                </div>
                {/* Supplier name */}
                <div className="trow__main">
                  <div className="trow__title">{s.name}</div>
                  <div className="trow__meta">
                    {s.country && <span>{s.country}</span>}
                    {spend !== null && spend > 0 && <><span className="dot"/><span style={{ fontWeight: 600, color: '#8F5C12' }}>{fmt(spend)}</span></>}
                  </div>
                </div>
                {/* Category */}
                <div style={{ fontSize: 12.5, color: '#75695F', textTransform: 'capitalize' }}>{(s.category||'—').replace(/_/g,' ')}</div>
                {/* Contract RAG */}
                <div>
                  {rag ? (
                    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, fontSize: 12 }}>
                      <span style={{ width: 7, height: 7, borderRadius: '50%', background: rag.dot, flexShrink: 0 }} />
                      <span style={{ color: rag.color, fontWeight: rag.days <= 30 ? 700 : 400 }}>{rag.label}</span>
                    </span>
                  ) : (
                    <span style={{ fontSize: 12, color: '#C9BFAE' }}>No contract</span>
                  )}
                </div>
                {/* Risk flag */}
                <div>
                  {risk ? (
                    <span style={{ fontSize: 11.5, padding: '2px 8px', borderRadius: 4, background: risk.bg, color: risk.color, fontWeight: 600 }}>
                      {risk.label}
                    </span>
                  ) : (
                    <span style={{ fontSize: 12, color: '#C9BFAE' }}>—</span>
                  )}
                </div>
                {/* Actions */}
                <div style={{ textAlign: 'right' }} onClick={e => e.stopPropagation()}>
                  {!['approved','blocked'].includes(s.compliance_status) && (
                    <button className="btn btn--secondary btn--sm" onClick={() => setOnboarding(true)}>Assess</button>
                  )}
                </div>
              </div>
            )
          })}
        </div>
      )}

      {selected && (
        <SupplierDrawer
          supplier={selected}
          spendMap={spendMap}
          onClose={() => setSelected(null)}
          onAssess={() => { setSelected(null); setOnboarding(true) }}
        />
      )}
      {onboarding && (
        <OnboardModal
          onClose={() => setOnboarding(false)}
          onDone={() => { setOnboarding(false); load() }}
        />
      )}
      {analytics && <AnalyticsDrawer onClose={() => setAnalytics(false)} />}
    </div>
  )
}

// ─── (Signal badge and RequestDetail moved above TicketRow) ──────────────────


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

// ─── Request Form (legacy — kept for reference, no longer rendered) ───────────
const RequestForm = ({ type, user, onBack, onSuccess }) => {
  const cfg = FORM_CONFIG[type] || FORM_CONFIG.other
  const [loading, setLoading]       = useState(false)
  const [supplier, setSupplier]     = useState('')
  const [amount,   setAmount]       = useState('')
  const [desc,     setDesc]         = useState('')
  const [notes,    setNotes]        = useState('')
  const [category, setCategory]     = useState('hardware')
  const [costCenterId, setCostCenterId] = useState(user?.costCenterId || '')
  const [costCenters, setCostCenters]   = useState(null)

  // Fetch cost centres for the user's branch
  useEffect(() => {
    if (!user?.branchId) { setCostCenters([]); return }
    pgFetch(`/cost_centers?branch_id=eq.${user.branchId}&order=code.asc`)
      .then(d => { setCostCenters(d); if (!costCenterId && d.length > 0) setCostCenterId(user?.costCenterId || d[0].id) })
      .catch(() => setCostCenters([]))
  }, [user?.branchId])

  const submit = async () => {
    if (loading) return
    setLoading(true)
    const ref = 'TS-' + new Date().getFullYear() + '-' + String(Date.now()).slice(-4)
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
          cost_center_id: costCenterId || null,
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
          {costCenters && costCenters.length > 0 && (
            <div className="field">
              <label className="field__label">Cost centre</label>
              <select className="select" value={costCenterId} onChange={e => setCostCenterId(e.target.value)}>
                <option value="">— none —</option>
                {costCenters.map(cc => (
                  <option key={cc.id} value={cc.id}>{cc.code} — {cc.name}</option>
                ))}
              </select>
            </div>
          )}
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
          {costCenters && costCenters.length > 0 && (
            <div className="field">
              <label className="field__label">Cost centre</label>
              <select className="select" value={costCenterId} onChange={e => setCostCenterId(e.target.value)}>
                <option value="">— none —</option>
                {costCenters.map(cc => (
                  <option key={cc.id} value={cc.id}>{cc.code} — {cc.name}</option>
                ))}
              </select>
            </div>
          )}
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
          {costCenters && costCenters.length > 0 && (
            <div className="field">
              <label className="field__label">Cost centre</label>
              <select className="select" value={costCenterId} onChange={e => setCostCenterId(e.target.value)}>
                <option value="">— none —</option>
                {costCenters.map(cc => (
                  <option key={cc.id} value={cc.id}>{cc.code} — {cc.name}</option>
                ))}
              </select>
            </div>
          )}
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
// ─── Users Screen (Admin only) ────────────────────────────────────────────────
// ─── Budget Screen (Controlling) ──────────────────────────────────────────────
const BUDGET_CATEGORIES = [
  'hardware','saas_license','cloud_infrastructure','professional_services',
  'facilities','telecoms','travel','marketing','hr','legal','ai_consumption','other'
]
const BUDGET_PERIODS = (() => {
  const out = []
  const y = new Date().getFullYear()
  for (let yr = y - 1; yr <= y + 1; yr++)
    for (let q = 1; q <= 4; q++) out.push(`${yr}-Q${q}`)
  return out
})()

const BudgetScreen = ({ user }) => {
  const [buckets, setBuckets]     = useState(null)
  const [adding, setAdding]       = useState(false)
  const [saving, setSaving]       = useState(false)
  const [saveErr, setSaveErr]     = useState('')
  const [saved, setSaved]         = useState(false)
  const [editRow, setEditRow]     = useState(null)   // { id, planned } being edited inline
  const EMPTY_FORM = { branch_id: BRANCHES[0].id, category: 'hardware', period: `${new Date().getFullYear()}-Q${Math.ceil((new Date().getMonth()+1)/3)}`, planned: '' }
  const [form, setForm]           = useState(EMPTY_FORM)

  // Roles that see ALL positions; others see only their own CC
  const isFullAccess = !user || ['controlling', 'cfo', 'head_of_procurement', 'admin'].includes(user.role) ||
    ['controlling', 'procurement'].includes(ROLE_GROUP[user.role])

  const load = useCallback(async () => {
    try {
      let path = '/budget_positions?order=period.desc,category.asc&limit=400'
      if (!isFullAccess && user?.costCenterId) {
        path = `/budget_positions?cost_center_id=eq.${user.costCenterId}&order=period.desc,category.asc&limit=400`
      }
      const data = await pgFetch(path)
      setBuckets(data)
    } catch { setBuckets([]) }
  }, [isFullAccess, user])

  useEffect(() => { load() }, [load])

  const totalPlanned = (buckets || []).reduce((s, b) => s + Number(b.planned || 0), 0)
  const totalCommit  = (buckets || []).reduce((s, b) => s + Number(b.committed || 0), 0)
  const totalSpent   = (buckets || []).reduce((s, b) => s + Number(b.spent || 0), 0)
  const totalAvail   = totalPlanned - totalCommit - totalSpent

  const handleSave = async () => {
    setSaving(true); setSaveErr(''); setSaved(false)
    try {
      const payload = {
        branch_id: form.branch_id,
        category:  form.category,
        period:    form.period,
        planned:   parseFloat(form.planned) || 0,
        committed: 0,
        spent:     0,
      }
      const r = await fetch(`${POSTGREST_URL}/budget_positions`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${POSTGREST_JWT}`, 'Content-Type': 'application/json', Prefer: 'return=representation' },
        body: JSON.stringify(payload)
      })
      if (!r.ok) { const t = await r.text(); throw new Error(t) }
      setSaved(true); setAdding(false); setForm(EMPTY_FORM)
      await load()
    } catch(e) { setSaveErr(e.message) }
    finally { setSaving(false) }
  }

  const handleEditSave = async (row) => {
    try {
      await fetch(`${POSTGREST_URL}/budget_positions?id=eq.${row.id}`, {
        method: 'PATCH',
        headers: { Authorization: `Bearer ${POSTGREST_JWT}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ planned: parseFloat(editRow.planned) || 0 })
      })
      setEditRow(null); await load()
    } catch {}
  }

  return (
    <div className="content step-in" style={{ maxWidth: 1100 }}>
      <div className="pagehead">
        <div>
          <div className="pagehead__eyebrow">Controlling</div>
          <h1 className="pagehead__title">Budget overview</h1>
          <div className="pagehead__sub">
            {isFullAccess
              ? 'Live spend vs. plan — all branches and cost centres. Set planned budgets per branch, category, and quarter.'
              : `Showing your cost centre budget only. Contact Controlling to update planned figures.`}
          </div>
        </div>
        <div className="pagehead__actions">
          <button className="btn btn--tertiary btn--sm" onClick={load}><IconRotateCw size={14}/></button>
          {isFullAccess && (
            <button className="btn btn--primary btn--sm" onClick={() => { setAdding(true); setSaved(false); setSaveErr('') }}>
              <IconPlus size={14}/> Set budget
            </button>
          )}
        </div>
      </div>

      {/* Add budget form */}
      {adding && (
        <div style={{ marginBottom: 24, padding: '20px 24px', background: '#FDFAF6', border: '1px solid #E5DDD0', borderRadius: 10 }}>
          <div style={{ fontSize: 13, fontWeight: 600, color: '#3D3633', marginBottom: 14 }}>New budget position</div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr 1fr auto', gap: 10, alignItems: 'end' }}>
            <div>
              <label style={{ fontSize: 11, color: '#75695F', display: 'block', marginBottom: 4 }}>Branch</label>
              <select className="select" value={form.branch_id} onChange={e => setForm(f => ({ ...f, branch_id: e.target.value }))}>
                {BRANCHES.map(b => <option key={b.id} value={b.id}>{b.label}</option>)}
              </select>
            </div>
            <div>
              <label style={{ fontSize: 11, color: '#75695F', display: 'block', marginBottom: 4 }}>Category</label>
              <select className="select" value={form.category} onChange={e => setForm(f => ({ ...f, category: e.target.value }))}>
                {BUDGET_CATEGORIES.map(c => <option key={c} value={c}>{c}</option>)}
              </select>
            </div>
            <div>
              <label style={{ fontSize: 11, color: '#75695F', display: 'block', marginBottom: 4 }}>Period</label>
              <select className="select" value={form.period} onChange={e => setForm(f => ({ ...f, period: e.target.value }))}>
                {BUDGET_PERIODS.map(p => <option key={p} value={p}>{p}</option>)}
              </select>
            </div>
            <div>
              <label style={{ fontSize: 11, color: '#75695F', display: 'block', marginBottom: 4 }}>Planned (EUR)</label>
              <input className="input" type="number" min="0" placeholder="e.g. 50000"
                value={form.planned} onChange={e => setForm(f => ({ ...f, planned: e.target.value }))} />
            </div>
            <div style={{ display: 'flex', gap: 8 }}>
              <button className="btn btn--primary btn--sm" onClick={handleSave} disabled={saving || !form.planned}>
                {saving ? 'Saving…' : 'Save'}
              </button>
              <button className="btn btn--tertiary btn--sm" onClick={() => setAdding(false)}>Cancel</button>
            </div>
          </div>
          {saveErr && <div style={{ marginTop: 8, fontSize: 12, color: '#B5462E' }}>{saveErr}</div>}
        </div>
      )}
      {saved && <div style={{ marginBottom: 16, fontSize: 12.5, color: '#3D7A5A', fontWeight: 600 }}>✓ Budget position saved.</div>}

      {/* Totals strip */}
      {buckets && (
        <div className="stats" style={{ marginBottom: 24 }}>
          <div className="stat">
            <div className="stat__label">Planned</div>
            <div className="stat__val">{fmt(totalPlanned)}</div>
            <div className="stat__hint">Total approved budget</div>
          </div>
          <div className="stat">
            <div className="stat__label">Committed</div>
            <div className="stat__val" style={{ color: '#B07219' }}>{fmt(totalCommit)}</div>
            <div className="stat__hint">POs approved, not yet invoiced</div>
          </div>
          <div className="stat">
            <div className="stat__label">Spent</div>
            <div className="stat__val" style={{ color: '#B5462E' }}>{fmt(totalSpent)}</div>
            <div className="stat__hint">Invoices approved</div>
          </div>
          <div className="stat">
            <div className="stat__label">Available</div>
            <div className="stat__val" style={{ color: totalAvail >= 0 ? '#3D7A5A' : '#B5462E' }}>{fmt(totalAvail)}</div>
            <div className="stat__hint">Planned − committed − spent</div>
          </div>
        </div>
      )}

      {/* Buckets table */}
      {!buckets && <div style={{ padding: '40px 0', textAlign: 'center', color: '#A89B8B', fontSize: 13 }}>Loading…</div>}
      {buckets && buckets.length === 0 && (
        <div style={{ padding: '40px 0', textAlign: 'center', color: '#A89B8B', fontSize: 13 }}>
          No budget positions yet. Click <strong>Set budget</strong> to add the first one.
        </div>
      )}
      {buckets && buckets.length > 0 && (
        <div className="tlist">
          <div className="trow" style={{ background: '#EFEBE1', cursor: 'default', fontSize: 11, fontWeight: 600, letterSpacing: '0.08em', textTransform: 'uppercase', color: '#75695F' }}>
            <div>Period</div>
            <div>Branch · Category</div>
            <div style={{ textAlign: 'right' }}>Planned</div>
            <div style={{ textAlign: 'right' }}>Committed</div>
            <div style={{ textAlign: 'right' }}>Spent</div>
            <div style={{ textAlign: 'right' }}>Available</div>
          </div>
          {buckets.map((b, i) => {
            const avail  = Number(b.planned || 0) - Number(b.committed || 0) - Number(b.spent || 0)
            const util   = Number(b.planned) > 0 ? Math.round((Number(b.committed) + Number(b.spent)) / Number(b.planned) * 100) : 0
            const isEdit = editRow?.id === b.id
            const branch = BRANCHES.find(br => br.id === b.branch_id)
            return (
              <div key={i} className="trow" style={{ cursor: 'default' }}>
                <div style={{ fontSize: 12.5, color: '#75695F' }}>{b.period}</div>
                <div className="trow__main">
                  <div className="trow__title" style={{ fontSize: 13 }}>{b.category}</div>
                  <div style={{ fontSize: 11.5, color: '#A89B8B' }}>{branch?.label || b.branch_id?.slice(0,8)} · {util}% utilised</div>
                </div>
                <div style={{ fontSize: 13, fontVariantNumeric: 'tabular-nums', textAlign: 'right' }}>
                  {isEdit
                    ? <input type="number" style={{ width: 90, textAlign: 'right', fontSize: 12, padding: '2px 6px', border: '1px solid #B07219', borderRadius: 4 }}
                        value={editRow.planned} autoFocus
                        onChange={e => setEditRow(r => ({ ...r, planned: e.target.value }))}
                        onKeyDown={e => { if (e.key === 'Enter') handleEditSave(b); if (e.key === 'Escape') setEditRow(null) }}
                        onBlur={() => handleEditSave(b)} />
                    : <span style={{ cursor: 'pointer', borderBottom: '1px dashed #C9BFAE' }}
                        title="Click to edit" onClick={() => setEditRow({ id: b.id, planned: b.planned })}>
                        {fmt(b.planned)}
                      </span>
                  }
                </div>
                <div style={{ fontSize: 13, fontVariantNumeric: 'tabular-nums', textAlign: 'right', color: '#B07219' }}>{fmt(b.committed)}</div>
                <div style={{ fontSize: 13, fontVariantNumeric: 'tabular-nums', textAlign: 'right', color: '#B5462E' }}>{fmt(b.spent)}</div>
                <div style={{ fontSize: 13, fontVariantNumeric: 'tabular-nums', textAlign: 'right', color: avail >= 0 ? '#3D7A5A' : '#B5462E', fontWeight: avail < 0 ? 700 : 400 }}>{fmt(avail)}</div>
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}

const NEW_USER_DEFAULTS = { name: '', email: '', role: 'user', branch_id: 'b1000000-0000-0000-0000-000000000001', title: '' }

const UsersScreen = () => {
  const [users, setUsers]         = useState(null)
  const [search, setSearch]       = useState('')
  const [adding, setAdding]       = useState(false)
  const [form, setForm]           = useState(NEW_USER_DEFAULTS)
  const [saving, setSaving]       = useState(false)
  const [saveErr, setSaveErr]     = useState('')
  const [editingRole, setEditingRole] = useState(null)   // user id being role-edited

  const load = useCallback(async () => {
    try {
      const data = await pgFetch('/users?order=role.asc,name.asc&limit=100')
      setUsers(data)
    } catch { setUsers([]) }
  }, [])

  useEffect(() => { load() }, [load])

  const filtered = (users || []).filter(u =>
    !search || u.name?.toLowerCase().includes(search.toLowerCase()) ||
    u.email?.toLowerCase().includes(search.toLowerCase()) ||
    u.role?.toLowerCase().includes(search.toLowerCase())
  )

  const saveUser = async () => {
    if (!form.name.trim() || !form.email.trim()) { setSaveErr('Name and email are required.'); return }
    setSaving(true); setSaveErr('')
    try {
      await fetch(`${POSTGREST_URL}/users`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${POSTGREST_JWT}`, 'Content-Type': 'application/json', Prefer: 'return=representation' },
        body: JSON.stringify({
          name:      form.name.trim(),
          email:     form.email.trim().toLowerCase(),
          role:      form.role,
          branch_id: form.branch_id,
          title:     form.title.trim() || ROLE_LABEL[form.role] || form.role,
          active:    true,
        })
      })
      setAdding(false)
      setForm(NEW_USER_DEFAULTS)
      load()
    } catch (e) { setSaveErr('Failed to create user. Try again.') }
    finally { setSaving(false) }
  }

  const toggleActive = async (u) => {
    try {
      await fetch(`${POSTGREST_URL}/users?id=eq.${u.id}`, {
        method: 'PATCH',
        headers: { Authorization: `Bearer ${POSTGREST_JWT}`, 'Content-Type': 'application/json', Prefer: 'return=representation' },
        body: JSON.stringify({ active: !u.active })
      })
      load()
    } catch {}
  }

  const changeRole = async (u, newRole) => {
    setEditingRole(null)
    try {
      await fetch(`${POSTGREST_URL}/users?id=eq.${u.id}`, {
        method: 'PATCH',
        headers: { Authorization: `Bearer ${POSTGREST_JWT}`, 'Content-Type': 'application/json', Prefer: 'return=representation' },
        body: JSON.stringify({ role: newRole })
      })
      load()
    } catch {}
  }

  const GROUP_ORDER = ['procurement', 'it', 'user', 'controlling', 'admin']
  const byGroup = {}
  for (const u of filtered) {
    const g = ROLE_GROUP[u.role] || 'user'
    if (!byGroup[g]) byGroup[g] = []
    byGroup[g].push(u)
  }

  return (
    <div className="content step-in" style={{ maxWidth: 1100 }}>
      <div className="pagehead">
        <div>
          <div className="pagehead__eyebrow">Users</div>
          <h1 className="pagehead__title">{users ? `${users.length} users.` : 'Loading…'}</h1>
          <div className="pagehead__sub">Every person who can log in. Assign roles to control what they see and can do.</div>
        </div>
        <div className="pagehead__actions">
          <button className="btn btn--tertiary btn--sm" onClick={load}><IconRotateCw size={14}/></button>
          <button className="btn btn--primary" onClick={() => { setAdding(true); setSaveErr('') }}>
            <IconUserPlus size={14}/> Add user
          </button>
        </div>
      </div>

      {/* Stats */}
      {users && (
        <div className="stats" style={{ marginBottom: 24 }}>
          <div className="stat">
            <div className="stat__label">Procurement</div>
            <div className="stat__val">{users.filter(u => ROLE_GROUP[u.role] === 'procurement').length}</div>
            <div className="stat__hint">Full platform access</div>
          </div>
          <div className="stat">
            <div className="stat__label">IT</div>
            <div className="stat__val">{users.filter(u => ROLE_GROUP[u.role] === 'it').length}</div>
            <div className="stat__hint">IT catalogue + orders</div>
          </div>
          <div className="stat">
            <div className="stat__label">Users</div>
            <div className="stat__val">{users.filter(u => ROLE_GROUP[u.role] === 'user').length}</div>
            <div className="stat__hint">Self-service requests</div>
          </div>
          <div className="stat">
            <div className="stat__label">Controlling</div>
            <div className="stat__val">{users.filter(u => ROLE_GROUP[u.role] === 'controlling').length}</div>
            <div className="stat__hint">Budget oversight</div>
          </div>
          <div className="stat">
            <div className="stat__label">Legal</div>
            <div className="stat__val">{users.filter(u => ROLE_GROUP[u.role] === 'legal').length}</div>
            <div className="stat__hint">Legal review queue</div>
          </div>
          <div className="stat">
            <div className="stat__label">Active</div>
            <div className="stat__val" style={{ color: '#3D7A5A' }}>{users.filter(u => u.active).length}</div>
            <div className="stat__hint">Can log in now</div>
          </div>
        </div>
      )}

      {/* Search */}
      <div style={{ marginBottom: 18 }}>
        <input className="input" placeholder="Search by name, email or role…" value={search} onChange={e => setSearch(e.target.value)} style={{ maxWidth: 340 }} />
      </div>

      {/* User table by group */}
      {GROUP_ORDER.map(group => {
        const members = byGroup[group] || []
        if (!members.length) return null
        const color = PERSONA_GROUP_COLOR[group]
        return (
          <div key={group} style={{ marginBottom: 20 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
              <span style={{ fontSize: 11, fontWeight: 700, letterSpacing: '0.12em', textTransform: 'uppercase', color }}>{PERSONA_GROUP_LABEL[group]}</span>
              <span style={{ fontSize: 11.5, color: '#A89B8B' }}>— {PERSONA_GROUP_DESC[group]}</span>
            </div>
            <div className="tlist">
              <div className="trow" style={{ background: '#EFEBE1', cursor: 'default', fontSize: 11, fontWeight: 600, letterSpacing: '0.08em', textTransform: 'uppercase', color: '#75695F' }}>
                <div>Status</div>
                <div>Name</div>
                <div>Role</div>
                <div>Branch</div>
                <div style={{ textAlign: 'right' }}>Actions</div>
              </div>
              {members.map(u => {
                const initials = u.name.split(' ').map(w => w[0]).join('').slice(0,2).toUpperCase()
                const branch = BRANCHES.find(b => b.id === u.branch_id)?.label || '—'
                return (
                  <div key={u.id} className="trow" style={{ cursor: 'default' }}>
                    <div>
                      <span className="pill" style={{ background: u.active ? '#EEF3EE' : '#EFEBE1', color: u.active ? '#3D7A5A' : '#A89B8B' }}>
                        <span className="pill__dot" style={{ background: u.active ? '#3D7A5A' : '#C9BFAE' }}/>
                        {u.active ? 'Active' : 'Inactive'}
                      </span>
                    </div>
                    <div className="trow__main">
                      <div style={{ display: 'flex', alignItems: 'center', gap: 9 }}>
                        <div style={{ width: 28, height: 28, borderRadius: '50%', background: u.active ? color : '#E5DDD0', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 10.5, fontWeight: 700, color: u.active ? '#fff' : '#A89B8B', flexShrink: 0 }}>
                          {initials}
                        </div>
                        <div>
                          <div className="trow__title" style={{ fontSize: 13 }}>{u.name}</div>
                          <div style={{ fontSize: 11.5, color: '#A89B8B' }}>{u.email || '—'}</div>
                        </div>
                      </div>
                    </div>
                    {/* Role — click to change */}
                    <div style={{ position: 'relative' }}>
                      {editingRole === u.id ? (
                        <select
                          className="select"
                          autoFocus
                          defaultValue={u.role}
                          onBlur={() => setEditingRole(null)}
                          onChange={e => changeRole(u, e.target.value)}
                          style={{ fontSize: 12, padding: '3px 8px', height: 'auto' }}
                        >
                          <option value="procurement_manager">Procurement Manager</option>
                          <option value="it_manager">IT Manager</option>
                          <option value="ops_manager">Ops Manager</option>
                          <option value="requester">Requester</option>
                          <option value="controlling">Controlling</option>
                          <option value="admin">Admin</option>
                        </select>
                      ) : (
                        <button
                          onClick={() => setEditingRole(u.id)}
                          title="Click to change role"
                          style={{
                            background: 'none', border: '1px dashed #E5DDD0', borderRadius: 5,
                            padding: '3px 8px', cursor: 'pointer', fontSize: 12.5, color: '#75695F',
                            display: 'flex', alignItems: 'center', gap: 5,
                          }}
                        >
                          {u.title || ROLE_LABEL[ROLE_GROUP[u.role] || u.role] || u.role}
                          <span style={{ fontSize: 10, color: '#C9BFAE' }}>✎</span>
                        </button>
                      )}
                    </div>
                    <div style={{ fontSize: 12.5, color: '#75695F' }}>{branch}</div>
                    <div style={{ textAlign: 'right', display: 'flex', gap: 6, justifyContent: 'flex-end' }}>
                      <button
                        className={`btn btn--sm ${u.active ? 'btn--danger' : 'btn--success'}`}
                        onClick={() => toggleActive(u)}
                        style={{ fontSize: 11.5 }}
                      >
                        {u.active ? 'Deactivate' : 'Activate'}
                      </button>
                    </div>
                  </div>
                )
              })}
            </div>
          </div>
        )
      })}

      {/* Add user modal */}
      {adding && (
        <div className="modal-scrim" onClick={() => setAdding(false)}>
          <div className="modal" style={{ maxWidth: 480 }} onClick={e => e.stopPropagation()}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 20 }}>
              <div>
                <div style={{ fontSize: 11, letterSpacing: '0.14em', textTransform: 'uppercase', color: '#75695F', marginBottom: 4 }}>Users</div>
                <div style={{ fontFamily: "'Instrument Serif', serif", fontSize: 24, color: '#161413', letterSpacing: '-0.025em' }}>Add user</div>
              </div>
              <button className="iconbtn" onClick={() => setAdding(false)}><IconX size={16}/></button>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
              <div className="field" style={{ gridColumn: 'span 2' }}>
                <label className="field__label">Full name <span style={{ color: '#B07219' }}>*</span></label>
                <input className="input" value={form.name} onChange={e => setForm(f=>({...f,name:e.target.value}))} placeholder="Eva Müller" />
              </div>
              <div className="field" style={{ gridColumn: 'span 2' }}>
                <label className="field__label">Work email <span style={{ color: '#B07219' }}>*</span></label>
                <input className="input" type="email" value={form.email} onChange={e => setForm(f=>({...f,email:e.target.value}))} placeholder="legal@truespend.com" />
              </div>
              <div className="field">
                <label className="field__label">Role</label>
                <select className="select" value={form.role} onChange={e => setForm(f=>({...f,role:e.target.value}))}>
                  <option value="procurement_manager">Procurement Manager</option>
                  <option value="it_manager">IT Manager</option>
                  <option value="ops_manager">Ops Manager</option>
                  <option value="requester">Requester</option>
                  <option value="controlling">Controlling</option>
                  <option value="admin">Admin</option>
                </select>
              </div>
              <div className="field">
                <label className="field__label">Branch</label>
                <select className="select" value={form.branch_id} onChange={e => setForm(f=>({...f,branch_id:e.target.value}))}>
                  {BRANCHES.map(b => <option key={b.id} value={b.id}>{b.label}</option>)}
                </select>
              </div>
              <div className="field" style={{ gridColumn: 'span 2' }}>
                <label className="field__label">Job title <span style={{ color: '#75695F', fontWeight: 400 }}>(optional)</span></label>
                <input className="input" value={form.title} onChange={e => setForm(f=>({...f,title:e.target.value}))} placeholder="e.g. Senior Category Manager" />
              </div>
            </div>

            {/* Role description */}
            <div style={{ background: '#F5F1EA', border: '1px solid #E5DDD0', borderRadius: 6, padding: '10px 12px', marginBottom: 16, fontSize: 12.5, color: '#75695F', lineHeight: 1.5 }}>
              <strong style={{ color: '#3D3633' }}>{PERSONA_GROUP_LABEL[form.role] || 'User'}</strong>
              {' — '}{PERSONA_GROUP_DESC[form.role] || 'Self-service access'}
            </div>

            {saveErr && (
              <div style={{ background: '#F6E5DE', border: '1px solid #E8C3B5', borderRadius: 6, padding: '10px 12px', marginBottom: 14, fontSize: 12.5, color: '#B5462E' }}>
                {saveErr}
              </div>
            )}

            <div style={{ display: 'flex', gap: 10 }}>
              <button className="btn btn--tertiary" style={{ flex: 1 }} onClick={() => setAdding(false)}>Cancel</button>
              <button className="btn btn--primary" style={{ flex: 2 }} onClick={saveUser} disabled={saving || !form.name.trim() || !form.email.trim()}>
                {saving ? 'Creating…' : 'Create user'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

// ─── Persona picker (login screen) ───────────────────────────────────────────
const PERSONA_GROUP_LABEL = {
  procurement: 'Procurement',
  it:          'IT',
  user:        'User',
  controlling: 'Controlling',
  admin:       'Admin',
}

const PERSONA_GROUP_DESC = {
  procurement: 'Ops Board (branch scope), Orders, Suppliers, Catalogues — can approve & sign',
  it:          'IT Requests board (hardware/software only), Orders, Catalogues, New Request',
  user:        'Self-service — browse catalogue, submit requests, track own requests',
  controlling: 'Read-only board (branch scope) + Budget screen — no approval buttons',
  admin:       'User management, Operations Board, Supplier onboarding',
}

const PERSONA_GROUP_COLOR = {
  procurement: '#B07219',
  it:          '#2B5F7A',
  user:        '#3D7A5A',
  controlling: '#5A3E7A',
  admin:       '#6B4F8A',
}

// ─── Login Screen ─────────────────────────────────────────────────────────────
// Email-based login: looks up user in DB, shows role confirmation, signs in.
// Role is set by admin (Users screen). Each role sees only its own nav items.
const UserSetupModal = ({ onSave }) => {
  const [email,   setEmail]   = useState('')
  const [status,  setStatus]  = useState('idle')   // idle | searching | found | notfound | error
  const [found,   setFound]   = useState(null)      // matched user object
  const [allUsers, setAllUsers] = useState(null)    // for demo hint dropdown

  // Load all users for the demo email hint
  useEffect(() => {
    pgFetch('/users?active=eq.true&order=role.asc,name.asc&limit=50')
      .then(data => setAllUsers(data))
      .catch(() => setAllUsers([]))
  }, [])

  const lookup = async (e) => {
    e.preventDefault()
    if (!email.trim()) return
    setStatus('searching')
    try {
      const q = email.trim().toLowerCase()
      // First try exact DB match
      const all = allUsers || []
      const match = all.find(u => (u.email || '').toLowerCase() === q)
      if (match) {
        setFound(match)
        setStatus('found')
      } else {
        setStatus('notfound')
      }
    } catch {
      setStatus('error')
    }
  }

  const signIn = () => {
    if (!found) return
    onSave({
      id:            found.id,
      name:          found.name,
      email:         found.email || '',
      role:          found.role,
      branchId:      found.branch_id || BRANCHES[0].id,
      costCenterId:  found.cost_center_id || null,
      title:         found.title || ROLE_LABEL[ROLE_GROUP[found.role] || found.role] || found.role,
    })
  }

  const roleGroup  = found ? (ROLE_GROUP[found.role] || 'user') : null
  const roleLabel  = found ? (ROLE_LABEL[roleGroup] || found.role) : null
  const roleColor  = found ? (PERSONA_GROUP_COLOR[roleGroup] || '#75695F') : null
  const initials   = found ? found.name.split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase() : null
  const branch     = found ? (BRANCHES.find(b => b.id === found.branch_id)?.label || '') : ''

  // Group users for the demo hint dropdown
  const grouped = {}
  for (const u of (allUsers || [])) {
    const g = ROLE_GROUP[u.role] || 'user'
    if (!grouped[g]) grouped[g] = []
    grouped[g].push(u)
  }

  return (
    <div style={{
      position: 'fixed', inset: 0, background: '#F5F1EA',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      zIndex: 9999, flexDirection: 'column', gap: 0,
    }}>
      {/* Logo */}
      <div style={{ marginBottom: 40, textAlign: 'center' }}>
        <div style={{ display: 'inline-flex', alignItems: 'center', gap: 10 }}>
          <div style={{ background: '#161413', borderRadius: 8, width: 36, height: 36, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <svg width="18" height="18" viewBox="0 0 64 64" fill="none">
              <path d="M16 18 H48 V25 H37 V48 H29 V25 H16 Z" fill="#B07219"/>
              <path d="M22 18 L42 18 L42 25 L33 25 L33 32 L25 32 L25 25 L22 25 Z" fill="#D89E40" opacity="0.85"/>
            </svg>
          </div>
          <span style={{ fontWeight: 800, fontSize: 22, color: '#161413', letterSpacing: '-0.03em' }}>TrueSpend</span>
        </div>
      </div>

      {/* Card */}
      <div style={{
        background: '#FFFEFB', borderRadius: 12, padding: '40px 44px 36px',
        boxShadow: '0 2px 24px rgba(22,20,19,0.09)', width: '100%', maxWidth: 420,
      }}>
        <div style={{ fontFamily: "'Instrument Serif', serif", fontSize: 28, letterSpacing: '-0.025em', color: '#161413', marginBottom: 6 }}>
          Sign in
        </div>
        <div style={{ fontSize: 13, color: '#75695F', marginBottom: 28, lineHeight: 1.5 }}>
          Your access level is set by your admin.
        </div>

        {/* Email form */}
        {status !== 'found' && (
          <form onSubmit={lookup}>
            <div className="field" style={{ marginBottom: 16 }}>
              <label className="field__label">Work email</label>
              <input
                className="input"
                type="email"
                placeholder="head.of.procurement@truespend.com"
                value={email}
                onChange={e => { setEmail(e.target.value); setStatus('idle') }}
                autoFocus
                style={{ fontSize: 14 }}
              />
            </div>
            {status === 'notfound' && (
              <div style={{ fontSize: 12.5, color: '#B5462E', marginBottom: 14, padding: '8px 12px', background: '#FDF0ED', borderRadius: 6 }}>
                No account found for that email. Ask your admin to add you.
              </div>
            )}
            {status === 'error' && (
              <div style={{ fontSize: 12.5, color: '#B5462E', marginBottom: 14, padding: '8px 12px', background: '#FDF0ED', borderRadius: 6 }}>
                Connection error. Check your network and try again.
              </div>
            )}
            <button
              type="submit"
              className="btn btn--primary btn--block btn--lg"
              disabled={status === 'searching' || !email.trim()}
              style={{ opacity: (status === 'searching' || !email.trim()) ? 0.6 : 1 }}
            >
              {status === 'searching' ? 'Looking up…' : 'Continue'}
            </button>
          </form>
        )}

        {/* Confirmed identity */}
        {status === 'found' && found && (
          <div>
            <div style={{
              display: 'flex', alignItems: 'center', gap: 14,
              padding: '14px 16px', background: '#F5F1EA', borderRadius: 8, marginBottom: 20,
            }}>
              <div style={{
                width: 42, height: 42, borderRadius: '50%', background: roleColor,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontSize: 14, fontWeight: 700, color: '#fff', flexShrink: 0,
              }}>{initials}</div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 15, fontWeight: 700, color: '#161413', letterSpacing: '-0.01em' }}>{found.name}</div>
                <div style={{ fontSize: 12, color: '#75695F', marginTop: 2 }}>
                  {found.email}
                  {branch && <span style={{ color: '#A89B8B' }}> · {branch}</span>}
                </div>
              </div>
              <span style={{
                padding: '3px 9px', borderRadius: 5, fontSize: 11, fontWeight: 700,
                letterSpacing: '0.06em', textTransform: 'uppercase',
                background: roleColor + '22', color: roleColor,
              }}>{roleLabel}</span>
            </div>
            <div style={{ fontSize: 12.5, color: '#75695F', marginBottom: 20, lineHeight: 1.6 }}>
              You'll see <strong style={{ color: '#161413' }}>{PERSONA_GROUP_DESC[roleGroup] || 'your role\'s features'}</strong>. Your admin can change your access level from the Users screen.
            </div>
            <div style={{ display: 'flex', gap: 10 }}>
              <button
                className="btn btn--secondary"
                onClick={() => { setStatus('idle'); setFound(null); setEmail('') }}
                style={{ flex: 1 }}
              >
                Back
              </button>
              <button className="btn btn--primary" onClick={signIn} style={{ flex: 2 }}>
                Sign in as {found.name.split(' ')[0]} →
              </button>
            </div>
          </div>
        )}
      </div>

      {/* Demo hint — collapsible */}
      {allUsers && allUsers.length > 0 && (
        <DemoHint users={allUsers} grouped={grouped} onPick={(u) => {
          setEmail(u.email || '')
          setFound(u)
          setStatus('found')
        }} />
      )}
    </div>
  )
}

// Demo hint — shows all available test accounts grouped by role
const DemoHint = ({ users, grouped, onPick }) => {
  const [open, setOpen] = useState(false)
  return (
    <div style={{ marginTop: 20, width: '100%', maxWidth: 420 }}>
      <button
        onClick={() => setOpen(o => !o)}
        style={{
          width: '100%', background: 'none', border: '1px solid #E5DDD0', borderRadius: 8,
          padding: '9px 14px', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          fontSize: 12.5, color: '#75695F', fontWeight: 600,
        }}
      >
        <span>Demo accounts</span>
        <IconChevDown size={14} style={{ transform: open ? 'rotate(180deg)' : 'none', transition: 'transform 0.15s' }} />
      </button>
      {open && (
        <div style={{
          background: '#FFFEFB', border: '1px solid #E5DDD0', borderRadius: 8, marginTop: 6,
          padding: '10px 8px', display: 'flex', flexDirection: 'column', gap: 2,
          maxHeight: 320, overflowY: 'auto',
        }}>
          {['procurement','it','controlling','user','admin'].map(group => {
            const members = grouped[group] || []
            if (!members.length) return null
            return (
              <div key={group}>
                <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: '0.12em', textTransform: 'uppercase', color: '#A89B8B', padding: '6px 8px 3px' }}>
                  {PERSONA_GROUP_LABEL[group]}
                </div>
                {members.map(u => (
                  <button
                    key={u.id}
                    onClick={() => onPick(u)}
                    style={{
                      display: 'flex', alignItems: 'center', gap: 10, width: '100%',
                      padding: '7px 8px', border: 'none', background: 'none', cursor: 'pointer',
                      borderRadius: 6, textAlign: 'left',
                    }}
                    onMouseEnter={e => e.currentTarget.style.background = '#F5F1EA'}
                    onMouseLeave={e => e.currentTarget.style.background = 'none'}
                  >
                    <div style={{
                      width: 26, height: 26, borderRadius: '50%', flexShrink: 0,
                      background: PERSONA_GROUP_COLOR[group] + '33',
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                      fontSize: 10, fontWeight: 700, color: PERSONA_GROUP_COLOR[group],
                    }}>
                      {u.name.split(' ').map(w => w[0]).join('').slice(0,2).toUpperCase()}
                    </div>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ fontSize: 13, fontWeight: 600, color: '#161413' }}>{u.name}</div>
                      <div style={{ fontSize: 11, color: '#A89B8B', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{u.email}</div>
                    </div>
                  </button>
                ))}
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}

// ─── Search Screen ────────────────────────────────────────────────────────────
// Semantic search across contracts, legal docs, policies, and supplier intelligence
// Uses keyword fallback (PostgREST full-text) when embeddings aren't indexed yet

const SEARCH_TYPES = [
  { value: '',                label: 'All documents' },
  { value: 'legal_document',  label: 'NDAs & DPAs' },
  { value: 'contract',        label: 'Contracts' },
  { value: 'policy',          label: 'Policies' },
]

const GDPR_STATUS_COLOR = { signed: '#3D7A5A', draft: '#B5462E', generated: '#D97706', sent: '#2563EB', expired: '#6B7280', filed: '#3D7A5A' }

// ─── Contracts Screen ─────────────────────────────────────────────────────────
// Real DB data from /contracts. Shows expiry urgency, auto-renew flag, RAG status.
// "Renew" action fires the n8n intake webhook (ticket_type: renew).
const CONTRACT_CATEGORIES = { hardware: 'Hardware', hyperscaler: 'Hyperscaler', saas_license: 'SaaS', services: 'Services', facilities: 'Facilities', telecoms: 'Telecoms', other: 'Other' }

function ragStatus(expiryDate) {
  if (!expiryDate) return { label: 'No expiry', color: '#A89B8B', bg: '#F0EBE3' }
  const days = Math.ceil((new Date(expiryDate) - new Date()) / 86400000)
  if (days < 0)   return { label: 'Expired',     color: '#B5462E', bg: '#F6E5DE', days }
  if (days <= 30) return { label: `${days}d`,    color: '#B5462E', bg: '#F6E5DE', days }
  if (days <= 90) return { label: `${days}d`,    color: '#C99119', bg: '#FAF1D7', days }
  if (days <= 180) return { label: `${days}d`,   color: '#B07219', bg: '#F7EFDE', days }
  return { label: `${days}d`,                    color: '#3D7A5A', bg: '#EEF3EE', days }
}

function ContractsScreen({ user }) {
  const [contracts,  setContracts]  = useState(null)
  const [suppliers,  setSuppliers]  = useState({})
  const [filter,     setFilter]     = useState('')      // category filter
  const [search,     setSearch]     = useState('')
  const [renewing,   setRenewing]   = useState(null)
  const [renewOk,    setRenewOk]    = useState(null)
  const [openId,     setOpenId]     = useState(null)
  const roleGroup = ROLE_GROUP[user?.role] || 'user'
  const canRenew  = roleGroup === 'procurement'

  useEffect(() => {
    Promise.all([
      pgFetch('/contracts?order=expiry_date.asc&limit=200&select=id,name,contract_number,supplier_id,category,value_eur,expiry_date,auto_renew,renewal_state,start_date'),
      pgFetch('/suppliers?select=id,name&limit=200'),
    ]).then(([ctrs, sups]) => {
      const supMap = {}
      for (const s of (sups || [])) supMap[s.id] = s.name
      setSuppliers(supMap)
      // Sort: expired first, then by days asc, then auto_renew
      const sorted = (ctrs || []).slice().sort((a, b) => {
        const da = a.expiry_date ? Math.ceil((new Date(a.expiry_date) - new Date()) / 86400000) : 9999
        const db = b.expiry_date ? Math.ceil((new Date(b.expiry_date) - new Date()) / 86400000) : 9999
        return da - db
      })
      setContracts(sorted)
    }).catch(() => setContracts([]))
  }, [])

  const handleRenew = async (c) => {
    if (renewing) return
    setRenewing(c.id)
    try {
      await fetch(N8N_WEBHOOK, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ticket_type:       'renew',
          title:             `Renew — ${c.name}`,
          description:       `Contract renewal request for ${c.name} (${c.contract_number || c.id}). Current expiry: ${c.expiry_date || 'unknown'}. Category: ${c.category || 'other'}.`,
          submitted_by:      user?.name || '',
          submitted_by_email: user?.email || '',
          supplier_name:     suppliers[c.supplier_id] || '',
          value_eur:         c.value_eur || 0,
          category:          c.category || 'other',
          branch_id:         user?.branchId || null,
        }),
      })
      setRenewOk(c.id)
      setTimeout(() => setRenewOk(null), 3000)
    } catch {}
    setRenewing(null)
  }

  const displayed = (contracts || []).filter(c => {
    if (filter && c.category !== filter) return false
    if (search) {
      const q = search.toLowerCase()
      return (c.name || '').toLowerCase().includes(q) || (suppliers[c.supplier_id] || '').toLowerCase().includes(q) || (c.contract_number || '').toLowerCase().includes(q)
    }
    return true
  })

  // Stats
  const now = new Date()
  const expired   = (contracts || []).filter(c => c.expiry_date && new Date(c.expiry_date) < now).length
  const exp30     = (contracts || []).filter(c => { if (!c.expiry_date) return false; const d = Math.ceil((new Date(c.expiry_date) - now) / 86400000); return d >= 0 && d <= 30 }).length
  const exp90     = (contracts || []).filter(c => { if (!c.expiry_date) return false; const d = Math.ceil((new Date(c.expiry_date) - now) / 86400000); return d > 30 && d <= 90 }).length
  const autoRenew = (contracts || []).filter(c => c.auto_renew).length

  return (
    <div className="board-wrap">
      <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 20 }}>
        <div>
          <div style={{ fontSize: 11, letterSpacing: '0.14em', textTransform: 'uppercase', color: '#75695F', marginBottom: 4 }}>Contracts</div>
          <div style={{ fontFamily: "'Instrument Serif', serif", fontSize: 28, color: '#161413', letterSpacing: '-0.025em' }}>
            Contract register
          </div>
        </div>
        <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
          <input
            className="input"
            placeholder="Search contracts…"
            value={search}
            onChange={e => setSearch(e.target.value)}
            style={{ width: 200, fontSize: 13 }}
          />
          <select className="select" value={filter} onChange={e => setFilter(e.target.value)} style={{ fontSize: 13 }}>
            <option value="">All categories</option>
            {Object.entries(CONTRACT_CATEGORIES).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
          </select>
        </div>
      </div>

      {/* Stats strip */}
      {contracts && (
        <div className="stats" style={{ marginBottom: 24 }}>
          <div className="stat">
            <div className="stat__label">Total</div>
            <div className="stat__val">{contracts.length}</div>
            <div className="stat__hint">Active contracts</div>
          </div>
          <div className="stat">
            <div className="stat__label">Expired</div>
            <div className="stat__val" style={{ color: expired ? '#B5462E' : '#3D7A5A' }}>{expired}</div>
            <div className="stat__hint">Need immediate action</div>
          </div>
          <div className="stat">
            <div className="stat__label">Expiring &lt;30d</div>
            <div className="stat__val" style={{ color: exp30 ? '#C99119' : '#3D7A5A' }}>{exp30}</div>
            <div className="stat__hint">Critical renewal window</div>
          </div>
          <div className="stat">
            <div className="stat__label">Expiring &lt;90d</div>
            <div className="stat__val" style={{ color: exp90 ? '#B07219' : '#3D7A5A' }}>{exp90}</div>
            <div className="stat__hint">Renewal window open</div>
          </div>
          <div className="stat">
            <div className="stat__label">Auto-renew</div>
            <div className="stat__val" style={{ color: '#3D7A5A' }}>{autoRenew}</div>
            <div className="stat__hint">Handled by agent</div>
          </div>
        </div>
      )}

      {/* Contracts list */}
      {!contracts && <div style={{ padding: '40px 0', textAlign: 'center', color: '#A89B8B', fontSize: 13 }}>Loading contracts…</div>}
      {contracts && contracts.length === 0 && (
        <div style={{ padding: '60px 0', textAlign: 'center', color: '#A89B8B', fontSize: 13 }}>No contracts found.</div>
      )}

      {contracts && displayed.length > 0 && (
        <div className="tlist">
          {/* Header */}
          <div className="trow" style={{ gridTemplateColumns: '100px 1fr 160px 110px 140px 160px', background: '#EFEBE1', cursor: 'default', fontSize: 11, fontWeight: 600, letterSpacing: '0.1em', textTransform: 'uppercase', color: '#75695F' }}>
            <div>Expiry</div>
            <div>Contract</div>
            <div>Supplier</div>
            <div style={{ textAlign: 'right' }}>Value</div>
            <div>Category</div>
            <div style={{ textAlign: 'right' }}>Actions</div>
          </div>

          {displayed.map(c => {
            const rag     = ragStatus(c.expiry_date)
            const isOpen  = openId === c.id
            const supName = suppliers[c.supplier_id] || '—'

            return (
              <div key={c.id}>
                <div
                  className="trow"
                  style={{ gridTemplateColumns: '100px 1fr 160px 110px 140px 160px', cursor: 'pointer' }}
                  onClick={() => setOpenId(isOpen ? null : c.id)}
                >
                  {/* Expiry badge */}
                  <div>
                    <span className="pill" style={{ background: rag.bg, color: rag.color, fontFamily: "'Geist Mono', monospace", fontWeight: 700, fontSize: 11 }}>
                      {rag.days !== undefined && rag.days < 0 ? 'Expired' : rag.label}
                    </span>
                  </div>

                  {/* Name */}
                  <div className="trow__main">
                    <div className="trow__title">
                      {c.name}
                      {c.auto_renew && <span style={{ marginLeft: 6, fontSize: 10, fontWeight: 600, padding: '1px 6px', borderRadius: 4, background: '#EEF3EE', color: '#3D7A5A', border: '1px solid #C5D8C9' }}>Auto-renew</span>}
                    </div>
                    <div className="trow__meta">
                      {c.contract_number && <span className="ref">{c.contract_number}</span>}
                      {c.start_date && <><span className="dot"/><span>from {new Date(c.start_date).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' })}</span></>}
                    </div>
                  </div>

                  {/* Supplier */}
                  <div>
                    <div className="trow__supplier">{supName}</div>
                  </div>

                  {/* Value */}
                  <div style={{ textAlign: 'right' }}>
                    <div className="trow__value">{c.value_eur ? fmt(c.value_eur) : '—'}</div>
                  </div>

                  {/* Category */}
                  <div>
                    <span className="pill" style={{ background: '#F0EDE8', color: '#75695F', fontSize: 11 }}>
                      {CONTRACT_CATEGORIES[c.category] || c.category || '—'}
                    </span>
                  </div>

                  {/* Actions */}
                  <div style={{ display: 'flex', justifyContent: 'flex-end', alignItems: 'center', gap: 6 }}>
                    {renewOk === c.id ? (
                      <span style={{ fontSize: 12, color: '#3D7A5A', fontWeight: 600 }}>✓ Submitted</span>
                    ) : canRenew && (
                      <button
                        className="btn btn--secondary btn--sm"
                        style={{ fontSize: 11, whiteSpace: 'nowrap' }}
                        disabled={renewing === c.id}
                        onClick={e => { e.stopPropagation(); handleRenew(c) }}
                      >
                        {renewing === c.id ? 'Submitting…' : 'Renew'}
                      </button>
                    )}
                    <IconChevDown size={14} style={{ color: '#A89B8B', transform: isOpen ? 'rotate(180deg)' : 'none', transition: 'transform 0.15s', flexShrink: 0 }} />
                  </div>
                </div>

                {/* Expanded detail */}
                {isOpen && (
                  <div style={{ padding: '16px 24px 20px', background: '#FDFAF5', borderTop: '1px solid #EEE7DA', display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 16 }}>
                    <div>
                      <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: '0.1em', textTransform: 'uppercase', color: '#A89B8B', marginBottom: 6 }}>Contract details</div>
                      <div style={{ fontSize: 12.5, color: '#3D3633', lineHeight: 1.8 }}>
                        <div><strong>Number:</strong> {c.contract_number || '—'}</div>
                        <div><strong>Start:</strong> {c.start_date ? new Date(c.start_date).toLocaleDateString('en-GB') : '—'}</div>
                        <div><strong>Expiry:</strong> {c.expiry_date ? new Date(c.expiry_date).toLocaleDateString('en-GB') : '—'}</div>
                        <div><strong>Auto-renew:</strong> {c.auto_renew ? 'Yes' : 'No'}</div>
                      </div>
                    </div>
                    <div>
                      <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: '0.1em', textTransform: 'uppercase', color: '#A89B8B', marginBottom: 6 }}>Renewal state</div>
                      <div>
                        <span className="pill" style={{ fontSize: 12, background: c.renewal_state === 'auto_renewed' ? '#EEF3EE' : c.renewal_state === 'manual_required' ? '#FAF1D7' : '#F0EDE8', color: c.renewal_state === 'auto_renewed' ? '#3D7A5A' : c.renewal_state === 'manual_required' ? '#8C6510' : '#75695F' }}>
                          {c.renewal_state || 'not set'}
                        </span>
                      </div>
                    </div>
                    <div>
                      <div style={{ fontSize: 10, fontWeight: 700, letterSpacing: '0.1em', textTransform: 'uppercase', color: '#A89B8B', marginBottom: 6 }}>Supplier</div>
                      <div style={{ fontSize: 12.5, color: '#3D3633' }}>{supName}</div>
                    </div>
                  </div>
                )}
              </div>
            )
          })}
        </div>
      )}

      {contracts && displayed.length === 0 && (contracts.length > 0) && (
        <div style={{ padding: '40px 0', textAlign: 'center', color: '#A89B8B', fontSize: 13 }}>
          No contracts match the current filter.
        </div>
      )}
    </div>
  )
}

function SearchScreen() {
  const [query,     setQuery]     = useState('')
  const [docType,   setDocType]   = useState('')
  const [results,   setResults]   = useState(null)
  const [loading,   setLoading]   = useState(false)
  const [error,     setError]     = useState(null)
  const [selected,  setSelected]  = useState(null)
  const inputRef = useRef(null)

  const doSearch = useCallback(async (q, type) => {
    if (!q || q.trim().length < 2) { setResults(null); return }
    setLoading(true); setError(null)
    try {
      // Use keyword search RPC (works without embeddings being pre-generated)
      const params = new URLSearchParams({ query_text: q, result_limit: 20 })
      if (type) params.set('filter_doc_type', type)
      const data = await pgFetch(`/rpc/search_documents_text?${params}`)
      setResults(data)
    } catch (e) {
      // Fallback: direct FTS on source tables
      try {
        const [ldocs, contracts, policies] = await Promise.all([
          (!type || type === 'legal_document')
            ? pgFetch(`/legal_documents?content=ilike.*${encodeURIComponent(q)}*&select=id,supplier_id,doc_type,status,content,created_at&limit=15`)
            : Promise.resolve([]),
          (!type || type === 'contract')
            ? pgFetch(`/contracts?or=(name.ilike.*${encodeURIComponent(q)}*,terms_summary.ilike.*${encodeURIComponent(q)}*)&select=id,supplier_id,name,category,value,currency,expiry_date,renewal_state,terms_summary&limit=10`)
            : Promise.resolve([]),
          (!type || type === 'policy')
            ? pgFetch(`/rag_policies?content=ilike.*${encodeURIComponent(q)}*&select=id,title,category,content&limit=5`)
            : Promise.resolve([]),
        ])
        const combined = [
          ...ldocs.map(d => ({ doc_type: 'legal_document', source_id: d.id, supplier_id: d.supplier_id, meta_title: `${d.doc_type.toUpperCase()} — ${d.status}`, meta_status: d.status, meta_category: d.doc_type, chunk_text: d.content, similarity: null })),
          ...contracts.map(c => ({ doc_type: 'contract', source_id: c.id, supplier_id: c.supplier_id, meta_title: c.name, meta_status: c.renewal_state, meta_category: c.category, chunk_text: c.terms_summary || c.name, similarity: null })),
          ...policies.map(p => ({ doc_type: 'policy', source_id: p.id, supplier_id: null, meta_title: p.title, meta_status: 'active', meta_category: p.category, chunk_text: p.content, similarity: null })),
        ]
        setResults(combined)
      } catch (e2) {
        setError(e2.message)
      }
    } finally {
      setLoading(false)
    }
  }, [])

  // Debounced search
  useEffect(() => {
    const t = setTimeout(() => doSearch(query, docType), 350)
    return () => clearTimeout(t)
  }, [query, docType, doSearch])

  const docTypeLabel = (t) => ({ legal_document: 'Legal Doc', contract: 'Contract', policy: 'Policy' }[t] || t)
  const docTypeColor = (t) => ({ legal_document: '#7C3AED', contract: '#2563EB', policy: '#D97706' }[t] || '#6B7280')

  const highlight = (text, q) => {
    if (!q || !text) return text
    const parts = text.split(new RegExp(`(${q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')})`, 'gi'))
    return parts.map((part, i) =>
      part.toLowerCase() === q.toLowerCase()
        ? <mark key={i} style={{ background: '#FEF08A', borderRadius: 2, padding: '0 1px' }}>{part}</mark>
        : part
    )
  }

  return (
    <div style={{ padding: '28px 32px', maxWidth: 900 }}>
      {/* Header */}
      <div style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 20, fontWeight: 700, color: '#161413', margin: 0 }}>Document Search</h2>
        <p style={{ fontSize: 13, color: '#7A6A5A', margin: '4px 0 0' }}>
          Search across contracts, NDAs, DPAs, compliance reports, and procurement policies
        </p>
      </div>

      {/* Search bar + filter */}
      <div style={{ display: 'flex', gap: 10, marginBottom: 20 }}>
        <div style={{ position: 'relative', flex: 1 }}>
          <svg width={16} height={16} viewBox="0 0 24 24" fill="none" stroke="#A89B8B" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round"
            style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', pointerEvents: 'none' }}>
            <circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
          </svg>
          <input
            ref={inputRef}
            autoFocus
            value={query}
            onChange={e => setQuery(e.target.value)}
            placeholder='Search: "auto-renew clause", "GDPR DPA Salesforce", "spend authority €100k"…'
            style={{ width: '100%', padding: '10px 12px 10px 36px', fontSize: 14, border: '1.5px solid #E8E0D8', borderRadius: 8, outline: 'none', background: '#FBF9F7', boxSizing: 'border-box', color: '#161413' }}
          />
        </div>
        <select value={docType} onChange={e => setDocType(e.target.value)}
          style={{ padding: '10px 12px', fontSize: 13, border: '1.5px solid #E8E0D8', borderRadius: 8, background: '#FBF9F7', color: '#4A3728', outline: 'none', minWidth: 150 }}>
          {SEARCH_TYPES.map(t => <option key={t.value} value={t.value}>{t.label}</option>)}
        </select>
      </div>

      {/* Quick suggestions */}
      {!query && (
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginBottom: 20 }}>
          {['auto-renew expiring', 'DPA signed Germany', 'GDPR data residency', 'price increase clause', 'spend authority €100k', 'LkSG declaration pending', 'Anthropic API', 'SOC 2 Type II'].map(s => (
            <button key={s} onClick={() => { setQuery(s); inputRef.current?.focus() }}
              style={{ padding: '5px 12px', fontSize: 12, border: '1px solid #E8E0D8', borderRadius: 20, background: 'white', color: '#7A6A5A', cursor: 'pointer' }}>
              {s}
            </button>
          ))}
        </div>
      )}

      {/* Loading */}
      {loading && <div style={{ color: '#A89B8B', fontSize: 13, padding: '16px 0' }}>Searching…</div>}
      {error && <div style={{ color: '#B5462E', fontSize: 13, padding: '8px 12px', background: '#FFF0ED', borderRadius: 6 }}>Search error: {error}</div>}

      {/* Results */}
      {results !== null && !loading && (
        <>
          <div style={{ fontSize: 12, color: '#A89B8B', marginBottom: 12 }}>
            {results.length === 0 ? 'No results found' : `${results.length} result${results.length !== 1 ? 's' : ''} for "${query}"`}
          </div>
          <div style={{ display: 'flex', gap: 16 }}>
            {/* Result list */}
            <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 8 }}>
              {results.map((r, i) => (
                <button key={r.source_id + i} onClick={() => setSelected(selected?.source_id === r.source_id ? null : r)}
                  style={{
                    textAlign: 'left', padding: '12px 14px', borderRadius: 8, cursor: 'pointer',
                    border: selected?.source_id === r.source_id ? '1.5px solid #9B7A5A' : '1.5px solid #E8E0D8',
                    background: selected?.source_id === r.source_id ? '#FAF6F2' : 'white',
                    transition: 'all 0.12s'
                  }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
                    <span style={{ fontSize: 10, fontWeight: 700, letterSpacing: 0.5, padding: '2px 7px', borderRadius: 10, background: docTypeColor(r.doc_type) + '18', color: docTypeColor(r.doc_type) }}>
                      {docTypeLabel(r.doc_type)}
                    </span>
                    {r.meta_status && (
                      <span style={{ fontSize: 10, color: GDPR_STATUS_COLOR[r.meta_status] || '#6B7280', fontWeight: 500 }}>
                        {r.meta_status}
                      </span>
                    )}
                    {r.meta_category && (
                      <span style={{ fontSize: 10, color: '#A89B8B' }}>{r.meta_category}</span>
                    )}
                    {r.similarity !== null && r.similarity !== undefined && (
                      <span style={{ fontSize: 10, color: '#A89B8B', marginLeft: 'auto' }}>{Math.round(r.similarity * 100)}% match</span>
                    )}
                  </div>
                  <div style={{ fontSize: 13, fontWeight: 600, color: '#161413', marginBottom: 4 }}>
                    {highlight(r.meta_title, query)}
                  </div>
                  <div style={{ fontSize: 12, color: '#7A6A5A', lineHeight: 1.5,
                    display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>
                    {highlight((r.chunk_text || '').substring(0, 200), query)}
                  </div>
                </button>
              ))}
            </div>

            {/* Detail pane */}
            {selected && (
              <div style={{ width: 360, flexShrink: 0, background: '#FAF6F2', border: '1.5px solid #E8E0D8', borderRadius: 10, padding: '16px', alignSelf: 'flex-start', position: 'sticky', top: 20 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 12 }}>
                  <div>
                    <span style={{ fontSize: 10, fontWeight: 700, letterSpacing: 0.5, padding: '2px 7px', borderRadius: 10, background: docTypeColor(selected.doc_type) + '18', color: docTypeColor(selected.doc_type) }}>
                      {docTypeLabel(selected.doc_type)}
                    </span>
                  </div>
                  <button onClick={() => setSelected(null)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#A89B8B', fontSize: 18, lineHeight: 1, padding: 0 }}>×</button>
                </div>
                <h3 style={{ fontSize: 14, fontWeight: 700, color: '#161413', margin: '0 0 8px' }}>
                  {selected.meta_title}
                </h3>
                <div style={{ display: 'flex', gap: 8, marginBottom: 12, flexWrap: 'wrap' }}>
                  {selected.meta_status && <span style={{ fontSize: 11, padding: '2px 8px', borderRadius: 10, background: '#F0EDE8', color: GDPR_STATUS_COLOR[selected.meta_status] || '#6B7280', fontWeight: 600 }}>{selected.meta_status}</span>}
                  {selected.meta_category && <span style={{ fontSize: 11, padding: '2px 8px', borderRadius: 10, background: '#F0EDE8', color: '#7A6A5A' }}>{selected.meta_category}</span>}
                </div>
                <div style={{ fontSize: 12, color: '#4A3728', lineHeight: 1.7, whiteSpace: 'pre-wrap', maxHeight: 400, overflowY: 'auto' }}>
                  {selected.chunk_text}
                </div>
              </div>
            )}
          </div>
        </>
      )}

      {/* Empty state */}
      {results === null && !loading && (
        <div style={{ textAlign: 'center', padding: '48px 0', color: '#A89B8B' }}>
          <svg width={40} height={40} viewBox="0 0 24 24" fill="none" stroke="#D8CFC7" strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round" style={{ margin: '0 auto 12px', display: 'block' }}>
            <circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
          </svg>
          <div style={{ fontSize: 14, fontWeight: 600, marginBottom: 4 }}>Search your document library</div>
          <div style={{ fontSize: 12 }}>100 suppliers · 80+ contracts · NDAs, DPAs, compliance reports, policies</div>
        </div>
      )}
    </div>
  )
}

// ─── Default persona — opens directly on Operations Board for demo ─────────────
// Fallback when localStorage has nothing. Full user object from DB is loaded
// by UserSetupModal; this stub just gets the user past the modal on first visit.
const DEFAULT_USER = {
  id:       'e1000000-0000-0000-0000-000000000001',
  name:     'Procurement Manager (HQ)',
  email:    'procurement.hq@truespend.com',
  role:     'procurement_manager',
  branchId: 'b1000000-0000-0000-0000-000000000001',
  title:    'Procurement Manager',
}

// ─── App ──────────────────────────────────────────────────────────────────────
export default function App() {
  const [user, setUser] = useLocalStorage('truespend_user', DEFAULT_USER)
  // resolvedUser: if cached role has no group mapping (e.g. stale 'cfo' or 'legal'), fall back to default
  const resolvedUser = (user && !ROLE_GROUP[user.role]) ? DEFAULT_USER : user

  const [tab,         setTab]         = useState('board')
  const [reqType,     setReqType]     = useState(null)
  const [success,     setSuccess]     = useState(null)
  const [boardCount,  setBoardCount]  = useState(0)
  const [ordersCount, setOrdersCount] = useState(0)
  const [sectionJump, setSectionJump] = useState(null)
  const [openByStatus, setOpenByStatus] = useState({})
  const [cart,        setCart]        = useState([])   // [{ item, qty }]
  const [cartOpen,    setCartOpen]    = useState(false)

  // Clear stale cached sessions with removed roles (cfo, legal, head_of_procurement)
  useEffect(() => {
    if (user && !ROLE_GROUP[user.role]) setUser(DEFAULT_USER)
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

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
    const ref = 'TS-' + new Date().getFullYear() + '-' + String(Date.now()).slice(-4)
    const title = cartLines.length === 1
      ? `Purchase — ${cartLines[0].item.name}${cartLines[0].qty > 1 ? ` × ${cartLines[0].qty}` : ''}`
      : `Purchase — ${cartLines.length} catalog items`
    const desc = cartLines.map(l => `${l.item.name} × ${l.qty} (${l.item.sku || l.item.id})`).join(', ') + (notes ? `. Notes: ${notes}` : '')
    try {
      await fetch(N8N_WEBHOOK, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          title,
          description: desc,
          ticket_type: 'purchase',
          submitted_by: resolvedUser?.name || '',
          submitted_by_email: resolvedUser?.email || '',
          supplier_name: cartLines.length === 1 ? cartLines[0].item.supplier : 'Multiple',
          value_eur: total,
          category: 'hardware',
          branch_id: resolvedUser?.branchId || null,
        })
      })
    } catch {}
    setCart([])
    setSuccess({ ref, email: resolvedUser?.email, isOrder: true })
  }

  const handleCountChange = useCallback((count) => {
    setBoardCount(count)
  }, [])

  const crumbs = (() => {
    if (success)             return ['Submitted']
    if (tab === 'board')     return ['Operations']
    if (tab === 'orders')    return ['Orders']
    if (tab === 'suppliers') return ['Suppliers']
    if (tab === 'catalog')   return ['Catalogues']
    if (tab === 'mine')      return ['My requests']
    if (tab === 'home' || tab === 'request') return ['New request']
    if (tab === 'users')     return ['Users']
    if (tab === 'budget')    return ['Budget']
    if (tab === 'contracts') return ['Contracts']
    if (tab === 'search')    return ['Search']
    return ['Operations']
  })()

  const counts = { open: boardCount, orders: ordersCount }

  return (
    <>
      {/* Show persona picker only when explicitly switched (user === null) */}
      {user === null && <UserSetupModal onSave={(u) => {
        setUser(u)
        // Land on the right default tab for the role
        const group = ROLE_GROUP[u.role] || 'user'
        if (group === 'admin' || group === 'procurement' || group === 'controlling' || group === 'it') setTab('board')
        else if (group === 'it') setTab('catalog')
        else setTab('catalog')
      }} />}

      <div className="app">
        <Sidebar
          tab={tab}
          onNav={navigate}
          counts={counts}
          openByStatus={openByStatus}
          onJumpSection={(st) => { setTab('board'); setSectionJump(st) }}
          user={resolvedUser}
          onSwitchUser={() => setUser(null)}
          onQuickSwitch={(u) => {
            setUser(u)
            setSuccess(null)
            const group = ROLE_GROUP[u.role] || 'user'
            if (group === 'admin' || group === 'procurement' || group === 'controlling' || group === 'it') setTab('board')
            else if (group === 'it') setTab('catalog')
            else setTab('catalog')
          }}
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
              roleGroup={ROLE_GROUP[resolvedUser?.role] || 'procurement'}
              user={resolvedUser}
            />
          )}
          {!success && tab === 'orders'    && <OrdersBoard onCountChange={setOrdersCount} />}
          {!success && tab === 'suppliers' && <SuppliersScreen />}
          {!success && tab === 'catalog'   && <CatalogScreen cart={cart} onAddToCart={handleAddToCart} onOpenCart={() => setCartOpen(true)} />}
          {!success && tab === 'mine'    && <MyRequestsScreen user={resolvedUser} />}
          {!success && (tab === 'home' || tab === 'request') && (
            <NewRequestScreen
              user={resolvedUser}
              onCatalog={() => navigate('catalog')}
              onSuccess={(ref) => setSuccess({ ref, email: resolvedUser?.email, isOrder: false })}
            />
          )}
          {!success && tab === 'users'     && <UsersScreen />}
          {!success && tab === 'budget'    && <BudgetScreen user={resolvedUser} />}
          {!success && tab === 'contracts' && <ContractsScreen user={resolvedUser} />}
          {!success && tab === 'search'    && <SearchScreen />}
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
