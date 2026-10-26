const currency = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'USD',
  maximumFractionDigits: 0,
})
const compactCurrency = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'USD',
  notation: 'compact',
  maximumFractionDigits: 2,
})
const count = new Intl.NumberFormat('en-US')

export const formatUsd = (n: number) => currency.format(n)

export const formatUsdCompact = (n: number) =>
  Math.abs(n) < 10000 ? currency.format(n) : compactCurrency.format(n)

export const formatCount = (n: number) => count.format(n)

/** Up to two uppercase initials from a name. */
export function initialsOf(name: string): string {
  return name
    .split(/[\s&/-]+/)
    .filter((w) => /^[A-Za-z0-9]/.test(w))
    .slice(0, 2)
    .map((w) => w[0].toUpperCase())
    .join('')
}

const ACCENTS = ['#1F6FB2', '#0E8A7E', '#B7701C', '#7A4FB5', '#B8445A', '#3F7D3A']

/** Stable accent color derived from a name. */
export function accentFor(name: string): string {
  let h = 0
  for (let i = 0; i < name.length; i++) h = (h * 31 + name.charCodeAt(i)) & 0x7fffffff
  return ACCENTS[h % ACCENTS.length]
}

/**
 * Removes characters that carry meaning in PostgREST filter syntax so user
 * search text cannot alter the query structure.
 */
export const sanitizeSearch = (input: string) =>
  input.replace(/[,()*%\\:."]/g, ' ').trim()

export const isValidEmail = (v: string) => /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(v.trim())

/** Accepts common phone formats with 7–15 digits. */
export function isValidPhone(v: string): boolean {
  const digits = v.replace(/\D/g, '')
  return /^[0-9+()\-.\s]+$/.test(v.trim()) && digits.length >= 7 && digits.length <= 15
}

/** Short, non-technical error text. Never includes request headers or keys. */
export function describeError(error: unknown): string {
  const text = error instanceof Error ? error.message : String(error)
  if (/Failed to fetch|NetworkError|network/i.test(text)) {
    return 'Check your internet connection and try again.'
  }
  if (/permission denied|42501/i.test(text)) {
    return 'The public grant data is not readable with this key.'
  }
  if (/does not exist|PGRST205/i.test(text)) {
    return 'The grant data views were not found.'
  }
  return 'Something went wrong while loading grant data.'
}
