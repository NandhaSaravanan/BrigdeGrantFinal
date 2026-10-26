import { cloneElement, useId, useState, type FormEvent, type ReactElement } from 'react'
import { Link } from 'react-router-dom'

import { Icon, type IconName } from '../components/Icon'
import { Card } from '../components/ui'
import { isValidEmail, isValidPhone } from '../lib/format'
import { useApi } from '../lib/hooks'
import { HELP_TYPES, STAGES } from '../lib/types'

const STEPS: { title: string; body: string; link?: [string, string] }[] = [
  {
    title: 'Define your mission and build a founding board',
    body:
      'Write a short mission statement and recruit people with the skills you will need. Look up local ' +
      'nonprofits doing similar work under Recipients to learn from them or partner instead of duplicating.',
  },
  {
    title: 'Incorporate as a South Carolina nonprofit',
    body: 'File Articles of Incorporation for a nonprofit corporation with the SC Secretary of State.',
    link: ['SC Secretary of State', 'https://sos.sc.gov/'],
  },
  {
    title: 'Get an Employer Identification Number (EIN)',
    body: 'An EIN is free from the IRS and is needed for bank accounts and tax-exempt status.',
    link: [
      'IRS: Get an EIN',
      'https://www.irs.gov/businesses/small-businesses-self-employed/get-an-employer-identification-number',
    ],
  },
  {
    title: 'Adopt bylaws and core policies',
    body: 'Bylaws, a conflict-of-interest policy, and basic financial controls are expected by funders and the IRS.',
  },
  {
    title: 'Apply for 501(c)(3) tax-exempt status',
    body: 'Most groups file IRS Form 1023 or the shorter 1023-EZ if eligible.',
    link: ['IRS: Applying for tax-exempt status', 'https://www.irs.gov/charities-non-profits/applying-for-tax-exempt-status'],
  },
  {
    title: 'Register before asking the public for donations',
    body: 'South Carolina generally requires charities to register with the Secretary of State before soliciting donations.',
    link: ['SC Secretary of State', 'https://sos.sc.gov/'],
  },
  {
    title: 'Stay compliant every year',
    body: 'File the annual IRS Form 990-series return and keep state registrations current. Funders often review your 990.',
    link: ['IRS: Annual filing and forms', 'https://www.irs.gov/charities-non-profits/annual-filing-and-forms'],
  },
]

const RESEARCH: { to: string; icon: IconName; title: string; body: string }[] = [
  {
    to: '/funders',
    icon: 'bank',
    title: 'Find funders who give locally',
    body: 'See which foundations reported grants in this area, how much, and to whom.',
  },
  {
    to: '/recipients',
    icon: 'people',
    title: 'Learn from peer nonprofits',
    body: 'Look up organizations doing similar work and the funders that support them.',
  },
  {
    to: '/grants',
    icon: 'filter',
    title: 'Check typical grant sizes',
    body: 'Filter grants by city, year, and amount to set a realistic ask.',
  },
]

export function HelpPage() {
  return (
    <div className="page">
      <section className="hero">
        <span className="hero-pill">
          <Icon name="heart" size={14} /> For nonprofit founders and leaders
        </span>
        <h1 className="hero-heading">Starting or growing a nonprofit?</h1>
        <p className="hero-sub">
          Tell us what you are working on and what kind of help you need. We will follow up with resources or a
          connection.
        </p>
        <a className="btn btn-hero" href="#request">
          <Icon name="send" size={18} /> Request help
        </a>
      </section>

      <div className="grid-2">
        <Card title="First steps to start a nonprofit in SC" icon="check">
          <ol className="steps">
            {STEPS.map((s) => (
              <li key={s.title}>
                <strong>{s.title}</strong>
                <span className="muted">{s.body}</span>
                {s.link && (
                  <a href={s.link[1]} target="_blank" rel="noopener noreferrer">
                    {s.link[0]} <Icon name="external" size={14} />
                  </a>
                )}
              </li>
            ))}
          </ol>
          <p className="muted small">
            General information, not legal or tax advice. Confirm current requirements and fees with the agencies
            linked above.
          </p>
        </Card>
        <div className="stack">
          <Card title="Use this site to research" icon="bulb">
            {RESEARCH.map((r) => (
              <Link key={r.to} className="action-row" to={r.to}>
                <span className="icon-badge">
                  <Icon name={r.icon} size={18} />
                </span>
                <span>
                  <strong>{r.title}</strong>
                  <span className="muted small">{r.body}</span>
                </span>
              </Link>
            ))}
          </Card>
          <Card title="About this data" icon="info">
            <p>
              Grant records come from IRS Form 990 Schedule I and 990-PF filings, matched on filing ID, recipient,
              city, state, and amount. Use “Open source filing” on any grant to see the original.
            </p>
          </Card>
        </div>
      </div>

      <HelpForm />
    </div>
  )
}

/**
 * Labeled form control with its error message outside the label, linked via
 * aria-describedby, so the control's accessible name stays stable.
 */
