import { useId } from 'react'

/**
 * Single-series vertical bar chart. Bars share one blue; the selected bar
 * turns pink and shows its value above it. Thin bars with 4px rounded tops
 * sit on a shared baseline over faint gridlines. Colors were validated for
 * colorblind separation and 3:1 contrast on light and dark cards.
 */
export function BarChart({
  title,
  labels,
  values,
  valueLabels,
  selected,
  onSelect,
}: {
  title: string
  labels: string[]
  values: number[]
  valueLabels: string[]
  selected: number
  onSelect: (i: number) => void
}) {
  const id = useId()
  const max = Math.max(0, ...values)
  const n = values.length
  // Keep the tip inside the chart over the first and last bars.
  const tipLeft = n ? ((selected + 0.5) / n) * 100 : 50
  const tipShift = tipLeft < 15 ? '0%' : tipLeft > 85 ? '-100%' : '-50%'

  return (
    <figure className="chart" aria-labelledby={`${id}-title`}>
      <figcaption id={`${id}-title`} className="sr-only">
        {title}
      </figcaption>
      <div className="chart-tip-row">
        {n > 0 && (
          <span className="chart-tip" style={{ left: `${tipLeft}%`, transform: `translateX(${tipShift})` }}>
            {valueLabels[selected]}
          </span>
        )}
      </div>
      <div className="chart-plot">
        <div className="chart-grid" aria-hidden="true">
          <span />
          <span />
          <span />
        </div>
        {values.map((v, i) => (
          <button
            key={labels[i]}
            className={`chart-col ${i === selected ? 'selected' : ''}`}
            onClick={() => onSelect(i)}
            aria-pressed={i === selected}
            aria-label={`${labels[i]}: ${valueLabels[i]}`}
          >
            <span
              className="chart-bar"
              style={{ height: max > 0 ? `${Math.max(v > 0 ? 2 : 0, (v / max) * 100)}%` : 0 }}
            />
          </button>
        ))}
      </div>
      <div className="chart-labels" aria-hidden="true">
        {labels.map((l, i) => (
          <span key={l} className={i === selected ? 'selected' : ''}>
            {l}
          </span>
        ))}
      </div>
    </figure>
  )
}
