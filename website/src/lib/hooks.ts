import { createContext, useCallback, useContext, useEffect, useState } from 'react'

import type { Api } from './api'

export const ApiContext = createContext<Api | null>(null)

export function useApi(): Api {
  const api = useContext(ApiContext)
  if (!api) throw new Error('ApiContext is missing')
  return api
}

/** The county the site is limited to (null = all of South Carolina). */
export const CountyContext = createContext<{ county: string | null; setCounty: (c: string | null) => void }>({
  county: null,
  setCounty: () => {},
})

export const useCounty = () => useContext(CountyContext)

const COUNTY_KEY = 'bridgegrant-county'

/** Last county the visitor picked, else statewide. */
export function savedCounty(): string | null {
  try {
    return localStorage.getItem(COUNTY_KEY) || null
  } catch {
    return null
  }
}

export function saveCounty(county: string | null) {
  try {
    if (county) localStorage.setItem(COUNTY_KEY, county)
    else localStorage.removeItem(COUNTY_KEY)
  } catch {
    // Ignore: the choice just won't persist.
  }
}

export type AsyncState<T> =
  | { status: 'loading' }
  | { status: 'error'; error: unknown }
  | { status: 'ready'; data: T }

/**
 * Runs [load] whenever [deps] change and returns its state plus a retry
 * function. Results from stale requests are ignored.
 */
export function useAsync<T>(load: () => Promise<T>, deps: unknown[]): [AsyncState<T>, () => void] {
  const [state, setState] = useState<AsyncState<T>>({ status: 'loading' })
  const [attempt, setAttempt] = useState(0)

  useEffect(() => {
    let active = true
    setState({ status: 'loading' })
    load().then(
      (data) => active && setState({ status: 'ready', data }),
      (error) => active && setState({ status: 'error', error }),
    )
    return () => {
      active = false
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [...deps, attempt])

  const retry = useCallback(() => setAttempt((n) => n + 1), [])
  return [state, retry]
}

/** Returns [value] after it stops changing for [ms]. */
export function useDebounced<T>(value: T, ms = 350): T {
  const [debounced, setDebounced] = useState(value)
  useEffect(() => {
    const t = setTimeout(() => setDebounced(value), ms)
    return () => clearTimeout(t)
  }, [value, ms])
  return debounced
}

/** Tracks a CSS media query; false where matchMedia is unavailable. */
export function useMediaQuery(query: string): boolean {
  const get = () => typeof window !== 'undefined' && !!window.matchMedia?.(query).matches
  const [matches, setMatches] = useState(get)
  useEffect(() => {
    const mql = window.matchMedia?.(query)
    if (!mql) return
    const onChange = () => setMatches(mql.matches)
    onChange()
    mql.addEventListener('change', onChange)
    return () => mql.removeEventListener('change', onChange)
  }, [query])
  return matches
}

export type ThemeMode = 'light' | 'dark'

const THEME_KEY = 'bridgegrant-theme'

/** Saved choice, else the system setting. Light mode is the Mint design. */
export function initialTheme(): ThemeMode {
  try {
    const saved = localStorage.getItem(THEME_KEY)
    if (saved === 'light' || saved === 'dark') return saved
  } catch {
    // Storage can be unavailable (private mode); fall back to the system.
  }
  return typeof window !== 'undefined' && window.matchMedia?.('(prefers-color-scheme: dark)').matches
    ? 'dark'
    : 'light'
}

export function applyTheme(mode: ThemeMode) {
  document.documentElement.dataset.theme = mode
  document.querySelector('meta[name="theme-color"]')?.setAttribute('content', mode === 'dark' ? '#0f141b' : '#eef7f3')
}

/** Current light/dark mode plus a toggle that applies and remembers it. */
export function useThemeMode(): [ThemeMode, () => void] {
  const [mode, setMode] = useState<ThemeMode>(initialTheme)

  useEffect(() => applyTheme(mode), [mode])

  const toggle = useCallback(() => {
    setMode((m) => {
      const next = m === 'dark' ? 'light' : 'dark'
      try {
        localStorage.setItem(THEME_KEY, next)
      } catch {
        // Ignore: the choice just won't persist.
      }
      return next
    })
  }, [])

  return [mode, toggle]
}
