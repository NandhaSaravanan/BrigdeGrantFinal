import { Link, useSearchParams } from 'react-router-dom'

import { Icon } from '../components/Icon'
import { BarRow, Card, Empty, ErrorState, Loading, StatTile } from '../components/ui'
import { formatCount, formatUsd, formatUsdCompact } from '../lib/format'
import { useApi, useAsync, useCounty } from '../lib/hooks'
import { PARTIAL_TAX_YEARS, type Aggregate } from '../lib/types'

export function HomePage() {
  const api = useApi()
  const { county } = useCounty()
  const [params, setParams] = useSearchParams()
  const year = params.get('year')

  const [state, retry] = useAsync(async () => {
    const [years, overview, cities, funders, recipients] = await Promise.all([
      api.taxYears(),
      // Optional: totals fall back to the yearly rows if unavailable.
      api.overview(),
      api.places('city', 'amount'),
      api.entities('funder', 'amount', '', 0, 5),
      api.entities('recipient', 'amount', '', 0, 5),
    ])
    return { years, overview, cities, funders, recipients }
  }, [api])

  if (state.status === 'loading') return <Loading />
  if (state.status === 'error') return <ErrorState error={state.error} onRetry={retry} />
  const { years, overview, cities, funders, recipients } = state.data
  if (years.length === 0) return <Empty message="No grant records have been loaded yet." />

  const multiYear = years.length > 1
  const yearRow = years.find((y) => y.label === year)
  const selected: Aggregate = yearRow ??
    (multiYear ? null : years[0]) ??
    overview ?? {
      label: 'All years',
      grantCount: years.reduce((s, y) => s + y.grantCount, 0),
      totalAmountUsd: years.reduce((s, y) => s + y.totalAmountUsd, 0),
    }
  const sortedYears = [...years].sort((a, b) => b.label.localeCompare(a.label))
  const yearLabel =
    yearRow || !multiYear
      ? `Tax year ${(yearRow ?? years[0]).label}`
      : `Tax years ${sortedYears.at(-1)!.label}–${sortedYears[0].label}`

  const setYear = (y: string | null) => {
    const next = new URLSearchParams(params)
    if (y) next.set('year', y)
    else next.delete('year')
    setParams(next, { replace: true })
  }

  const top = (title: string, kind: 'funder' | 'recipient', page: typeof funders) => {
    const max = page.items[0]?.totalAmountUsd ?? 0
    return (
      <Card
        title={title}
        icon={kind === 'funder' ? 'bank' : 'people'}
        action={<Link to={`/${kind}s`}>All {formatCount(page.totalCount)}</Link>}
      >
        {page.items.map((r, i) => (
          <BarRow
            key={`${r.label}-${r.secondaryLabel ?? ''}`}
            rank={i + 1}
            label={r.label}
            subtitle={`${formatCount(r.grantCount)} grants`}
            valueLabel={formatUsdCompact(r.totalAmountUsd)}
            value={r.totalAmountUsd}
            max={max}
            to={`/grants?${kind}=${encodeURIComponent(r.label)}`}
          />
        ))}
      </Card>
    )
  }

  return (
    <div className="page">
      {multiYear && (
        <div className="chips" role="group" aria-label="Tax year">
          <span className="chips-label">Tax year</span>
          <button className={`chip ${!yearRow ? 'active' : ''}`} aria-pressed={!yearRow} onClick={() => setYear(null)}>
            All years
          </button>
          {sortedYears.map((y) => (
            <button
              key={y.label}
              className={`chip ${yearRow?.label === y.label ? 'active' : ''}`}
              aria-pressed={yearRow?.label === y.label}
              onClick={() => setYear(y.label)}
            >
              {y.label}
            </button>
          ))}
        </div>
      )}

      <section className="hero">
        <div className="hero-pills">
          <span className="hero-pill">
            <Icon name="list" size={14} /> Source-matched IRS filings
          </span>
          <span className="hero-pill">
            <Icon name="calendar" size={14} /> {yearLabel}
          </span>
          <span className="hero-pill">
            <Icon name="place" size={14} /> {county ?? 'All of South Carolina'}
          </span>
        </div>
        <p className="hero-eyebrow">Reported dollars</p>
        <h1 className="hero-amount">{formatUsd(selected.totalAmountUsd)}</h1>
        <p className="hero-sub">
          across {formatCount(selected.grantCount)} grant records matched to IRS-derived filings
        </p>
        <Link className="btn btn-hero" to={yearRow ? `/grants?year=${yearRow.label}` : '/grants'}>
          <Icon name="search" size={18} /> Explore grant records
        </Link>
      </section>

      <div className="stats">
        {selected.medianAmountUsd != null && (
          <StatTile
            icon="trend"
            color="#1F6FB2"
            label="Median grant"
            value={formatUsd(selected.medianAmountUsd)}
            caption="Typical record; amounts are skewed"
          />
        )}
        {selected.averageAmountUsd != null && (
          <StatTile
            icon="sigma"
            color="#B7701C"
            label="Average grant"
            value={formatUsd(selected.averageAmountUsd)}
            caption="Pulled up by a few large grants"
          />
        )}
        {selected.funderCount != null && (
          <StatTile
            icon="bank"
            color="#0E8A7E"
            label="Funders"
            value={formatCount(selected.funderCount)}
            caption="Distinct EINs"
          />
        )}
        {selected.recipientCount != null && (
          <StatTile
            icon="people"
            color="#7A4FB5"
            label="Recipients"
            value={formatCount(selected.recipientCount)}
            caption="By EIN, or name when no EIN"
          />
        )}
      </div>

      {yearRow && multiYear && (
        <p className="muted small">Places, funders, and recipients below include all tax years.</p>
      )}

      <div className="grid-2">
        <Card title="Where funding is recorded" icon="place" action={<Link to="/places">All places</Link>}>
          {cities.slice(0, 6).map((c, i) => (
            <BarRow
              key={c.label}
              rank={i + 1}
              label={c.label}
              subtitle={`${formatCount(c.grantCount)} grants`}
              valueLabel={formatUsdCompact(c.totalAmountUsd)}
              value={c.totalAmountUsd}
              max={cities[0]?.totalAmountUsd ?? 0}
              to={`/grants?city=${encodeURIComponent(c.label)}`}
            />
          ))}
        </Card>
        <Card title="Tax years loaded" icon="calendar">
          <ul className="plain-list">
            {sortedYears.map((y) => (
              <li key={y.label}>
                <strong>{y.label}</strong>: {formatCount(y.grantCount)} records, {formatUsd(y.totalAmountUsd)}
                {PARTIAL_TAX_YEARS.has(Number(y.label)) && ' (still incomplete)'}
              </li>
            ))}
          </ul>
          <p className="muted small">
            Tax year is a filter here, not a trend line. Recent years keep growing for 2–3 years as late IRS returns
            arrive, so lower totals there are not real declines.
          </p>
        </Card>
      </div>

      <div className="grid-2">
        {top('Top funders by amount', 'funder', funders)}
        {top('Top recipients by amount', 'recipient', recipients)}
      </div>
    </div>
  )
}
