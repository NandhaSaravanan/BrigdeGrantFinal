import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'

import { App } from './App'
import '@fontsource-variable/manrope'

import { applyTheme, initialTheme } from './lib/hooks'
import './styles.css'
// After styles.css so the theme rules take precedence.
import './theme.css'

// Apply before first paint to avoid a flash of the wrong mode.
applyTheme(initialTheme())

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <BrowserRouter>
      <App />
    </BrowserRouter>
  </StrictMode>,
)
