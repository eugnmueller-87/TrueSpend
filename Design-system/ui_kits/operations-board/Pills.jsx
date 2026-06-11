/* Pills, eyebrows, sample data — shared across screens. */

const STATUS = {
  signature_required: { label: 'Signature required', dot: 'var(--ts-negative)',     bg: 'var(--ts-negative-wash)', fg: 'var(--ts-negative)' },
  pending_review:     { label: 'Pending review',     dot: 'var(--ts-warning)',      bg: 'var(--ts-warning-wash)',  fg: '#8C6510' },
  escalated:          { label: 'Escalated',          dot: 'var(--ts-info)',         bg: 'var(--ts-info-wash)',     fg: 'var(--ts-info)' },
  pending_confirm:    { label: 'Quick confirm',      dot: 'var(--ts-brand-gold)',   bg: 'var(--ts-brand-gold-wash)', fg: 'var(--ts-brand-gold-deep)' },
  approved:           { label: 'Approved',           dot: 'var(--ts-positive)',     bg: 'var(--ts-positive-wash)', fg: 'var(--ts-positive)' },
  rejected:           { label: 'Rejected',           dot: 'var(--ts-ink-faint)',    bg: 'var(--ts-paper-deep)',    fg: 'var(--ts-ink-mute)' },
  closed:             { label: 'Closed',             dot: 'var(--ts-ink-faint)',    bg: 'var(--ts-paper-deep)',    fg: 'var(--ts-ink-mute)' },
  auto_executed:      { label: 'Auto-executed',      dot: 'var(--ts-positive)',     bg: 'var(--ts-positive-wash)', fg: 'var(--ts-positive)' },
};

const COMPLIANCE = {
  green:   { label: 'Compliant', fg: 'var(--ts-positive)' },
  amber:   { label: 'Gaps',      fg: 'var(--ts-warning)' },
  red:     { label: 'Blocked',   fg: 'var(--ts-negative)' },
  pending: { label: 'Pending',   fg: 'var(--ts-ink-mute)' },
};

const StatusPill = ({ status }) => {
  const s = STATUS[status] || STATUS.closed;
  return (
    <span className="pill" style={{ background: s.bg, color: s.fg }}>
      <span className="pill__dot" style={{ background: s.dot }} />
      {s.label}
    </span>
  );
};

const CompliancePill = ({ status }) => {
  const c = COMPLIANCE[status] || COMPLIANCE.pending;
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 6,
      fontSize: 11.5, fontWeight: 500, color: c.fg, letterSpacing: '-0.005em'
    }}>
      <span style={{ width: 6, height: 6, borderRadius: '50%', background: c.fg }} />
      {c.label}
    </span>
  );
};

/* Money formatter — €1.234, de-DE locale (matches existing codebase) */
const formatEuro = (n) => '€' + n.toLocaleString('de-DE', { minimumFractionDigits: 0, maximumFractionDigits: 0 });

/* Mock "now" so ages render deterministically */
const NOW = new Date('2026-05-28T11:34:00Z');
const timeAgo = (iso) => {
  const m = Math.floor((NOW - new Date(iso)) / 60000);
  if (m < 1)  return 'just now';
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  return `${Math.floor(h / 24)}d ago`;
};

Object.assign(window, { STATUS, COMPLIANCE, StatusPill, CompliancePill, formatEuro, timeAgo, NOW });
