import { createClient, type SupabaseClient } from '@supabase/supabase-js'

import type { AppConfig } from './config'
import { sanitizeSearch } from './format'
import {
  GRANT_SORTS,
  type Aggregate,
  type EntityKind,
  type FilterOptions,
  type Grant,
  type GrantFilters,
  type GrantSort,
  type HelpRequest,
  type Page,
  type PlaceKind,
  type RankBy,
} from './types'

type Row = Record<string, unknown>

const num = (v: unknown): number => (typeof v === 'number' ? v : Number(v ?? 0) || 0)
const optNum = (v: unknown): number | null => (v == null ? null : num(v))

function toAggregate(row: Row, labelKey: string, secondaryKey?: string): Aggregate {
  return {
    label: String(row[labelKey] ?? ''),
    secondaryLabel: secondaryKey ? (row[secondaryKey] as string | null) : undefined,
    grantCount: num(row.grant_count),
    totalAmountUsd: num(row.total_amount_usd),
    averageAmountUsd: optNum(row.average_amount_usd),
    medianAmountUsd: optNum(row.median_amount_usd),
    funderCount: optNum(row.funder_count),
    recipientCount: optNum(row.recipient_count),
  }
}

const rankColumn = (by: RankBy) => (by === 'amount' ? 'total_amount_usd' : 'grant_count')

const UNKNOWN_COUNTY = 'Unknown or multiple counties'

/**
 * Read-only access to the statewide South Carolina grant data
 * (`sc_grants_public` and `sc_aggregate`, see supabase/sc_app_views.sql),
 * plus help-request inserts. Each instance is limited to one [county]
 * (null = all of South Carolina); [withCounty] returns a copy for another.
 */
export class GrantsApi {
  private readonly client: SupabaseClient
  readonly county: string | null

  constructor(config: AppConfig | null, county: string | null = null, client?: SupabaseClient) {
    this.county = county
    // No sign-in: the site only reads public views with the publishable key.
    this.client =
      client ??
      createClient(config!.supabaseUrl, config!.supabaseKey, {
        auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
      })
  }

  withCounty(county: string | null): GrantsApi {
    return county === this.county ? this : new GrantsApi(null, county, this.client)
  }

  /** Grouped totals for this county (or statewide). */
  private aggregate(group: string, opts: { statewide?: boolean; count?: boolean } = {}) {
    return this.client.rpc(
      'sc_aggregate',
      { p_group: group, p_county: opts.statewide ? null : this.county },
      opts.count ? { count: 'exact' } : undefined,
    )
  }

  private static row(r: Row): Aggregate {
    return toAggregate(r, 'label', 'secondary_label')
  }

  /** Counties that have grants, statewide, A–Z, for the county picker. */
  async counties(): Promise<Aggregate[]> {
    const { data, error } = await this.aggregate('county', { statewide: true })
      .neq('label', UNKNOWN_COUNTY)
      .order('label', { ascending: true })
    if (error) throw new Error(error.message)
    return ((data ?? []) as Row[]).map(GrantsApi.row)
  }

  async grants(filters: GrantFilters, sort: GrantSort, page: number, pageSize: number): Promise<Page<Grant>> {
    let query = this.client.from('sc_grants_public').select('*', { count: 'exact' })
    if (this.county) query = query.eq('county', this.county)
    const q = sanitizeSearch(filters.q ?? '')
    if (q) query = query.or(`funder.ilike.*${q}*,recipient.ilike.*${q}*,purpose.ilike.*${q}*`)
    if (filters.city) query = query.eq('city', filters.city)
    if (filters.zip) query = query.eq('zip', filters.zip)
    if (filters.year) query = query.eq('tax_year', filters.year)
    if (filters.funder) query = query.eq('funder', filters.funder)
    if (filters.recipient) query = query.eq('recipient', filters.recipient)
    if (filters.min != null) query = query.gte('amount_usd', filters.min)
    if (filters.max != null) query = query.lte('amount_usd', filters.max)
    const s = GRANT_SORTS[sort]
    const from = page * pageSize
    const { data, error, count } = await query
      .order(s.column, { ascending: s.ascending })
      // Stable tie-breaker so pages never overlap.
      .order('id', { ascending: true })
      .range(from, from + pageSize - 1)
    if (error) throw new Error(error.message)
    return { items: (data ?? []) as Grant[], totalCount: count ?? 0 }
  }

