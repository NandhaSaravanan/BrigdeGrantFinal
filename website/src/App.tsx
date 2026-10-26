import { useCallback, useMemo, useState } from 'react'
import { Route, Routes } from 'react-router-dom'

import { Layout } from './components/Layout'
import { GrantsApi, type Api } from './lib/api'
import { configProblem, readConfig } from './lib/config'
import { ApiContext, CountyContext, saveCounty, savedCounty } from './lib/hooks'
import { EntitiesPage } from './pages/Entities'
import { GrantDetailPage } from './pages/GrantDetail'
import { GrantsPage } from './pages/Grants'
import { HelpPage } from './pages/Help'
import { HomePage } from './pages/Home'
import { NotFoundPage } from './pages/NotFound'
import { PlacesPage } from './pages/Places'
import { PrivacyPage } from './pages/Privacy'

export function AppRoutes() {
  return (
    <Routes>
      <Route element={<Layout />}>
        <Route index element={<HomePage />} />
        <Route path="grants" element={<GrantsPage />} />
        <Route path="grants/:id" element={<GrantDetailPage />} />
        <Route path="funders" element={<EntitiesPage key="funder" kind="funder" />} />
        <Route path="recipients" element={<EntitiesPage key="recipient" kind="recipient" />} />
        <Route path="places" element={<PlacesPage />} />
        <Route path="help" element={<HelpPage />} />
        <Route path="privacy" element={<PrivacyPage />} />
        <Route path="*" element={<NotFoundPage />} />
      </Route>
    </Routes>
  )
}

/** Root component; [api] is injectable for tests. */
export function App({ api }: { api?: Api }) {
  const config = useMemo(() => readConfig(), [])
  const problem = api ? null : configProblem(config)
  const client = useMemo(() => api ?? (problem ? null : new GrantsApi(config)), [api, problem, config])
  const [county, setCountyState] = useState<string | null>(savedCounty)
  const setCounty = useCallback((c: string | null) => {
    saveCounty(c)
    setCountyState(c)
  }, [])
  // A new Api object per county makes every page reload its data.
  const scoped = useMemo(() => client?.withCounty(county) ?? null, [client, county])
  const countyValue = useMemo(() => ({ county, setCounty }), [county, setCounty])

  if (!client || !scoped) {
    return (
      <main className="config-error">
        <h1>BridgeGrant is not configured</h1>
        <p>{problem}</p>
        <p className="muted">
          Set <code>VITE_SUPABASE_URL</code> and <code>VITE_SUPABASE_ANON_KEY</code> (see <code>.env.example</code>).
        </p>
      </main>
    )
  }

  return (
    <ApiContext.Provider value={scoped}>
      <CountyContext.Provider value={countyValue}>
        <AppRoutes />
      </CountyContext.Provider>
    </ApiContext.Provider>
  )
}
