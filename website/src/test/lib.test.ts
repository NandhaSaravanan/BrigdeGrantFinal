import { describe, expect, it } from 'vitest'

import { configProblem, looksLikeServiceRoleKey } from '../lib/config'
import { formatUsdCompact, initialsOf, isValidEmail, isValidPhone, sanitizeSearch } from '../lib/format'

const jwt = (payload: object) => `${btoa('{"alg":"HS256"}')}.${btoa(JSON.stringify(payload))}.sig`

describe('config', () => {
  it('requires both values', () => {
    expect(configProblem({ supabaseUrl: '', supabaseKey: '' })).not.toBeNull()
  })
  it('accepts publishable and anon keys', () => {
    expect(configProblem({ supabaseUrl: 'https://x.supabase.co', supabaseKey: 'sb_publishable_abc' })).toBeNull()
    expect(configProblem({ supabaseUrl: 'https://x.supabase.co', supabaseKey: jwt({ role: 'anon' }) })).toBeNull()
  })
  it('rejects secret keys and insecure URLs', () => {
    expect(looksLikeServiceRoleKey('sb_secret_abc')).toBe(true)
    expect(looksLikeServiceRoleKey(jwt({ role: 'service_role' }))).toBe(true)
    expect(configProblem({ supabaseUrl: 'http://x.supabase.co', supabaseKey: 'k' })).not.toBeNull()
  })
})

describe('format', () => {
  it('strips PostgREST filter syntax from search', () => {
    expect(sanitizeSearch('ymca),id.eq.(1')).toBe('ymca  id eq  1')
  })
  it('formats compact currency', () => {
    expect(formatUsdCompact(5000)).toBe('$5,000')
    expect(formatUsdCompact(24_200_000)).toBe('$24.2M')
  })
  it('validates contact fields', () => {
    expect(isValidEmail('a@b.org')).toBe(true)
    expect(isValidEmail('nope')).toBe(false)
    expect(isValidPhone('(803) 555-0100')).toBe(true)
    expect(isValidPhone('12')).toBe(false)
  })
  it('builds initials', () => {
    expect(initialsOf('Winthrop University Foundation')).toBe('WU')
  })
})