  async grant(id: string): Promise<Grant | null> {
    const { data, error } = await this.client.from('sc_grants_public').select('*').eq('id', id).maybeSingle()
    if (error) throw new Error(error.message)
    return data as Grant | null
  }

  async taxYears(): Promise<Aggregate[]> {
    const { data, error } = await this.aggregate('tax_year').order('label', { ascending: false })
    if (error) throw new Error(error.message)
    return ((data ?? []) as Row[]).map(GrantsApi.row)
  }

  /** All-years summary; null if unavailable. */
  async overview(): Promise<Aggregate | null> {
    const { data, error } = await this.aggregate('overview').maybeSingle()
    if (error || !data) return null
    return GrantsApi.row(data as Row)
  }

  async entities(kind: EntityKind, by: RankBy, search: string, page: number, pageSize: number): Promise<Page<Aggregate>> {
    let query = this.aggregate(kind, { count: true })
    const q = sanitizeSearch(search)
    if (q) query = query.ilike('label', `%${q}%`)
    const from = page * pageSize
    const { data, error, count } = await query
      .order(rankColumn(by), { ascending: false })
      .order('label', { ascending: true })
      .order('secondary_label', { ascending: true, nullsFirst: false })
      .range(from, from + pageSize - 1)
    if (error) throw new Error(error.message)
    return { items: ((data ?? []) as Row[]).map(GrantsApi.row), totalCount: count ?? 0 }
  }

  async places(kind: PlaceKind, by: RankBy): Promise<Aggregate[]> {
    const { data, error } = await this.aggregate(kind)
      .order(rankColumn(by), { ascending: false })
      .order('label', { ascending: true })
      // Statewide there are hundreds of cities and ZIPs; show the leaders.
      .limit(100)
    if (error) throw new Error(error.message)
    return ((data ?? []) as Row[]).map(GrantsApi.row)
  }

  async filterOptions(): Promise<FilterOptions> {
    const [cities, years] = await Promise.all([
      this.aggregate('city').order('label', { ascending: true }),
      this.aggregate('tax_year').order('label', { ascending: false }),
    ])
    for (const r of [cities, years]) if (r.error) throw new Error(r.error.message)
    return {
      cities: [...new Set(((cities.data ?? []) as Row[]).map((r) => String(r.label)))],
      years: ((years.data ?? []) as Row[]).map((r) => num(r.label)),
    }
  }

  /** Stores a help request. The table is insert-only for site visitors. */
  async submitHelpRequest(r: HelpRequest): Promise<void> {
    const blank = (v?: string) => (v && v.trim() ? v.trim() : null)
    // No `.select()`: anon may insert but not read help requests.
    const { error } = await this.client.from('help_requests').insert({
      full_name: r.fullName.trim(),
      email: r.email.trim(),
      phone: blank(r.phone),
      npo_name: blank(r.npoName),
      stage: r.stage || null,
      help_types: r.helpTypes,
      message: blank(r.message),
      consent: true,
    })
    if (error) throw new Error(error.message)
  }
}

/** The subset of GrantsApi pages depend on; tests supply a fake. */
export type Api = Pick<
  GrantsApi,
  | 'grants'
  | 'grant'
  | 'taxYears'
  | 'overview'
  | 'entities'
  | 'places'
  | 'filterOptions'
  | 'submitHelpRequest'
  | 'county'
  | 'counties'
> & { withCounty(county: string | null): Api }
