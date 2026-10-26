import type { ReactNode } from 'react'
import { Link } from 'react-router-dom'

import { accentFor, describeError, formatCount, initialsOf } from '../lib/format'
import { Icon, type IconName } from './Icon'

export function Loading({ label = 'Loading grant data…' }: { label?: string }) {
  return (
    <div className="state" role="status" aria-live="polite">
      <span className="spinner" aria-hidden="true" />
      <span className="sr-only">{label}</span>
    </div>
  )
}

export function ErrorState({ error, onRetry }: { error: unknown; onRetry: () => void }) {
  return (
    <div className="state" role="alert">
      <div className="state-icon" aria-hidden="true">
        <Icon name="info" size={36} />
      </div>
      <h2>Could not load grant data</h2>
      <p>{describeError(error)}</p>
      <button className="btn btn-primary" onClick={onRetry}>
        Try again
      </button>
    </div>
  )
}

export function Empty({ message, action }: { message: string; action?: ReactNode }) {
  return (
    <div className="state">
      <div className="state-icon" aria-hidden="true">
        <Icon name="search" size={36} />
      </div>
      <h2>No matching records</h2>
      <p>{message}</p>
      {action}
    </div>
  )
}

export function Avatar({ name, size = 40 }: { name: string; size?: number }) {
  const color = accentFor(name)
  return (
    <span
      className="avatar"
      aria-hidden="true"
      style={{
        width: size,
        height: size,
        fontSize: size * 0.36,
        background: `linear-gradient(135deg, ${color}, color-mix(in srgb, ${color} 75%, black))`,
      }}
    >
      {initialsOf(name) || '?'}
    </span>
  )
}

export function Card({
  title,
  icon,
  action,
  children,
  className = '',
}: {
  title?: string
  icon?: IconName
  action?: ReactNode
  children: ReactNode
  className?: string
}) {
  return (
    <section className={`card ${className}`}>
      {title && (
        <header className="card-header">
          {icon && (
            <span className="icon-badge">
              <Icon name={icon} size={18} />
            </span>
          )}
          <h2>{title}</h2>
          {action && <div className="card-action">{action}</div>}
        </header>
      )}
      {children}
    </section>
  )
}

export function StatTile({
  label,
  value,
  caption,
  icon,
  color,
}: {
  label: string
  value: string
  caption?: string
  icon: IconName
  color: string
}) {
  return (
    <div className="card stat">
      <div className="stat-label">
        <span className="icon-badge" style={{ color, background: `color-mix(in srgb, ${color} 14%, transparent)` }}>
          <Icon name={icon} size={18} />
        </span>
        {label}
      </div>
      <div className="stat-value">{value}</div>
      {caption && <div className="muted small">{caption}</div>}
    </div>
  )
}

/** Ranked row with a horizontal bar relative to [max]. */
export function BarRow({
  rank,
  label,
  subtitle,
  valueLabel,
  value,
  max,
  to,
}: {
  rank?: number
  label: string
  subtitle?: string
  valueLabel: string
  value: number
  max: number
  /** In-app route to open when the row is clicked. */
  to?: string
}) {
  const pct = max > 0 ? Math.max(2, Math.min(100, (value / max) * 100)) : 0
  const body = (
    <>
      {rank != null && <span className={`rank ${rank <= 3 ? 'rank-top' : ''}`}>{rank}</span>}
      <span className="barrow-main">
        <span className="barrow-line">
          <span className="barrow-label">{label}</span>
          <span className="barrow-value">{valueLabel}</span>
        </span>
        {subtitle && <span className="muted small">{subtitle}</span>}
        <span className="bar-track" aria-hidden="true">
          <span className="bar-fill" style={{ width: `${value > 0 ? pct : 0}%` }} />
        </span>
      </span>
    </>
  )
  if (to) {
    return (
      <Link className="barrow" to={to}>
        {body}
      </Link>
    )
  }
  return <div className="barrow">{body}</div>
}

export function Pager({
  page,
  pageSize,
  total,
  onPage,
}: {
  page: number
  pageSize: number
  total: number
  onPage: (page: number) => void
}) {
  const pages = Math.max(1, Math.ceil(total / pageSize))
  const first = total === 0 ? 0 : page * pageSize + 1
  const last = Math.min(total, (page + 1) * pageSize)
  return (
    <nav className="pager" aria-label="Pagination">
      <span className="muted small">
        {first}–{last} of {formatCount(total)}
      </span>
      <div className="pager-controls">
        <button className="btn btn-ghost" disabled={page <= 0} onClick={() => onPage(page - 1)} aria-label="Previous page">
          ‹
        </button>
        <span>
          {page + 1} / {pages}
        </span>
        <button
          className="btn btn-ghost"
          disabled={page + 1 >= pages}
          onClick={() => onPage(page + 1)}
          aria-label="Next page"
        >
          ›
        </button>
      </div>
    </nav>
  )
}

/** Small segmented toggle. */
export function Segmented<T extends string>({
  value,
  options,
  onChange,
  label,
}: {
  value: T
  options: Record<T, string>
  onChange: (v: T) => void
  label: string
}) {
  return (
    <div className="segmented" role="group" aria-label={label}>
      {(Object.keys(options) as T[]).map((k) => (
        <button key={k} aria-pressed={k === value} className={k === value ? 'active' : ''} onClick={() => onChange(k)}>
          {options[k]}
        </button>
      ))}
    </div>
  )
}
