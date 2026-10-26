import type { Api } from '../lib/api'
import type { Aggregate, Grant, HelpRequest } from '../lib/types'

export function fakeGrant(i: number, overrides: Partial<Grant> = {}): Grant {
  return {
    id: `g${i}`,
    funder: 'Example Foundation',
    recipient: `Recipient ${i}`,
    amount_usd: 15000,
    tax_year: 2024,
    city: 'Rock Hill',
    state: 'SC',
    zip: '29730',
    filing_id: `OID-${i}`,
    filing_url: `https://example.org/${i}.xml`,
    source: 'Schedule I',
    match_evidence: 'Exact filing ID + recipient name + city',
    purpose: null,
    county: 'York County',
    ...overrides,
  }
}

const summary = (label: string, rows: Grant[]): Aggregate => ({
  label,
  grantCount: rows.length,
  totalAmountUsd: rows.reduce((s, g) => s + g.amount_usd, 0),
  averageAmountUsd: 15000,
  medianAmountUsd: 15000,
  funderCount: new Set(rows.map((g) => g.funder)).size,
  recipientCount: new Set(rows.map((g) => g.recipient)).size,
})

/** In-memory Api with the same filter semantics as Supabase. */
export function fakeApi(
  all: Grant[],
  opts: { fail?: boolean; county?: string | null; helpRequests?: HelpRequest[] } = {},
): Api & { helpRequests: HelpRequest[] } {
  const helpRequests: HelpRequest[] = opts.helpRequests ?? []
  const county = opts.county ?? null
  const grants = county ? all.filter((g) => g.county === county) : all
  const guard = async <T>(v: T): Promise<T> => {
    if (opts.fail) throw new Error('Failed to fetch')
    return v
  }
  return {
    helpRequests,
    county,
    withCounty: (c) => fakeApi(all, { ...opts, county: c, helpRequests }),
    counties: () => {
      const names = [...new Set(all.map((g) => g.county).filter((c): c is string => !!c))].sort()
      return guard(names.map((c) => summary(c, all.filter((g) => g.county === c))))
    },
    grants: (f, _sort, page, pageSize) => {
      const q = (f.q ?? '').toLowerCase()
      const rows = grants.filter(
        (g) =>
          (!q ||
            g.funder.toLowerCase().includes(q) ||
            g.recipient.toLowerCase().includes(q) ||
            (g.purpose ?? '').toLowerCase().includes(q)) &&
          (!f.city || g.city === f.city) &&
          (!f.year || g.tax_year === f.year) &&
          (!f.funder || g.funder === f.funder) &&
          (f.min == null || g.amount_usd >= f.min) &&
          (f.max == null || g.amount_usd <= f.max),
      )
      return guard({ items: rows.slice(page * pageSize, (page + 1) * pageSize), totalCount: rows.length })
    },
    grant: (id) => guard(grants.find((g) => g.id === id) ?? null),
    taxYears: () => {
      const years = [...new Set(grants.map((g) => g.tax_year))].sort((a, b) => b - a)
      return guard(years.map((y) => summary(String(y), grants.filter((g) => g.tax_year === y))))
    },
    overview: () => guard(summary('All years', grants)),
    entities: (kind) =>
      guard({
        items: [{ ...summary(kind === 'funder' ? 'Example Foundation' : 'Recipient 1', grants), secondaryLabel: '123456789' }],
        totalCount: 1,
      }),
    places: () =>
      guard([
        { ...summary('Rock Hill', grants), secondaryLabel: 'SC' },
        { label: 'Fort Mill', secondaryLabel: 'SC', grantCount: 1, totalAmountUsd: 5000 },
      ]),
    filterOptions: () => guard({ cities: ['Fort Mill', 'Rock Hill'], years: [2024] }),
    submitHelpRequest: async (r) => {
      if (opts.fail) throw new Error('Failed to fetch')
      helpRequests.push(r)
    },
  }
}
