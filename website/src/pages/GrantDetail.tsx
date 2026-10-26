import { Link, useNavigate, useParams } from 'react-router-dom'

import { Icon } from '../components/Icon'
import { Avatar, Card, Empty, ErrorState, Loading } from '../components/ui'
import { formatUsd } from '../lib/format'
import { useApi, useAsync } from '../lib/hooks'

/** Only open filing links that use http(s). */
function safeUrl(url: string): string | null {
  try {
    const u = new URL(url)
    return u.protocol === 'https:' || u.protocol === 'http:' ? u.toString() : null
  } catch {
    return null
  }
}

export function GrantDetailPage() {
  const { id = '' } = useParams()
  const api = useApi()
  const navigate = useNavigate()
  const [state, retry] = useAsync(() => api.grant(id), [api, id])

  if (state.status === 'loading') return <Loading />
  if (state.status === 'error') return <ErrorState error={state.error} onRetry={retry} />
  const g = state.data
  if (!g) {
    return (
      <Empty
        message="This grant record was not found."
        action={
          <Link className="btn btn-primary" to="/grants">
            Browse grants
          </Link>
        }
      />
    )
  }

  const filing = safeUrl(g.filing_url)
  const rows = (entries: [string, string | null | undefined][]) => (
    <dl className="detail-list">
      {entries
        .filter(([, v]) => v != null)
        .map(([k, v]) => (
          <div key={k}>
            <dt>{k}</dt>
            <dd>{v || '—'}</dd>
          </div>
        ))}
    </dl>
  )

  return (
    <div className="page narrow">
      <button className="btn btn-link back" onClick={() => (history.length > 1 ? navigate(-1) : navigate('/grants'))}>
        <Icon name="back" size={18} /> Back
      </button>

      <section className="hero">
        <div className="hero-title">
          <Avatar name={g.recipient} size={48} />
          <h1>{g.recipient}</h1>
        </div>
        <p className="hero-amount">{formatUsd(g.amount_usd)}</p>
        <p className="hero-sub">Reported amount, tax year {g.tax_year}</p>
        <div className="hero-pills">
          <Link className="hero-pill" to={`/grants?funder=${encodeURIComponent(g.funder)}`}>
            <Icon name="bank" size={14} /> From {g.funder}
          </Link>
          <Link className="hero-pill" to={`/grants?city=${encodeURIComponent(g.city)}`}>
            <Icon name="place" size={14} /> {g.city}, {g.state}
          </Link>
        </div>
      </section>

      <Card title="Record" icon="list">
        {rows([
          ['Funder', g.funder],
          ['Recipient', g.recipient],
          ['Purpose', g.purpose],
          ['Recorded location', `${g.city}, ${g.state} ${g.zip}`],
          ['County', g.county ?? 'Not assigned (ZIP spans counties or is a PO box)'],
          ['Tax year', String(g.tax_year)],
        ])}
      </Card>

      <Card title="Source" icon="list">
        {rows([
          ['Source', g.source],
          ['Match evidence', g.match_evidence],
          ['Filing ID', g.filing_id],
        ])}
      </Card>

      {filing && (
        <a className="btn btn-primary" href={filing} target="_blank" rel="noopener noreferrer">
          <Icon name="external" size={18} /> Open source filing (XML)
        </a>
      )}
    </div>
  )
}
