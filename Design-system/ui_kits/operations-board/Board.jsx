/* Operations Board — desktop centerpiece. */

const BOARD_TICKETS = [
  {
    id: 't1',
    status: 'signature_required',
    compliance: 'green',
    title: 'Renew — Deloitte SOC 2 Type II audit',
    value: 35000,
    supplier: 'Deloitte',
    supplierMeta: 'Strategic · Audit',
    branch: 'Global HQ',
    ref: 'TS-2026-0476',
    age: '2d ago',
    confidence: 0.92,
    brief: "Framework agreement on file. Pricing matches the Q4 negotiation we held. Auto-renew clause already disabled per board policy. Counterparty NDA current. Nothing to argue — ready to sign.",
    signals: [
      { label: 'Contract', state: 'green', note: 'Matches framework T&Cs' },
      { label: 'Budget',   state: 'green', note: 'Audit bucket at 41% YTD' },
      { label: 'Supplier', state: 'green', note: 'On strategic tier' },
      { label: 'Request',  state: 'green', note: 'Annual recurring' },
      { label: 'Policy',   state: 'green', note: 'Within Eva\u2019s authority' },
    ],
  },
  {
    id: 't2',
    status: 'pending_review',
    compliance: 'green',
    title: 'Renew — CalDigit TS4 dock fleet (+40 seats)',
    value: 11960,
    supplier: 'CalDigit',
    supplierMeta: 'Performing · Hardware',
    branch: 'DACH',
    ref: 'TS-2026-0481',
    age: '13m ago',
    confidence: 0.91,
    brief: "Bulk pricing tier reached at 200+ units. €12 / seat saved versus catalog. DACH still has €38k Q2 hardware headroom; this lands at 74%. Recommend approve.",
    signals: [
      { label: 'Contract', state: 'green', note: 'Bulk tier triggered' },
      { label: 'Budget',   state: 'green', note: 'DACH hardware 64% YTD' },
      { label: 'Supplier', state: 'green', note: 'No open disputes' },
      { label: 'Request',  state: 'green', note: 'Matches headcount plan' },
      { label: 'Policy',   state: 'amber', note: 'Crosses €10k confirm threshold' },
    ],
  },
  {
    id: 't3',
    status: 'escalated',
    compliance: 'amber',
    title: 'Purchase — Adobe CC Enterprise (3-year commit)',
    value: 184500,
    supplier: 'Adobe',
    supplierMeta: 'Strategic · SaaS',
    branch: 'Benelux',
    ref: 'TS-2026-0469',
    age: '4h ago',
    confidence: 0.61,
    brief: "Crosses €100k threshold and triggers automatic escalation. SaaS taxonomy overlap: 45 Figma Org seats already provisioned in Benelux. 3-year commit removes flexibility just as Figma is closing the design-to-handoff gap. Recommend re-scope to 1-year commit before sign.",
    signals: [
      { label: 'Contract', state: 'amber', note: '3-yr commit · low flex' },
      { label: 'Budget',   state: 'green', note: 'Within Benelux software bucket' },
      { label: 'Supplier', state: 'green', note: 'Strategic, performing' },
      { label: 'Request',  state: 'amber', note: 'Overlap with Figma (45 seats)' },
      { label: 'Policy',   state: 'red',   note: 'Exceeds €100k — board sign-off' },
    ],
  },
  {
    id: 't4',
    status: 'pending_confirm',
    compliance: 'green',
    title: 'Purchase — Anthropic API (Q3 commit, 6 dev seats)',
    value: 4800,
    supplier: 'Anthropic',
    supplierMeta: 'Performing · LLM',
    branch: 'Global HQ',
    ref: 'TS-2026-0492',
    age: '8m ago',
    confidence: 0.94,
    brief: "Existing API key registered. Reallocating from the LLM bucket — €18.4k remaining this quarter. All signals green. One-touch confirm.",
    signals: [
      { label: 'Contract', state: 'green', note: 'Master terms in place' },
      { label: 'Budget',   state: 'green', note: 'LLM bucket 71% YTD' },
      { label: 'Supplier', state: 'green', note: 'Performing' },
      { label: 'Request',  state: 'green', note: 'Standard team scale' },
      { label: 'Policy',   state: 'green', note: 'Auto-approve eligible' },
    ],
  },
];

