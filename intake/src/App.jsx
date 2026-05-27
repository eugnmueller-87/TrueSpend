import { useState, useEffect, useRef } from 'react'

// ─── Constants ───────────────────────────────────────────────────────────────

const TICKET_TYPES = [
  { id: 'renew',    label: 'Renew a contract',   icon: '🔄', hint: 'Extend or renegotiate an existing agreement' },
  { id: 'purchase', label: 'Approve a purchase',  icon: '📦', hint: 'Get sign-off on a new spend item'           },
  { id: 'onboard',  label: 'Onboard a supplier',  icon: '🏢', hint: 'Bring a new vendor into the system'         },
  { id: 'other',    label: 'Something else',       icon: '⚡', hint: 'Any other procurement request'              },
]

// Branch display names mapped to their Supabase UUIDs (from db/seed/01_branches.sql)
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

const SUPPLIER_CATEGORIES = [
  'Hardware',
  'Cloud',
  'SaaS',
  'Services',
  'Other',
]

// ─── Helpers ─────────────────────────────────────────────────────────────────

function formatEuro(val) {
  if (!val) return ''
  const n = parseFloat(val)
  if (isNaN(n)) return val
  return n.toLocaleString('de-DE', { minimumFractionDigits: 0, maximumFractionDigits: 2 })
}

function required(val) {
  return val && val.toString().trim().length > 0
}

function validEmail(val) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(val)
}

// ─── Sub-components ──────────────────────────────────────────────────────────

function StepWrapper({ children, visible }) {
  const ref = useRef(null)

  useEffect(() => {
    const el = ref.current
    if (!el) return
    el.classList.add('step-enter')
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        el.classList.remove('step-enter')
        el.classList.add('step-visible')
      })
    })
  }, [visible])

  return (
    <div
      ref={ref}
      className="step-visible w-full"
      style={{ willChange: 'opacity, transform' }}
    >
      {children}
    </div>
  )
}

