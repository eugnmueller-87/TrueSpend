/* Home / Catalog / My Orders / Request form / Success — desktop layouts. */

// ─── HOME ────────────────────────────────────────────────────────────
const QUICK_TILES = [
  { id: 'purchase', label: 'Ad-hoc purchase',    sub: 'New supplier or one-off spend',       Icon: IconBag },
  { id: 'renew',    label: 'Renew a contract',   sub: 'Extend or renegotiate an agreement',  Icon: IconRefresh },
  { id: 'onboard',  label: 'Onboard a supplier', sub: 'Bring a new vendor into the system',  Icon: IconBuilding },
  { id: 'other',    label: 'Something else',     sub: 'Any other procurement request',       Icon: IconZap },
];

const Home = ({ onCatalog, onRequestType }) => (
  <div className="content step-in" style={{ maxWidth: 980 }}>
    <div className="pagehead">
      <div>
        <div className="pagehead__eyebrow">Thursday · 28 May 2026</div>
        <h1 className="greeting__hello">Hi, <em>Eva.</em></h1>
        <div className="greeting__sub">What do you need to get done?</div>
      </div>
    </div>

    <div style={{
      background: 'var(--ts-ink-night)', borderRadius: 10, padding: '28px 32px',
      display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 24,
      marginBottom: 32,
    }}>
      <div>
        <div style={{ fontSize: 10.5, letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--ts-brand-gold)', marginBottom: 10, fontWeight: 500 }}>
          Catalog
        </div>
        <h2 style={{
          fontFamily: 'var(--ts-font-display)', fontSize: 32, letterSpacing: '-0.025em',
          color: 'var(--ts-paper)', margin: 0, lineHeight: 1.1, maxWidth: 480,
        }}>
          Standard items. <em style={{ color: 'var(--ts-brand-gold)', fontStyle: 'normal' }}>Instant approval.</em>
        </h2>
        <div style={{ fontSize: 13, color: 'rgba(247,244,237,0.6)', marginTop: 10 }}>
          Contract on file. Budget check only. No waiting.
        </div>
      </div>
      <button className="btn btn--primary btn--lg" onClick={onCatalog}>
        Browse catalog <IconChev size={14}/>
      </button>
    </div>

    <div style={{ fontSize: 11, fontWeight: 500, letterSpacing: '0.14em', textTransform: 'uppercase', color: 'var(--ts-ink-mute)', marginBottom: 14 }}>
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
);

// ─── CATALOG ─────────────────────────────────────────────────────────
const CATALOG = [
  {
    category: 'Hardware', Icon: IconLaptop,
    items: [
      { id: 'mac-pro-14', name: 'MacBook Pro 14"',     supplier: 'Apple',   price: 2199, sku: 'APPMBP14M3PRO', desc: 'M3 Pro · 18 GB · 512 GB. Standard dev config.' },
      { id: 'mac-pro-16', name: 'MacBook Pro 16"',     supplier: 'Apple',   price: 2999, sku: 'APPMBP16M3MAX', desc: 'M3 Max · 36 GB · 1 TB. Power user config.' },
      { id: 'dell-u27',   name: 'Dell UltraSharp 27"', supplier: 'Dell',    price: 549,  sku: 'DELLU2723QE',   desc: '4K USB-C monitor, 90 W PD. Standard desk monitor.' },
      { id: 'dock-uc',    name: 'CalDigit TS4 Dock',   supplier: 'CalDigit',price: 299,  sku: 'CDTS4',         desc: 'Thunderbolt 4, 18 ports. Standard docking station.' },
      { id: 'iphone-15',  name: 'iPhone 15 Pro',       supplier: 'Apple',   price: 1199, sku: 'APPIPH15P256',  desc: '256 GB. Standard corporate mobile.' },
    ],
  },
  {
    category: 'Software', Icon: IconApp,
    items: [
      { id: 'ms365-e3',   name: 'Microsoft 365 E3',   supplier: 'Microsoft', price: 36, sku: 'MS365E3',     desc: 'Per user / month. Teams, Outlook, Office, SharePoint.', per: '/mo' },
      { id: 'github-ent', name: 'GitHub Enterprise',  supplier: 'GitHub',    price: 21, sku: 'GHENT',       desc: 'Per user / month. Advanced Security + GHAS.',           per: '/mo' },
      { id: 'figma-org',  name: 'Figma Organization', supplier: 'Figma',     price: 45, sku: 'FIGMAORG',    desc: 'Per editor / month. Unlimited projects.',               per: '/mo' },
      { id: 'slack-pro',  name: 'Slack Pro',          supplier: 'Salesforce',price: 8,  sku: 'SLKPRO',      desc: 'Per user / month. Standard workspace.',                 per: '/mo' },
    ],
  },
  {
    category: 'Cloud', Icon: IconCloud,
    items: [
      { id: 'aws-ri', name: 'AWS Reserved Instance', supplier: 'Amazon Web Services', price: 0, sku: 'AWS-RI',  desc: 'Variable — submit for budget allocation. Agent reviews utilization first.', variable: true },
      { id: 'gcp-cu', name: 'GCP Committed Use',     supplier: 'Google Cloud',        price: 0, sku: 'GCP-CUD', desc: 'Variable — commit discount contract. Agent checks prior spend.',           variable: true },
    ],
  },
  {
    category: 'Services', Icon: IconWrench,
    items: [
      { id: 'soc2', name: 'SOC 2 Type II audit', supplier: 'Deloitte',  price: 35000, sku: 'SOC2T2', desc: 'Annual audit. Fixed price per framework agreement.' },
      { id: 'pen',  name: 'Penetration test',    supplier: 'NCC Group', price: 18000, sku: 'PENTESTANN', desc: 'Annual web + infra pentest. Standard scope.' },
    ],
  },
];

const Catalog = ({ onOrder }) => {
  const [activeCat, setActiveCat] = React.useState(CATALOG[0].category);
  const cat = CATALOG.find(c => c.category === activeCat);
  return (
    <div className="content step-in" style={{ maxWidth: 1180 }}>
      <div className="pagehead">
        <div>
          <div className="pagehead__eyebrow">Catalog</div>
          <h1 className="pagehead__title">Pre-negotiated.</h1>
          <div className="pagehead__sub">Contract on file. Budget check only. Order completes the same day.</div>
        </div>
      </div>

      <div className="tabs">
        {CATALOG.map(c => (
          <button
            key={c.category}
            className={'tab' + (activeCat === c.category ? ' tab--active' : '')}
            onClick={() => setActiveCat(c.category)}
          >
            {c.category}
          </button>
        ))}
      </div>

      <div className="cat-grid">
        {cat.items.map(item => (
          <div key={item.id} className="cat-item">
            <div className="cat-item__name">{item.name}</div>
            <div className="cat-item__desc">{item.desc}</div>
            <div className="cat-item__meta">
              <span>{item.supplier}</span>
              <span style={{ width: 3, height: 3, borderRadius: '50%', background: 'var(--ts-line-strong)' }} />
              <span className="ref" style={{ color: 'var(--ts-ink-faint)' }}>{item.sku}</span>
            </div>
            <div className="cat-item__foot">
              <span className="cat-item__price">
                {item.variable ? 'Variable' : formatEuro(item.price)}
                {item.per && !item.variable && <span className="cat-item__price-mo">{item.per}</span>}
              </span>
              <button className="btn btn--secondary btn--sm" onClick={() => onOrder(item)}>Order</button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

// ─── ORDER MODAL ─────────────────────────────────────────────────────
const OrderModal = ({ item, onClose, onPlace }) => {
  const [qty, setQty] = React.useState(1);
  if (!item) return null;
  const total = (item.variable ? 0 : item.price) * qty;
  return (
    <div className="modal-scrim" onClick={onClose}>
      <div className="modal" onClick={e => e.stopPropagation()}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 22 }}>
          <div>
            <div style={{ fontSize: 11, letterSpacing: '0.14em', textTransform: 'uppercase', color: 'var(--ts-ink-mute)', marginBottom: 6 }}>
              Order
            </div>
            <div style={{ fontFamily: 'var(--ts-font-display)', fontSize: 26, color: 'var(--ts-ink)', letterSpacing: '-0.025em', lineHeight: 1.1 }}>
              {item.name}
            </div>
            <div style={{ fontSize: 12.5, color: 'var(--ts-ink-mute)', marginTop: 4 }}>{item.supplier}</div>
          </div>
          <button onClick={onClose} className="iconbtn"><IconX size={16} /></button>
        </div>

        <div className="field">
          <label className="field__label">Quantity</label>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <button className="btn btn--secondary btn--sm" onClick={() => setQty(Math.max(1, qty - 1))} style={{ width: 36, height: 36, padding: 0 }}>
              <IconMinus size={14} />
            </button>
            <span style={{ minWidth: 32, textAlign: 'center', fontSize: 17, fontWeight: 600, color: 'var(--ts-ink)', fontVariantNumeric: 'tabular-nums' }}>{qty}</span>
            <button className="btn btn--secondary btn--sm" onClick={() => setQty(qty + 1)} style={{ width: 36, height: 36, padding: 0 }}>
              <IconPlus size={14} />
            </button>
            {!item.variable && (
              <span className="money" style={{ marginLeft: 'auto', fontSize: 18 }}>{formatEuro(total)}</span>
            )}
          </div>
        </div>

        <div className="field">
          <label className="field__label">Notes <span style={{ color: 'var(--ts-ink-mute)', fontWeight: 400 }}>(optional)</span></label>
          <input className="input" placeholder="Asset tag, requirements, etc." />
        </div>

        <div style={{
          background: 'var(--ts-brand-gold-wash)',
          border: '1px solid var(--ts-brand-gold-soft)',
          borderRadius: 4, padding: '10px 12px',
          fontSize: 12.5, color: 'var(--ts-brand-gold-deep)',
          marginBottom: 18,
        }}>
          Fast-path order. Budget check only — auto-approved if budget available.
        </div>

        <button className="btn btn--primary btn--block btn--lg" onClick={() => onPlace(item, qty, total)}>
          Place order — {formatEuro(total || item.price)}
        </button>
      </div>
    </div>
  );
};

// ─── MY ORDERS ───────────────────────────────────────────────────────
const MY_ORDERS = [
  { id: 1, title: 'MacBook Pro 14" × 1',              supplier: 'Apple',    value: 2199,  ref: 'TS-2026-0492', status: 'auto_executed',      age: '2h ago',  po: 'PO/DACH/00219' },
  { id: 2, title: 'Figma Organization × 6',           supplier: 'Figma',    value: 270,   ref: 'TS-2026-0488', status: 'auto_executed',      age: '8h ago',  po: 'PO/DACH/00217' },
  { id: 3, title: 'Renew — CalDigit TS4 dock fleet',  supplier: 'CalDigit', value: 11960, ref: 'TS-2026-0481', status: 'pending_review',     age: '1d ago' },
  { id: 4, title: 'SOC 2 Type II audit × 1',          supplier: 'Deloitte', value: 35000, ref: 'TS-2026-0476', status: 'signature_required', age: '2d ago' },
  { id: 5, title: 'GitHub Enterprise × 18',           supplier: 'GitHub',   value: 378,   ref: 'TS-2026-0461', status: 'auto_executed',      age: '4d ago',  po: 'PO/DACH/00204' },
  { id: 6, title: 'Onboard — NCC Group',              supplier: 'NCC Group',value: 0,     ref: 'TS-2026-0455', status: 'approved',           age: '5d ago' },
];

const MyOrders = () => (
  <div className="content step-in" style={{ maxWidth: 1180 }}>
    <div className="pagehead">
      <div>
        <div className="pagehead__eyebrow">My requests</div>
        <h1 className="pagehead__title">{MY_ORDERS.length} total.</h1>
        <div className="pagehead__sub">Everything you've submitted, with where the agent took it.</div>
      </div>
      <div className="pagehead__actions">
        <button className="btn btn--tertiary"><IconRotateCw size={14}/> Refresh</button>
      </div>
    </div>

    <div className="tlist" style={{ marginTop: 0 }}>
      <div className="trow" style={{
        background: 'var(--ts-paper-deep)', borderBottom: '1px solid var(--ts-line)',
        padding: '10px 22px', cursor: 'default',
      }}>
        <div className="eyebrow">Status</div>
        <div className="eyebrow">Request</div>
        <div className="eyebrow">Supplier</div>
        <div className="eyebrow" style={{ textAlign: 'right' }}>Value</div>
        <div className="eyebrow" style={{ textAlign: 'right' }}>PO / Action</div>
      </div>
      {MY_ORDERS.map(o => (
        <div key={o.id} className="trow" style={{ cursor: 'default' }}>
          <div><StatusPill status={o.status} /></div>
          <div className="trow__main">
            <div className="trow__title">{o.title}</div>
            <div className="trow__meta">
              <span className="ref">{o.ref}</span>
              <span className="dot" />
              <span>{o.age}</span>
            </div>
          </div>
          <div>
            <div className="trow__supplier">{o.supplier}</div>
          </div>
          <div>
            <div className="trow__value">{o.value ? formatEuro(o.value) : '—'}</div>
          </div>
          <div style={{ textAlign: 'right' }}>
            {o.po ? (
              <span className="ref" style={{ fontFamily: 'var(--ts-font-mono)', fontSize: 12, color: 'var(--ts-brand-gold-deep)' }}>{o.po}</span>
            ) : (
              <span style={{ fontSize: 12, color: 'var(--ts-ink-mute)' }}>—</span>
            )}
          </div>
        </div>
      ))}
    </div>
  </div>
);

// ─── REQUEST FORM ────────────────────────────────────────────────────
const FORM_CONFIG = {
  purchase: { title: 'Purchase request',    hint: 'New supplier or one-off spend.' },
  renew:    { title: 'Contract renewal',    hint: 'Extend or renegotiate an agreement.' },
  onboard:  { title: 'Supplier onboarding', hint: 'Bring a new vendor into the system.' },
  other:    { title: 'Other request',       hint: 'Anything else.' },
};

const RequestForm = ({ type, onBack, onSubmit }) => {
  const cfg = FORM_CONFIG[type] || FORM_CONFIG.other;
  const [supplier, setSupplier] = React.useState(type === 'purchase' ? 'Anthropic' : '');
  const [amount,   setAmount]   = React.useState(type === 'purchase' ? '4800' : '');
  const [desc,     setDesc]     = React.useState(type === 'purchase' ? 'Claude Sonnet API — Q3 commit, 6 dev seats' : '');

  return (
    <div className="content step-in" style={{ maxWidth: 680 }}>
      <button onClick={onBack} className="btn btn--tertiary btn--sm" style={{ marginBottom: 14, padding: '4px 8px' }}>
        <IconArrowLeft size={14} /> Back
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
            <label className="field__label">Supplier <span className="req">*</span></label>
            <input className="input" value={supplier} onChange={e => setSupplier(e.target.value)} placeholder="Supplier or vendor name" />
          </div>
          <div className="field">
            <label className="field__label">Amount <span className="req">*</span></label>
            <div style={{ position: 'relative' }}>
              <span style={{ position: 'absolute', left: 13, top: '50%', transform: 'translateY(-50%)', color: 'var(--ts-ink-mute)', fontSize: 14 }}>€</span>
              <input className="input" style={{ paddingLeft: 28 }} value={amount} onChange={e => setAmount(e.target.value)} inputMode="decimal" />
            </div>
          </div>
          <div className="field">
            <label className="field__label">What's it for? <span className="req">*</span></label>
            <input className="input" value={desc} onChange={e => setDesc(e.target.value)} />
          </div>
          <div className="field">
            <label className="field__label">Business justification</label>
            <textarea className="textarea" rows={3} placeholder="Why is this needed? What does it replace or enable?"></textarea>
          </div>
        </>}

        {type === 'renew' && <>
          <div className="field"><label className="field__label">Supplier <span className="req">*</span></label><input className="input" placeholder="Acme Corp" /></div>
          <div className="field"><label className="field__label">Contract value <span className="req">*</span></label>
            <div style={{ position: 'relative' }}>
              <span style={{ position: 'absolute', left: 13, top: '50%', transform: 'translateY(-50%)', color: 'var(--ts-ink-mute)', fontSize: 14 }}>€</span>
              <input className="input" style={{ paddingLeft: 28 }} placeholder="0" />
            </div>
          </div>
          <div className="field"><label className="field__label">Notes</label><textarea className="textarea" rows={3} placeholder="Expiry, key terms, requested changes…"></textarea></div>
        </>}

        {type === 'onboard' && <>
          <div className="field"><label className="field__label">Company name <span className="req">*</span></label><input className="input" placeholder="New Vendor Ltd" /></div>
          <div className="field"><label className="field__label">Country <span className="req">*</span></label><input className="input" placeholder="e.g. Germany" /></div>
          <div className="field"><label className="field__label">Category <span className="req">*</span></label>
            <select className="select" defaultValue=""><option value="" disabled>Select category</option><option>Hardware</option><option>Cloud</option><option>SaaS</option><option>Services</option></select>
          </div>
          <div className="field"><label className="field__label">Justification <span className="req">*</span></label><textarea className="textarea" rows={3} placeholder="Why do we need this vendor?"></textarea></div>
        </>}

        {type === 'other' && <>
          <div className="field"><label className="field__label">Title <span className="req">*</span></label><input className="input" placeholder="Short summary" /></div>
          <div className="field"><label className="field__label">Description <span className="req">*</span></label><textarea className="textarea" rows={4} placeholder="What do you need and why?"></textarea></div>
        </>}

        <div style={{
          background: 'var(--ts-paper-deep)',
          border: '1px solid var(--ts-line)',
          borderRadius: 4, padding: '10px 12px',
          fontSize: 12.5, color: 'var(--ts-ink-mute)', marginBottom: 18,
          lineHeight: 1.5,
        }}>
          Full review — five signals, then auto-execute or one-touch decision. Median time to resolution: 4 minutes.
        </div>

        <button className="btn btn--primary btn--block btn--lg" onClick={onSubmit}>
          Submit request
        </button>
      </div>
    </div>
  );
};

// ─── SUCCESS ─────────────────────────────────────────────────────────
const Success = ({ result, onDone }) => (
  <div className="content step-in" style={{ maxWidth: 680 }}>
    <div className="success">
      <svg width="88" height="88" viewBox="0 0 88 88" fill="none">
        <circle cx="44" cy="44" r="40" stroke="var(--ts-positive)" strokeWidth="1.5" className="success__circle" />
        <path d="M28 45 l11 11 21 -22" stroke="var(--ts-positive)" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" className="success__mark" />
      </svg>
      <h1 className="success__h">
        {result.item ? <>Order placed. <em>That's it.</em></> : <>Submitted. <em>The agent's on it.</em></>}
      </h1>
      <div className="success__ref">
        <span className="success__ref-label">Ref</span>
        <span className="success__ref-val">{result.ref}</span>
      </div>
      <p className="success__msg">
        {result.item
          ? <>Budget check running. You'll hear back at <b>{result.email}</b>.</>
          : <>Five signals running. You'll hear back at <b>{result.email}</b>.</>
        }
      </p>
      <div style={{ marginTop: 32, display: 'flex', gap: 10 }}>
        <button className="btn btn--secondary" onClick={onDone}>Back to operations</button>
      </div>
    </div>
  </div>
);

Object.assign(window, { Home, Catalog, OrderModal, MyOrders, RequestForm, Success, CATALOG, MY_ORDERS });