function Field({ label, error, children }: { label: string; error?: string; children: ReactElement<Record<string, unknown>> }) {
  const id = useId()
  const errorId = `${id}-error`
  return (
    <div className="field">
      <label htmlFor={id}>{label}</label>
      {cloneElement(children, {
        id,
        'aria-invalid': error ? true : undefined,
        'aria-describedby': error ? errorId : undefined,
      })}
      {error && (
        <span id={errorId} className="field-error">
          {error}
        </span>
      )}
    </div>
  )
}

interface FormErrors {
  name?: string
  email?: string
  phone?: string
  help?: string
  consent?: string
}

export function HelpForm() {
  const api = useApi()
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [phone, setPhone] = useState('')
  const [npo, setNpo] = useState('')
  const [stage, setStage] = useState('')
  const [help, setHelp] = useState<string[]>([])
  const [message, setMessage] = useState('')
  const [consent, setConsent] = useState(false)
  const [errors, setErrors] = useState<FormErrors>({})
  const [status, setStatus] = useState<'idle' | 'sending' | 'sent' | 'failed'>('idle')

  const validate = (): FormErrors => ({
    name: name.trim() ? undefined : 'Enter your name.',
    email: isValidEmail(email) ? undefined : 'Enter a valid email address.',
    phone: !phone.trim() || isValidPhone(phone) ? undefined : 'Enter a valid phone number.',
    help: help.length ? undefined : 'Choose at least one kind of help.',
    consent: consent ? undefined : 'Please confirm to continue.',
  })

  const submit = async (e: FormEvent) => {
    e.preventDefault()
    const found = validate()
    setErrors(found)
    if (Object.values(found).some(Boolean)) return
    setStatus('sending')
    try {
      await api.submitHelpRequest({
        fullName: name,
        email,
        phone,
        npoName: npo,
        stage: stage || undefined,
        // Keep option order stable regardless of click order.
        helpTypes: Object.keys(HELP_TYPES).filter((k) => help.includes(k)),
        message,
      })
      setStatus('sent')
    } catch {
      setStatus('failed')
    }
  }

  if (status === 'sent') {
    return (
      <section id="request" className="card form-done" role="status">
        <Icon name="check" size={40} />
        <h2>Thank you!</h2>
        <p>We received your request and will contact you at {email.trim()}.</p>
      </section>
    )
  }

  const toggle = (k: string) => setHelp((h) => (h.includes(k) ? h.filter((x) => x !== k) : [...h, k]))

  return (
    <section id="request" className="card help-form">
      <h2>How can we help?</h2>
      <p className="muted">Share a few details and we will follow up. Fields marked * are required.</p>
      <form onSubmit={submit} noValidate>
        <div className="form-grid">
          <Field label="Full name *" error={errors.name}>
            <input value={name} onChange={(e) => setName(e.target.value)} maxLength={120} autoComplete="name" />
          </Field>
          <Field label="Email *" error={errors.email}>
            <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} maxLength={254} autoComplete="email" />
          </Field>
          <Field label="Phone" error={errors.phone}>
            <input
              type="tel"
              value={phone}
              onChange={(e) => setPhone(e.target.value.replace(/[^0-9+()\-.\s]/g, ''))}
              maxLength={32}
              autoComplete="tel"
            />
          </Field>
          <Field label="Nonprofit name">
            <input value={npo} onChange={(e) => setNpo(e.target.value)} maxLength={200} placeholder="Or the name you are planning" />
          </Field>
          <Field label="Where are you today?">
            <select value={stage} onChange={(e) => setStage(e.target.value)}>
              <option value="">Choose one</option>
              {Object.entries(STAGES).map(([k, v]) => (
                <option key={k} value={k}>
                  {v}
                </option>
              ))}
            </select>
          </Field>
        </div>

        <fieldset className="field">
          <legend>Help needed *</legend>
          <div className="chips">
            {Object.entries(HELP_TYPES).map(([k, v]) => (
              <button
                type="button"
                key={k}
                className={`chip ${help.includes(k) ? 'active' : ''}`}
                aria-pressed={help.includes(k)}
                onClick={() => toggle(k)}
              >
                {v}
              </button>
            ))}
          </div>
          {errors.help && <span className="field-error">{errors.help}</span>}
        </fieldset>

        <Field label="Tell us more">
          <textarea
            rows={5}
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            maxLength={2000}
            placeholder="What are you working on? What would help most?"
          />
        </Field>

        <label className="checkbox">
          <input type="checkbox" checked={consent} onChange={(e) => setConsent(e.target.checked)} />
          <span>I agree to be contacted about this request. *</span>
        </label>
        {errors.consent && <span className="field-error">{errors.consent}</span>}

        {status === 'failed' && (
          <p className="field-error" role="alert">
            Your request could not be sent. Check your connection and try again.
          </p>
        )}
        <button className="btn btn-primary" type="submit" disabled={status === 'sending'}>
          <Icon name="send" size={18} /> {status === 'sending' ? 'Sending…' : 'Send request'}
        </button>
      </form>
    </section>
  )
}
