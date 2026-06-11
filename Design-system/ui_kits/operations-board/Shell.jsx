/* Shell — Sidebar nav + TopBar + page container. Desktop layout. */

const NAV_PRIMARY = [
  { id: 'board',   label: 'Operations',  Icon: IconBoard,    countKey: 'open' },
  { id: 'catalog', label: 'Catalog',     Icon: IconCatalog },
  { id: 'mine',    label: 'My requests', Icon: IconList },
  { id: 'home',    label: 'New request', Icon: IconPlus },
];

const NAV_SECONDARY = [
  { id: 'suppliers', label: 'Suppliers',  Icon: IconBuilding,   countKey: 'suppliers' },
  { id: 'budgets',   label: 'Budgets',    Icon: IconWrench,     countKey: 'budgets' },
  { id: 'contracts', label: 'Contracts',  Icon: IconRefresh,    countKey: 'contracts' },
];

const Sidebar = ({ tab, onNav, counts, openByStatus, onJumpSection }) => (
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
        const active = tab === id;
        const count = countKey ? counts[countKey] : null;
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
        );
      })}
    </nav>

    {tab === 'board' && openByStatus && (
      <div style={{ padding: '6px 12px 0', marginTop: 8 }}>
        {[
          { status: 'signature_required', label: 'Signature required', dot: 'var(--ts-negative)' },
          { status: 'pending_review',     label: 'Pending review',     dot: 'var(--ts-warning)' },
          { status: 'escalated',          label: 'Escalated',          dot: 'var(--ts-info)' },
          { status: 'pending_confirm',    label: 'Quick confirm',      dot: 'var(--ts-brand-gold)' },
        ].map(s => {
          const c = openByStatus[s.status] || 0;
          if (c === 0) return null;
          return (
            <button
              key={s.status}
              className="sidebar__sub"
              onClick={() => onJumpSection && onJumpSection(s.status)}
            >
              <span className="sidebar__sub-dot" style={{ background: s.dot }} />
              <span>{s.label}</span>
              <span className="sidebar__sub-count">{c}</span>
            </button>
          );
        })}
      </div>
    )}

    <div className="sidebar__sectionhead">Reference</div>
    <nav className="sidebar__nav">
      {NAV_SECONDARY.map(({ id, label, Icon }) => (
        <button key={id} className="sidebar__link" onClick={() => {}}>
          <span className="sidebar__link-icon"><Icon size={16} /></span>
          <span>{label}</span>
        </button>
      ))}
    </nav>

    <div className="sidebar__user">
      <div className="sidebar__avatar">EM</div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div className="sidebar__user-name">Eva Müller</div>
        <div className="sidebar__user-sub">DACH · Munich</div>
      </div>
      <button className="iconbtn" title="Switch user" style={{ width: 26, height: 26 }}>
        <IconChevDown size={14} />
      </button>
    </div>
  </aside>
);

const TopBar = ({ crumbs, actions, showSearch = true }) => (
  <div className="topbar">
    <div className="topbar__crumbs">
      {crumbs.map((c, i) => (
        <React.Fragment key={i}>
          {i > 0 && <IconChev size={12} style={{ color: 'var(--ts-ink-faint)' }} />}
          {i === crumbs.length - 1 ? <strong>{c}</strong> : <span>{c}</span>}
        </React.Fragment>
      ))}
    </div>
    <div className="topbar__right">
      {showSearch && (
        <div className="searchbar">
          <span className="searchbar__icon">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
              <circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/>
            </svg>
          </span>
          <input placeholder="Search requests, suppliers, refs…" />
          <span className="searchbar__kbd">⌘ K</span>
        </div>
      )}
      {actions}
      <button className="iconbtn" title="Notifications">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
          <path d="M18 8a6 6 0 1 0-12 0c0 7-3 9-3 9h18s-3-2-3-9"/>
          <path d="M13.7 21a2 2 0 0 1-3.4 0"/>
        </svg>
      </button>
    </div>
  </div>
);

Object.assign(window, { Sidebar, TopBar, NAV_PRIMARY, NAV_SECONDARY });
