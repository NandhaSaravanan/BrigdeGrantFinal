import { useEffect, useState } from 'react'
import { useSearchParams } from 'react-router-dom'

import { Icon } from '../components/Icon'
import { Avatar, BarRow, Empty, ErrorState, Loading, Pager, Segmented } from '../components/ui'
import { formatCount, formatUsdCompact } from '../lib/format'
import { useApi, useAsync, useDebounced } from '../lib/hooks'
import type { EntityKind, RankBy } from '../lib/types'

const PAGE_SIZE = 20

/** Ranked funders or recipients with search, sort, and pagination. */
export function EntitiesPage({ kind }: { kind: EntityKind }) {
  const api = useApi()
  const [params, setParams] = useSearchParams()
  const q = params.get('q') ?? ''
  const by: RankBy = params.get('by') === 'count' ? 'count' : 'amount'
  const page = Math.max(0, Number(params.get('page') ?? 0) || 0)
  const noun = kind === 'funder' ? 'funder' : 'recipient'

  const [search, setSearch] = useState(q)
  const debounced = useDebounced(search)

  const update = (changes: Record<string, string | undefined>, keepPage = false) => {
    const next = new URLSearchParams(params)
    for (const [k, v] of Object.entries(changes)) {
      if (!v) next.delete(k)
      else next.set(k, v)
    }
    if (!keepPage) next.delete('page')
    setParams(next, { replace: !keepPage })
  }

  useEffect(() => {
    if (q !== debounced.trim()) update({ q: debounced.trim() })
    // Only react to the debounced search text.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [debounced])

  const [state, retry] = useAsync(
    () => api.entities(kind, by, q, page, PAGE_SIZE),
    [api, kind, by, q, page],
  )

  return (
    <div className="page">
      <h1 className="page-title">{kind === 'funder' ? 'Funders' : 'Recipients'}</h1>
      <div className="toolbar">
        <label className="field field-search grow">
          <span className="sr-only">Search {noun}s</span>
          <Icon name="search" size={18} />
          <input
            type="search"
            placeholder={`Search ${noun} name`}
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </label>
        <Segmented
          label="Rank by"
          value={by}
          options={{ amount: 'Amount', count: 'Count' }}
          onChange={(v) => update({ by: v === 'amount' ? undefined : v })}
        />
      </div>

      {state.status === 'loading' && <Loading />}
      {state.status === 'error' && <ErrorState error={state.error} onRetry={retry} />}
      {state.status === 'ready' &&
        (state.data.items.length === 0 ? (
          <Empty message={`No ${noun}s match this search.`} />
        ) : (
          <>
            <ul className="entity-list">
              {state.data.items.map((r, i) => {
                const others =
                  kind === 'funder'
                    ? `${formatCount(r.recipientCount ?? 0)} recipients`
                    : `${formatCount(r.funderCount ?? 0)} funders`
                const max = by === 'amount' ? state.data.items[0].totalAmountUsd : state.data.items[0].grantCount
                return (
                  <li key={`${r.label}-${r.secondaryLabel ?? i}`} className="card entity-row">
                    <Avatar name={r.label} size={36} />
                    <BarRow
                      rank={page * PAGE_SIZE + i + 1}
                      label={r.label}
                      subtitle={[
                        `${formatCount(r.grantCount)} grants`,
                        `avg ${formatUsdCompact(r.averageAmountUsd ?? 0)}`,
                        others,
                        r.secondaryLabel ? `EIN ${r.secondaryLabel}` : null,
                      ]
                        .filter(Boolean)
                        .join(' · ')}
                      valueLabel={by === 'amount' ? formatUsdCompact(r.totalAmountUsd) : formatCount(r.grantCount)}
                      value={by === 'amount' ? r.totalAmountUsd : r.grantCount}
                      max={max}
                      to={`/grants?${kind}=${encodeURIComponent(r.label)}`}
                    />
                  </li>
                )
              })}
            </ul>
            <Pager
              page={page}
              pageSize={PAGE_SIZE}
              total={state.data.totalCount}
              onPage={(p) => {
                update({ page: p ? String(p) : undefined }, true)
                window.scrollTo({ top: 0 })
              }}
            />
          </>
        ))}
    </div>
  )
}