const SECTIONS = [
  { id: 'sig', Icon: IconPenLine, title: 'Signature required',          urgent: true,  filter: 'signature_required', hint: 'Final human checkpoint — agent has prepared the package.' },
  { id: 'rev', Icon: IconEye,     title: 'Pending review',              urgent: false, filter: 'pending_review',     hint: 'One signal uncertain — agent recommends, you decide.' },
  { id: 'esc', Icon: IconSiren,   title: 'Escalated',                   urgent: false, filter: 'escalated',          hint: 'Crosses €100k or hits a compliance blocker.' },
  { id: 'con', Icon: IconZap,     title: 'Quick confirm',               urgent: false, filter: 'pending_confirm',    hint: 'Standard request — one-touch and the agent does the rest.' },
];

const SIGNAL_COLORS = {
  green: 'var(--ts-positive)',
  amber: 'var(--ts-warning)',
  red:   'var(--ts-negative)',
};

const TicketRow = ({ ticket, isOpen, onToggle, onAction }) => {
  return (
    <React.Fragment>
      <div
        className={'trow' + (isOpen ? ' trow--open' : '')}
        onClick={() => onToggle(ticket.id)}
      >
        <div className="trow__status">
          <StatusPill status={ticket.status} />
        </div>
        <div className="trow__main">
          <div className="trow__title">{ticket.title}</div>
          <div className="trow__meta">
            <span className="ref">{ticket.ref}</span>
            <span className="dot" />
            <CompliancePill status={ticket.compliance} />
            <span className="dot" />
            <span>{ticket.age}</span>
          </div>
        </div>
        <div>
          <div className="trow__supplier">{ticket.supplier}</div>
          <div className="trow__supplier-meta">{ticket.branch}</div>
        </div>
        <div>
          <div className="trow__value">{formatEuro(ticket.value)}</div>
          <div className="trow__conf">conf. {Math.round(ticket.confidence * 100)}%</div>
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
            <div className="tbrief__h">Agent brief</div>
            <div className="tbrief__body">{ticket.brief}</div>
          </div>
          <div>
            <div className="tbrief__h">Five signals</div>
            <div className="tbrief__signals">
              {ticket.signals.map(s => (
                <div key={s.label} className="tbrief__signal">
                  <span className="tbrief__signal-dot" style={{ background: SIGNAL_COLORS[s.state] }} />
                  <span style={{ width: 64, color: 'var(--ts-ink)' }}>{s.label}</span>
                  <span style={{ color: 'var(--ts-ink-mute)' }}>{s.note}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}
    </React.Fragment>
  );
};

const StatsStrip = ({ tickets }) => {
  const totalValue = tickets.reduce((s, t) => s + t.value, 0);
  return (
    <div className="stats">
      <div className="stat">
        <div className="stat__label">Need you</div>
        <div className="stat__val">{tickets.length}</div>
        <div className="stat__hint">Across {SECTIONS.filter(s => tickets.some(t => t.status === s.filter)).length} sections</div>
      </div>
      <div className="stat">
        <div className="stat__label">Value at decision</div>
        <div className="stat__val">{formatEuro(totalValue)}</div>
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
  );
};

const AGENT_FEED = [
  { time: '11:32', title: 'Auto-approved Figma Organization × 6',           branch: 'DACH',     value: 270 },
  { time: '11:28', title: 'Released Q2 commit on AWS reserved (us-east-1)', branch: 'Global',   value: 9400 },
  { time: '11:14', title: 'Reordered Dell UltraSharp 27" × 4',              branch: 'Nordics',  value: 2196 },
  { time: '10:51', title: 'Closed Slack Pro renewal — same terms',          branch: 'Iberia',   value: 1248 },
  { time: '10:39', title: 'Auto-approved MS 365 E3 × 12 onboardings',       branch: 'DACH',     value: 432 },
  { time: '10:22', title: 'Cleared shelfware: 14 Salesforce seats',         branch: 'Benelux',  value: -2380, dim: true },
  { time: '09:57', title: 'Onboarded NCC Group — DPA + NDA signed',         branch: 'UK & IE',  value: 0,    dim: true },
];

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
                <span style={{ width: 3, height: 3, borderRadius: '50%', background: 'var(--ts-line-strong)' }} />
                <span className="money" style={{
                  color: e.value < 0 ? 'var(--ts-positive)' : (e.dim ? 'var(--ts-ink-mute)' : 'var(--ts-ink-soft)')
                }}>
                  {e.value < 0 ? '−' : ''}{formatEuro(Math.abs(e.value))}
                </span>
              </>
            )}
          </div>
        </div>
      ))}
    </div>
  </aside>
);

