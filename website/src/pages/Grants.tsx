import { useEffect, useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'

import { Icon } from '../components/Icon'
import { Avatar, Empty, ErrorState, Loading, Pager } from '../components/ui'
import { formatUsd } from '../lib/format'
import { useApi, useAsync, useDebounced, useMediaQuery } from '../lib/hooks'
import { GRANT_SORTS, type Grant, type GrantFilters, type GrantSort } from '../lib/types'

const PAGE_SIZE = 25

/** Filters, sort, and page live in the URL so views can be shared. */
function readFilters(p: URLSearchParams): GrantFilters {
  const int = (k: string) => {
    const v = p.get(k)
    return v && /^\d+$/.test(v) ? Number(v) : undefined
  }
  return {
    q: p.get('q') ?? undefined,
    city: p.get('city') ?? undefined,
    zip: p.get('zip') ?? undefined,
    year: int('year'),
    funder: p.get('funder') ?? undefined,
    recipient: p.get('recipient') ?? undefined,
    min: int('min'),
    max: int('max'),
  }
}

export function GrantsPage() {
  const api = useApi()
  const wide = useMediaQuery('(min-width: 900px)')
  const [params, setParams] = useSearchParams()
  const filters = readFilters(params)
  const sortParam = params.get('sort')
  const sort: GrantSort = sortParam && sortParam in GRANT_SORTS ? (sortParam as GrantSort) : 'amountDesc'
  const page = Math.max(0, Number(params.get('page') ?? 0) || 0)

  const [search, setSearch] = useState(filters.q ?? '')
  const debounced = useDebounced(search)

  const update = (changes: Record<string, string | number | undefined | null>, keepPage = false) => {
    const next = new URLSearchParams(params)
    for (const [k, v] of Object.entries(changes)) {
      if (v === undefined || v === null || v === '') next.delete(k)
      else next.set(k, String(v))
    }
    if (!keepPage) next.delete('page')
    setParams(next, { replace: !keepPage })
  }

  useEffect(() => {
    if ((filters.q ?? '') !== debounced.trim()) update({ q: debounced.trim() })
    // Only react to the debounced search text.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [debounced])

  const [options] = useAsync(() => api.filterOptions(), [api])
  const key = params.toString()
  const [state, retry] = useAsync(() => api.grants(filters, sort, page, PAGE_SIZE), [api, key])

  const [minText, setMinText] = useState(filters.min?.toString() ?? '')
  const [maxText, setMaxText] = useState(filters.max?.toString() ?? '')
  const amountError =
    minText && maxText && Number(minText) > Number(maxText) ? 'Minimum must not exceed maximum.' : null
  const applyAmounts = () => {
    if (!amountError) update({ min: minText || undefined, max: maxText || undefined })
  }

  const activeDrill = [
    filters.funder && { key: 'funder', label: `Funder: ${filters.funder}` },
    filters.recipient && { key: 'recipient', label: `Recipient: ${filters.recipient}` },
    filters.zip && { key: 'zip', label: `ZIP: ${filters.zip}` },
  ].filter(Boolean) as { key: string; label: string }[]
  const anyFilter = [...params.keys()].some((k) => k !== 'sort' && k !== 'page')

  const clearAll = () => {
    setSearch('')
    setMinText('')
    setMaxText('')
    setParams(new URLSearchParams(sortParam ? { sort: sortParam } : {}), { replace: true })
  }

  const opts = options.status === 'ready' ? options.data : null

  return (
    <div className="page">
      <h1 className="page-title">Grant records</h1>

      <div className="card filters">
        <label className="field field-search">
          <span className="sr-only">Search</span>
          <Icon name="search" size={18} />
          <input
            type="search"
            placeholder="Search funder, recipient, or purpose"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </label>
        <div className="filter-grid">
          <label className="field">
            <span>City</span>
            <select value={filters.city ?? ''} onChange={(e) => update({ city: e.target.value })}>
              <option value="">Any city</option>
              {opts?.cities.map((c) => (
                <option key={c}>{c}</option>
              ))}
              {filters.city && opts && !opts.cities.includes(filters.city) && <option>{filters.city}</option>}
            </select>
          </label>
          <label className="field">
            <span>Tax year</span>
            <select value={filters.year ?? ''} onChange={(e) => update({ year: e.target.value })}>
              <option value="">Any year</option>
              {opts?.years.map((y) => (
                <option key={y}>{y}</option>
              ))}
            </select>
          </label>
          <label className="field">
            <span>Min amount ($)</span>
            <input
              inputMode="numeric"
              value={minText}
              onChange={(e) => setMinText(e.target.value.replace(/\D/g, ''))}
              onBlur={applyAmounts}
              onKeyDown={(e) => e.key === 'Enter' && applyAmounts()}
            />
          </label>
          <label className="field">
            <span>Max amount ($)</span>
            <input
              inputMode="numeric"
              value={maxText}
              onChange={(e) => setMaxText(e.target.value.replace(/\D/g, ''))}
              onBlur={applyAmounts}
              onKeyDown={(e) => e.key === 'Enter' && applyAmounts()}
            />
          </label>
          <label className="field">
            <span>Sort</span>
            <select value={sort} onChange={(e) => update({ sort: e.target.value === 'amountDesc' ? '' : e.target.value })}>
              {Object.entries(GRANT_SORTS).map(([k, v]) => (
                <option key={k} value={k}>
                  {v.label}
                </option>
              ))}
            </select>
          </label>
        </div>
        {amountError && (
          <p className="field-error" role="alert">
            {amountError}
          </p>
        )}
        {(activeDrill.length > 0 || anyFilter) && (
          <div className="chips">
            {activeDrill.map((c) => (
              <span key={c.key} className="chip active">
                {c.label}
                <button aria-label={`Remove ${c.label}`} onClick={() => update({ [c.key]: undefined })}>
                  ×
                </button>
              </span>
            ))}
            {anyFilter && (
              <button className="btn btn-link" onClick={clearAll}>
                Clear all filters
              </button>
            )}
          </div>
        )}
      </div>

      {state.status === 'loading' && <Loading />}
      {state.status === 'error' && <ErrorState error={state.error} onRetry={retry} />}
      {state.status === 'ready' &&
        (state.data.items.length === 0 ? (
          <Empty
            message={anyFilter ? 'Try removing a filter or changing the search.' : 'No grant records are available yet.'}
            action={
              anyFilter && (
                <button className="btn btn-primary" onClick={clearAll}>
                  Clear filters
                </button>
              )
            }
          />
        ) : (
          <>
            {wide ? <GrantTable grants={state.data.items} /> : <GrantCards grants={state.data.items} />}
            <Pager
              page={page}
              pageSize={PAGE_SIZE}
              total={state.data.totalCount}
              onPage={(p) => {
                update({ page: p || undefined }, true)
                window.scrollTo({ top: 0 })
              }}
            />
          </>
        ))}
    </div>
  )
}

function GrantCards({ grants }: { grants: Grant[] }) {
  return (
    <ul className="grant-cards">
      {grants.map((g) => (
        <li key={g.id}>
          <Link className="card grant-card" to={`/grants/${g.id}`}>
            <Avatar name={g.recipient} size={42} />
            <span className="grant-card-main">
              <strong>{g.recipient}</strong>
              <span className="muted small">From {g.funder}</span>
              {g.purpose && <em className="small">{g.purpose}</em>}
              <span className="muted small">
                <Icon name="place" size={13} /> {g.city}, {g.state} {g.zip} · {g.tax_year}
              </span>
            </span>
            <span className="amount-pill">{formatUsd(g.amount_usd)}</span>
          </Link>
        </li>
      ))}
    </ul>
  )
}

function GrantTable({ grants }: { grants: Grant[] }) {
  return (
    <div className="card table-wrap">
      <table className="table">
        <thead>
          <tr>
            <th>Recipient</th>
            <th>Funder</th>
            <th>Purpose</th>
            <th className="num">Amount</th>
            <th className="num">Year</th>
            <th>City</th>
            <th>ZIP</th>
          </tr>
        </thead>
        <tbody>
          {grants.map((g) => (
            <tr key={g.id}>
              <td>
                <Link className="cell-link" to={`/grants/${g.id}`}>
                  <Avatar name={g.recipient} size={28} />
                  <span>{g.recipient}</span>
                </Link>
              </td>
              <td className="clip">{g.funder}</td>
              <td className="clip muted">{g.purpose ?? '—'}</td>
              <td className="num strong">{formatUsd(g.amount_usd)}</td>
              <td className="num">{g.tax_year}</td>
              <td>{g.city}</td>
              <td>{g.zip}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
