/** One row of the `sc_grants_public` view. */
export interface Grant {
  id: string
  funder: string
  recipient: string
  amount_usd: number
  tax_year: number
  city: string
  state: string
  zip: string
  filing_id: string
  filing_url: string
  source: string
  match_evidence: string | null
  purpose: string | null
  /** From the recipient's ZIP; null when the ZIP crosses county lines or is a PO box. */
  county?: string | null
}

/** Tax years NCCS is still filling in as late returns arrive. */
export const PARTIAL_TAX_YEARS = new Set([2024, 2025])

/** A grouped row from one of the aggregate views. */
export interface Aggregate {
  label: string
  secondaryLabel?: string | null
  grantCount: number
  totalAmountUsd: number
  averageAmountUsd?: number | null
  medianAmountUsd?: number | null
  funderCount?: number | null
  recipientCount?: number | null
}

export interface Page<T> {
  items: T[]
  totalCount: number
}

export interface GrantFilters {
  q?: string
  city?: string
  zip?: string
  year?: number
  funder?: string
  recipient?: string
  min?: number
  max?: number
}

export const GRANT_SORTS = {
  amountDesc: { label: 'Amount: high to low', column: 'amount_usd', ascending: false },
  amountAsc: { label: 'Amount: low to high', column: 'amount_usd', ascending: true },
  funder: { label: 'Funder A–Z', column: 'funder', ascending: true },
  recipient: { label: 'Recipient A–Z', column: 'recipient', ascending: true },
  city: { label: 'City A–Z', column: 'city', ascending: true },
  yearDesc: { label: 'Tax year: newest', column: 'tax_year', ascending: false },
} as const

export type GrantSort = keyof typeof GRANT_SORTS

export type EntityKind = 'funder' | 'recipient'
export type PlaceKind = 'city' | 'zip'
export type RankBy = 'amount' | 'count'

export interface FilterOptions {
  cities: string[]
  years: number[]
}

/** Kinds of help; keys must match the help_requests_help_types_check constraint. */
export const HELP_TYPES: Record<string, string> = {
  start_nonprofit: 'Starting a nonprofit',
  tax_exempt_status: '501(c)(3) application',
  find_funders: 'Finding grants & funders',
  grant_writing: 'Grant writing',
  board_governance: 'Board & governance',
  fundraising: 'Fundraising & donors',
  volunteers: 'Volunteers',
  mentorship: 'Mentorship',
  other: 'Something else',
}

/** Stages; keys must match the help_requests_stage_check constraint. */
export const STAGES: Record<string, string> = {
  idea: 'Just an idea',
  forming: 'Forming / incorporating',
  applying: 'Applying for tax-exempt status',
  established: 'Established nonprofit',
}

export interface HelpRequest {
  fullName: string
  email: string
  phone?: string
  npoName?: string
  stage?: string
  helpTypes: string[]
  message?: string
}