const Board = ({ tickets, onAction, openId, setOpenId, sectionJump }) => {
  React.useEffect(() => {
    if (sectionJump) {
      const el = document.getElementById('sec-' + sectionJump);
      if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  }, [sectionJump]);

  if (tickets.length === 0) {
    return (
      <div className="content content--with-rail step-in">
        <div>
          <div className="pagehead">
            <div>
              <div className="pagehead__eyebrow">Operations · 28 May 2026</div>
              <h1 className="pagehead__title">All clear.</h1>
              <div className="pagehead__sub">Nothing needs you right now. The agent is handling everything in the queue.</div>
            </div>
            <div className="pagehead__actions">
              <button className="btn btn--secondary"><IconRotateCw size={14}/> Refresh</button>
            </div>
          </div>
          <div style={{ background: 'var(--ts-surface)', border: '1px solid var(--ts-line)', borderRadius: 8, padding: '80px 24px', textAlign: 'center' }}>
            <IconCheck size={44} color="var(--ts-positive)" strokeWidth={1.25} />
            <h2 style={{ fontFamily: 'var(--ts-font-display)', fontSize: 32, letterSpacing: '-0.025em', color: 'var(--ts-ink)', margin: '18px 0 6px' }}>
              Nothing <em style={{ color: 'var(--ts-brand-gold-deep)' }}>needs you</em>.
            </h2>
            <p style={{ fontSize: 13.5, color: 'var(--ts-ink-mute)', maxWidth: 360, margin: '0 auto', lineHeight: 1.6 }}>
              Come back when there's something worth your attention.
            </p>
          </div>
        </div>
        <AgentRail />
      </div>
    );
  }

  return (
    <div className="content content--with-rail step-in">
      <div>
        <div className="pagehead">
          <div>
            <div className="pagehead__eyebrow">Operations · 28 May 2026</div>
            <h1 className="pagehead__title">
              {tickets.length} {tickets.length === 1 ? 'thing' : 'things'} <em>need you</em>.
            </h1>
            <div className="pagehead__sub">
              Everything else, the agent closed. Expand any row for the five-signal brief.
            </div>
          </div>
          <div className="pagehead__actions">
            <button className="btn btn--tertiary"><IconRotateCw size={14}/> Refresh</button>
            <button className="btn btn--secondary">Export</button>
          </div>
        </div>

        <StatsStrip tickets={tickets} />

        {SECTIONS.map(sec => {
          const inSec = tickets.filter(t => t.status === sec.filter);
          if (inSec.length === 0) return null;
          return (
            <section key={sec.id} id={'sec-' + sec.filter} className={'section' + (sec.urgent ? ' section--urgent' : '')}>
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
                    onAction={onAction}
                  />
                ))}
              </div>
            </section>
          );
        })}
      </div>

      <AgentRail />
    </div>
  );
};

Object.assign(window, { Board, BOARD_TICKETS, SECTIONS, TicketRow, AgentRail, StatsStrip });
