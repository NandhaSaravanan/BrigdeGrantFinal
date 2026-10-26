import { useState } from 'react'
import { useSearchParams } from 'react-router-dom'

import { BarChart } from '../components/BarChart'
import { BarRow, Card, Empty, ErrorState, Loading, Segmented } from '../components/ui'
import { formatCount, formatUsd, formatUsdCompact } from '../lib/format'
import { useApi, useAsync } from '../lib/hooks'
import type { PlaceKind, RankBy } from '../lib/types'

/** Where funding is recorded, by city and ZIP code. */
export function PlacesPage() {
  const api = useApi()
  const [params, setParams] = useSearchParams()
  const kind: PlaceKind = params.get('by') === 'zip' ? 'zip' : 'city'
  const rank: RankBy = params.get('rank') === 'count' ? 'count' : 'amount'
  const [selected, setSelected] = useState(0)
  const [state, retry] = useAsync(() => api.places(kind, rank), [api, kind, rank])

  const set = (k: string, v: string | null) => {
    const next = new URLSearchParams(params)
    if (v) next.set(k, v)
    else next.delete(k)
    setParams(next, { replace: true })
    setSelected(0)
  }

  const isCity = kind === 'city'
  const value = (r: { totalAmountUsd: number; grantCount: number }) =>
    rank === 'amount' ? r.totalAmountUsd : r.grantCount
  const valueLabel = (r: { totalAmountUsd: number; grantCount: number }) =>
    rank === 'amount' ? formatUsdCompact(r.totalAmountUsd) : formatCount(r.grantCount)

  return (
    <div className="page">
      <h1 className="page-title">Places</h1>
      <div className="toolbar">
        <Segmented
          label="Group by"
          value={kind}
          options={{ city: 'City', zip: 'ZIP code' }}
          onChange={(v) => set('by', v === 'city' ? null : v)}
        />
        <Segmented
          label="Rank by"
          value={rank}
          options={{ amount: 'Amount', count: 'Count' }}
          onChange={(v) => set('rank', v === 'amount' ? null : v)}
        />
      </div>

      {state.status === 'loading' && <Loading />}
      {state.status === 'error' && <ErrorState error={state.error} onRetry={retry} />}
      {state.status === 'ready' &&
        (state.data.length === 0 ? (
          <Empty message="No locations recorded yet." />
        ) : (
          (() => {
            const rows = state.data
            const chartRows = rows.slice(0, 7)
            const sel = Math.min(selected, chartRows.length - 1)
            const title = `${rank === 'amount' ? 'Grant dollars' : 'Grants'} by ${isCity ? 'city' : 'ZIP code'}${
              rows.length > chartRows.length ? ` · top ${chartRows.length}` : ''
            }`
            const max = Math.max(...rows.map(value))
            return (
              <div className="grid-2 places">
                <Card title={title} icon="chart">
                  <p className="muted small">Select a bar to see its value.</p>
                  <BarChart
                    title={title}
                    labels={chartRows.map((r) => r.label)}
                    values={chartRows.map(value)}
                    valueLabels={chartRows.map(valueLabel)}
                    selected={sel}
                    onSelect={setSelected}
                  />
                </Card>
                <Card title={isCity ? 'All cities' : 'All ZIP codes'} icon="place">
                  {rows.map((r, i) => (
                    <BarRow
                      key={`${r.label}-${r.secondaryLabel}`}
                      rank={i + 1}
                      label={isCity ? `${r.label}, ${r.secondaryLabel}` : `${r.label} · ${r.secondaryLabel}`}
                      subtitle={[
                        `${formatCount(r.grantCount)} grants`,
                        formatUsd(r.totalAmountUsd),
                        r.medianAmountUsd != null ? `median ${formatUsdCompact(r.medianAmountUsd)}` : null,
                        `${formatCount(r.funderCount ?? 0)} funders`,
                        `${formatCount(r.recipientCount ?? 0)} recipients`,
                      ]
                        .filter(Boolean)
                        .join(' · ')}
                      valueLabel={valueLabel(r)}
                      value={value(r)}
                      max={max}
                      to={`/grants?${kind}=${encodeURIComponent(r.label)}`}
                    />
                  ))}
                </Card>
              </div>
            )
          })()
        ))}
    </div>
  )
}
