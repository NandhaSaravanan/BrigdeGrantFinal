import { Link, NavLink, Outlet } from 'react-router-dom'

import { useApi, useAsync, useCounty, useThemeMode } from '../lib/hooks'
import { Icon, type IconName } from './Icon'

const NAV: { to: string; label: string; icon: IconName }[] = [
  { to: '/', label: 'Home', icon: 'home' },
  { to: '/grants', label: 'Grants', icon: 'list' },
  { to: '/funders', label: 'Funders', icon: 'bank' },
  { to: '/recipients', label: 'Recipients', icon: 'people' },
  { to: '/places', label: 'Places', icon: 'place' },
  { to: '/help', label: 'Help', icon: 'heart' },
]

/** Limits the whole site to one county, or all of South Carolina. */
function CountyPicker() {
  const api = useApi()
  const { county, setCounty } = useCounty()
  // The county list is statewide, so it doesn't need to reload per county.
  const [state] = useAsync(() => api.counties(), [])
  const counties = state.status === 'ready' ? state.data : []
  return (
    <label className="county-picker" title="Counties come from the recipient's ZIP code. Grants whose ZIP crosses county lines, or is a PO box, appear only under All of South Carolina.">
      <Icon name="place" size={16} />
      <span className="sr-only">Show grants for</span>
      <select value={county ?? ''} onChange={(e) => setCounty(e.target.value || null)}>
        <option value="">All of South Carolina</option>
        {county && !counties.some((c) => c.label === county) && <option value={county}>{county}</option>}
        {counties.map((c) => (
          <option key={c.label} value={c.label}>
            {c.label}
          </option>
        ))}
      </select>
    </label>
  )
}

export function Layout() {
  const [mode, toggleMode] = useThemeMode()
  return (
    <div className="shell">
      <a className="skip-link" href="#main">
        Skip to content
      </a>
      <header className="topbar">
        <div className="topbar-inner">
          <NavLink to="/" className="brand" aria-label="BridgeGrant home">
            <img src="/logo.png" alt="" width={36} height={36} />
            <span>BridgeGrant</span>
          </NavLink>
          <nav className="nav" aria-label="Main">
            {NAV.map((n) => (
              <NavLink key={n.to} to={n.to} end={n.to === '/'} className="nav-link">
                <Icon name={n.icon} size={18} />
                <span>{n.label}</span>
              </NavLink>
            ))}
          </nav>
          <CountyPicker />
          <button
            className="btn btn-ghost icon-btn"
            onClick={toggleMode}
            aria-label={mode === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'}
            title={mode === 'dark' ? 'Light mode' : 'Dark mode'}
          >
            <Icon name={mode === 'dark' ? 'sun' : 'moon'} />
          </button>
        </div>
      </header>
      <main id="main" className="main">
        <Outlet />
      </main>
      <footer className="footer">
        <p>
          Grant records for South Carolina recipients come from IRS Form 990 Schedule I and 990-PF filings (NCCS
          e-file data, tax years 2020–2025). Counties come from ZIP codes; 2024–2025 are still incomplete.
        </p>
        <p>
          General information only, not legal or tax advice. <Link to="/privacy">Privacy Policy</Link>
        </p>
      </footer>
    </div>
  )
}