function Label({ children, required: req }) {
  return (
    <label className="block text-sm font-medium text-white mb-1.5">
      {children}
      {req && <span className="text-indigo-400 ml-0.5">*</span>}
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

function TextInput({ value, onChange, placeholder, error, type = 'text', inputMode, ...rest }) {
  return (
    <input
      type={type}
      inputMode={inputMode}
      value={value}
      onChange={(e) => onChange(e.target.value)}
      placeholder={placeholder}
      className={error ? 'error' : ''}
      {...rest}
    />
  )
}

function EuroInput({ value, onChange, placeholder = '0', error }) {
  return (
    <div className="relative">
      <span
        className="absolute left-3 top-1/2 -translate-y-1/2 text-sm pointer-events-none"
        style={{ color: '#666' }}
      >
        €
      </span>
      <input
        type="number"
        inputMode="decimal"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        className={error ? 'error' : ''}
        style={{ paddingLeft: '28px' }}
        min="0"
        step="any"
      />
    </div>
  )
}

function SelectInput({ value, onChange, options, placeholder, error }) {
  return (
    <select
      value={value}
      onChange={(e) => onChange(e.target.value)}
      className={error ? 'error' : ''}
    >
      <option value="" disabled>
        {placeholder || 'Select…'}
      </option>
      {options.map((opt) => (
        <option key={opt} value={opt}>
          {opt}
        </option>
      ))}
    </select>
  )
}

function TextArea({ value, onChange, placeholder, error, rows = 3 }) {
  return (
    <textarea
      value={value}
      onChange={(e) => onChange(e.target.value)}
      placeholder={placeholder}
      rows={rows}
      className={error ? 'error' : ''}
    />
  )
}

function UrgencyToggle({ value, onChange }) {
  return (
    <div className="flex">
      <button
        type="button"
        className={`toggle-btn${value === 'normal' ? ' active' : ''}`}
        onClick={() => onChange('normal')}
      >
        Normal
      </button>
      <button
        type="button"
        className={`toggle-btn${value === 'urgent' ? ' active' : ''}`}
        onClick={() => onChange('urgent')}
      >
        🔴 Urgent
      </button>
    </div>
  )
}

function SubmitButton({ loading, children }) {
  return (
    <button
      type="submit"
      disabled={loading}
      className="w-full flex items-center justify-center gap-2 rounded-lg font-semibold text-white transition-all"
      style={{
        background: loading ? '#4f52d9' : '#6366f1',
        minHeight: '52px',
        fontSize: '15px',
        border: 'none',
        cursor: loading ? 'not-allowed' : 'pointer',
        opacity: loading ? 0.85 : 1,
      }}
    >
      {loading ? (
        <>
          <span className="spinner" />
          <span>Submitting…</span>
        </>
      ) : (
        children
      )}
    </button>
  )
}

function BackButton({ onClick }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="flex items-center gap-1.5 text-sm transition-colors"
      style={{ color: '#888', background: 'none', border: 'none', cursor: 'pointer', padding: '0' }}
    >
      <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
        <path d="M9 2L4 7l5 5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
      Back
    </button>
  )
}

// ─── Step 1: Type selection ───────────────────────────────────────────────────

function StepSelectType({ onSelect }) {
  return (
    <StepWrapper visible>
      <div className="mb-8 text-center">
        <div className="inline-flex items-center gap-2 mb-6">
          <span className="text-xl font-bold tracking-tight" style={{ color: '#6366f1' }}>TrueSpend</span>
        </div>
        <h1 className="text-2xl font-semibold text-white mb-2">What do you need?</h1>
        <p className="text-sm" style={{ color: '#888' }}>
          Pick the request type and we'll handle the rest.
        </p>
      </div>

      <div className="grid gap-3">
        {TICKET_TYPES.map((t) => (
          <button
            key={t.id}
            type="button"
            onClick={() => onSelect(t.id)}
            className="w-full text-left rounded-xl border transition-all"
            style={{
              background: '#141414',
              borderColor: '#2a2a2a',
              padding: '18px 20px',
              cursor: 'pointer',
              minHeight: '72px',
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.borderColor = '#6366f1'
              e.currentTarget.style.background = '#18181f'
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.borderColor = '#2a2a2a'
              e.currentTarget.style.background = '#141414'
            }}
          >
            <div className="flex items-center gap-4">
              <span className="text-2xl leading-none flex-shrink-0">{t.icon}</span>
              <div>
                <div className="font-semibold text-white text-[15px]">{t.label}</div>
                <div className="text-xs mt-0.5" style={{ color: '#666' }}>{t.hint}</div>
              </div>
              <svg
                className="ml-auto flex-shrink-0"
                width="16"
                height="16"
                viewBox="0 0 16 16"
                fill="none"
                style={{ color: '#444' }}
              >
                <path d="M6 3l5 5-5 5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
            </div>
          </button>
        ))}
      </div>
    </StepWrapper>
  )
}

// ─── Step 2: Forms ────────────────────────────────────────────────────────────

// Shared requester fields (name, email, branch) appended to every form
function RequesterFields({ values, errors, onChange }) {
  return (
    <>
      <div className="mt-2 mb-4" style={{ borderTop: '1px solid #1e1e1e', paddingTop: '20px' }}>
        <p className="text-xs font-medium uppercase tracking-wider mb-4" style={{ color: '#555' }}>
          About you
        </p>
      </div>
      <Field label="Your name" required error={errors.submitted_by}>
        <TextInput
          value={values.submitted_by}
          onChange={(v) => onChange('submitted_by', v)}
          placeholder="Jane Smith"
          error={errors.submitted_by}
          autoComplete="name"
        />
      </Field>
      <Field label="Your email" required error={errors.submitted_by_email}>
        <TextInput
          type="email"
          value={values.submitted_by_email}
          onChange={(v) => onChange('submitted_by_email', v)}
          placeholder="jane@company.com"
          error={errors.submitted_by_email}
          autoComplete="email"
        />
      </Field>
      <Field label="Branch" required error={errors.branch_id}>
        <select
          value={values.branch_id}
          onChange={(e) => onChange('branch_id', e.target.value)}
          className={errors.branch_id ? 'error' : ''}
        >
          <option value="" disabled>Select your region</option>
          {BRANCHES.map((b) => (
            <option key={b.id} value={b.id}>{b.label}</option>
          ))}
        </select>
      </Field>
    </>
  )
}

// ── Renew a contract ──
function FormRenew({ values, errors, onChange, onSubmit, onBack, loading }) {
  return (
    <form onSubmit={onSubmit} noValidate>
      <div className="flex items-center gap-3 mb-6">
        <BackButton onClick={onBack} />
        <div className="flex items-center gap-2">
          <span className="text-lg">🔄</span>
          <h2 className="text-lg font-semibold text-white">Renew a contract</h2>
        </div>
      </div>

      <Field label="Supplier name" required error={errors.supplier_name}>
        <TextInput
          value={values.supplier_name}
          onChange={(v) => onChange('supplier_name', v)}
          placeholder="Acme Corp"
          error={errors.supplier_name}
          autoComplete="off"
        />
      </Field>
      <Field label="Contract value" required error={errors.amount}>
        <EuroInput
          value={values.amount}
          onChange={(v) => onChange('amount', v)}
          error={errors.amount}
        />
      </Field>
      <Field label="Anything we should know?" error={errors.notes}>
        <TextArea
          value={values.notes}
          onChange={(v) => onChange('notes', v)}
          placeholder="Optional — expiry dates, key terms, changes requested…"
          error={errors.notes}
        />
      </Field>

      <RequesterFields values={values} errors={errors} onChange={onChange} />
      <SubmitButton loading={loading}>Submit request</SubmitButton>
    </form>
  )
}

// ── Approve a purchase ──
function FormPurchase({ values, errors, onChange, onSubmit, onBack, loading }) {
  return (
    <form onSubmit={onSubmit} noValidate>
      <div className="flex items-center gap-3 mb-6">
        <BackButton onClick={onBack} />
        <div className="flex items-center gap-2">
          <span className="text-lg">📦</span>
          <h2 className="text-lg font-semibold text-white">Approve a purchase</h2>
        </div>
      </div>

      <Field label="Supplier" required error={errors.supplier_name}>
        <TextInput
          value={values.supplier_name}
          onChange={(v) => onChange('supplier_name', v)}
          placeholder="Supplier name"
          error={errors.supplier_name}
          autoComplete="off"
        />
      </Field>
      <Field label="Amount" required error={errors.amount}>
        <EuroInput
          value={values.amount}
          onChange={(v) => onChange('amount', v)}
          error={errors.amount}
        />
      </Field>
      <Field label="What's it for?" required error={errors.description}>
        <TextInput
          value={values.description}
          onChange={(v) => onChange('description', v)}
          placeholder="Brief description of the purchase"
          error={errors.description}
        />
      </Field>
      <Field label="Urgency" error={errors.urgency}>
        <UrgencyToggle
          value={values.urgency || 'normal'}
          onChange={(v) => onChange('urgency', v)}
        />
      </Field>

      <RequesterFields values={values} errors={errors} onChange={onChange} />
      <SubmitButton loading={loading}>Submit request</SubmitButton>
    </form>
  )
}

// ── Onboard a supplier ──
function FormOnboard({ values, errors, onChange, onSubmit, onBack, loading }) {
  return (
    <form onSubmit={onSubmit} noValidate>
      <div className="flex items-center gap-3 mb-6">
        <BackButton onClick={onBack} />
        <div className="flex items-center gap-2">
          <span className="text-lg">🏢</span>
          <h2 className="text-lg font-semibold text-white">Onboard a supplier</h2>
        </div>
      </div>

      <Field label="Company name" required error={errors.supplier_name}>
        <TextInput
          value={values.supplier_name}
          onChange={(v) => onChange('supplier_name', v)}
          placeholder="New Vendor Ltd"
          error={errors.supplier_name}
          autoComplete="off"
        />
      </Field>
      <Field label="Country" required error={errors.country}>
        <TextInput
          value={values.country}
          onChange={(v) => onChange('country', v)}
          placeholder="e.g. Germany"
          error={errors.country}
        />
      </Field>
      <Field label="Category" required error={errors.category}>
        <SelectInput
          value={values.category}
          onChange={(v) => onChange('category', v)}
          options={SUPPLIER_CATEGORIES}
          placeholder="Select category"
          error={errors.category}
        />
      </Field>
      <Field label="Why do we need them?" required error={errors.description}>
        <TextInput
          value={values.description}
          onChange={(v) => onChange('description', v)}
          placeholder="Brief business justification"
          error={errors.description}
        />
      </Field>

      <RequesterFields values={values} errors={errors} onChange={onChange} />
      <SubmitButton loading={loading}>Submit request</SubmitButton>
    </form>
  )
}

// ── Something else ──
function FormOther({ values, errors, onChange, onSubmit, onBack, loading }) {
  return (
    <form onSubmit={onSubmit} noValidate>
      <div className="flex items-center gap-3 mb-6">
        <BackButton onClick={onBack} />
        <div className="flex items-center gap-2">
          <span className="text-lg">⚡</span>
          <h2 className="text-lg font-semibold text-white">Something else</h2>
        </div>
      </div>

      <Field label="Title" required error={errors.title}>
        <TextInput
          value={values.title}
          onChange={(v) => onChange('title', v)}
          placeholder="Short summary of your request"
          error={errors.title}
        />
      </Field>
      <Field label="Description" required error={errors.description}>
        <TextArea
          value={values.description}
          onChange={(v) => onChange('description', v)}
          placeholder="Tell us what you need and why"
          error={errors.description}
          rows={4}
        />
      </Field>
      <Field label="Amount (if applicable)" error={errors.amount}>
        <EuroInput
          value={values.amount}
          onChange={(v) => onChange('amount', v)}
          placeholder="Optional"
          error={errors.amount}
        />
      </Field>

      <RequesterFields values={values} errors={errors} onChange={onChange} />
      <SubmitButton loading={loading}>Submit request</SubmitButton>
    </form>
  )
}

// ─── Step 4: Done screen ──────────────────────────────────────────────────────

function StepDone({ reference, email }) {
  return (
    <StepWrapper visible>
      <div className="flex flex-col items-center text-center py-8">
        {/* Animated checkmark */}
        <div className="mb-8">
          <svg width="88" height="88" viewBox="0 0 88 88" fill="none">
            <circle
              className="check-circle"
              cx="44"
              cy="44"
              r="40"
              fill="#16a34a"
              fillOpacity="0.15"
              stroke="#22c55e"
              strokeWidth="2"
            />
            <path
              className="check-mark"
              d="M27 45l12 12 22-22"
              stroke="#22c55e"
              strokeWidth="3"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        </div>

        <h1 className="text-3xl font-bold text-white mb-3">Submitted</h1>

        {reference && (
          <div
            className="inline-flex items-center gap-2 rounded-lg px-4 py-2 mb-6"
            style={{ background: '#141414', border: '1px solid #2a2a2a' }}
          >
            <span className="text-xs font-medium uppercase tracking-wider" style={{ color: '#888' }}>
              Reference
            </span>
            <span className="font-mono font-semibold text-white text-sm">{reference}</span>
          </div>
        )}

        <p className="text-base mb-3" style={{ color: '#aaa', maxWidth: '320px' }}>
          The agent is reviewing this. You'll hear back at{' '}
          <span className="text-white font-medium">{email}</span>.
        </p>

        <p className="text-sm" style={{ color: '#555' }}>
          You can close this tab.
        </p>
      </div>
    </StepWrapper>
  )
}

// ─── Validation ──────────────────────────────────────────────────────────────

const sharedRules = {
  submitted_by:       (v) => required(v) ? null : 'Your name is required',
  submitted_by_email: (v) => {
    if (!required(v)) return 'Your email is required'
    if (!validEmail(v)) return 'Enter a valid email address'
    return null
  },
  branch_id: (v) => required(v) ? null : 'Please select your branch',
}

const typeRules = {
  renew: {
    supplier_name: (v) => required(v) ? null : 'Supplier name is required',
    amount:        (v) => required(v) ? null : 'Contract value is required',
  },
  purchase: {
    supplier_name: (v) => required(v) ? null : 'Supplier is required',
    amount:        (v) => required(v) ? null : 'Amount is required',
    description:   (v) => required(v) ? null : 'Please describe what this is for',
  },
  onboard: {
    supplier_name: (v) => required(v) ? null : 'Company name is required',
    country:       (v) => required(v) ? null : 'Country is required',
    category:      (v) => required(v) ? null : 'Please select a category',
    description:   (v) => required(v) ? null : 'Business justification is required',
  },
  other: {
    title:       (v) => required(v) ? null : 'Title is required',
    description: (v) => required(v) ? null : 'Description is required',
  },
}

function validate(ticketType, values) {
  const rules = { ...typeRules[ticketType], ...sharedRules }
  const errors = {}
  let hasError = false
  for (const [field, rule] of Object.entries(rules)) {
    const msg = rule(values[field] || '')
    if (msg) {
      errors[field] = msg
      hasError = true
    }
  }
  return { errors, hasError }
}

// ─── Build API payload ────────────────────────────────────────────────────────

function buildPayload(ticketType, values) {
  const type = TICKET_TYPES.find((t) => t.id === ticketType)
  const title =
    ticketType === 'other'
      ? values.title
      : ticketType === 'renew'
      ? `Renew contract — ${values.supplier_name}`
      : ticketType === 'purchase'
      ? `Purchase approval — ${values.supplier_name}`
      : `Onboard supplier — ${values.supplier_name}`

  return {
    ticket_type:         ticketType,
    ticket_type_label:   type?.label || ticketType,
    title,
    description:         values.description   || null,
    supplier_name:       values.supplier_name || null,
    amount:              values.amount ? parseFloat(values.amount) : null,
    currency:            'EUR',
    country:             values.country       || null,
    category:            values.category      || null,
    notes:               values.notes         || null,
    urgency:             values.urgency        || 'normal',
    submitted_by:        values.submitted_by,
    submitted_by_email:  values.submitted_by_email,
    branch_id:           values.branch_id,
    submitted_at:        new Date().toISOString(),
  }
}

// ─── Main App ─────────────────────────────────────────────────────────────────

export default function App() {
  const [step, setStep] = useState('select') // 'select' | 'form' | 'done'
  const [ticketType, setTicketType] = useState(null)
  const [values, setValues] = useState({})
  const [errors, setErrors] = useState({})
  const [loading, setLoading] = useState(false)
  const [submitError, setSubmitError] = useState(null)
  const [reference, setReference] = useState(null)

  function handleSelectType(type) {
    setTicketType(type)
    setValues({ urgency: 'normal' }) // reset with sensible default
    setErrors({})
    setSubmitError(null)
    setStep('form')
  }

  function handleChange(field, val) {
    setValues((prev) => ({ ...prev, [field]: val }))
    // Clear error on change
    if (errors[field]) {
      setErrors((prev) => ({ ...prev, [field]: null }))
    }
  }

  function handleBack() {
    setStep('select')
    setTicketType(null)
    setErrors({})
    setSubmitError(null)
  }

  async function handleSubmit(e) {
    e.preventDefault()

    const { errors: validationErrors, hasError } = validate(ticketType, values)
    if (hasError) {
      setErrors(validationErrors)
      // Scroll to first error
      const firstError = document.querySelector('.error, [aria-invalid="true"]')
      firstError?.scrollIntoView({ behavior: 'smooth', block: 'center' })
      return
    }

    setLoading(true)
    setSubmitError(null)

    const payload = buildPayload(ticketType, values)

    try {
      const res = await fetch('/api/intake', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      })

      if (!res.ok) {
        const text = await res.text().catch(() => '')
        throw new Error(text || `Server error ${res.status}`)
      }

      let data = {}
      try {
        data = await res.json()
      } catch {
        // Response might not be JSON — that's fine
      }

      const ref = data?.reference || data?.ticket_id || data?.id || null
      setReference(ref)
      setStep('done')
    } catch (err) {
      console.error('Intake submit error:', err)
      setSubmitError(
        err.message?.includes('Failed to fetch')
          ? 'Could not reach the server. Check your connection and try again.'
          : err.message || 'Something went wrong. Please try again.'
      )
    } finally {
      setLoading(false)
    }
  }

  const formProps = {
    values,
    errors,
    onChange: handleChange,
    onSubmit: handleSubmit,
    onBack: handleBack,
    loading,
  }

  return (
    <div
      className="min-h-screen flex flex-col items-center justify-center px-4 py-12"
      style={{ background: '#0a0a0a' }}
    >
      <div className="w-full" style={{ maxWidth: '440px' }}>

        {/* Step 1 — Select type */}
        {step === 'select' && (
          <StepSelectType onSelect={handleSelectType} />
        )}

        {/* Step 2 — Form */}
        {step === 'form' && ticketType && (
          <StepWrapper visible={step === 'form'}>
            {ticketType === 'renew'    && <FormRenew    {...formProps} />}
            {ticketType === 'purchase' && <FormPurchase {...formProps} />}
            {ticketType === 'onboard'  && <FormOnboard  {...formProps} />}
            {ticketType === 'other'    && <FormOther    {...formProps} />}

            {submitError && (
              <div
                className="mt-4 rounded-lg px-4 py-3 text-sm"
                style={{ background: '#1a0808', border: '1px solid #3f1010', color: '#f87171' }}
              >
                {submitError}
              </div>
            )}
          </StepWrapper>
        )}

        {/* Step 3 — Done */}
        {step === 'done' && (
          <StepDone reference={reference} email={values.submitted_by_email} />
        )}

        {/* Wordmark footer — only on select step */}
        {step === 'select' && (
          <p className="text-center text-xs mt-8" style={{ color: '#333' }}>
            Powered by TrueSpend · Procurement OS
          </p>
        )}
      </div>
    </div>
  )
}
