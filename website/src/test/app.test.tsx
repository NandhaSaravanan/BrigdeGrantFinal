import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, describe, expect, it } from 'vitest'

import { App } from '../App'
import type { Api } from '../lib/api'
import { fakeApi, fakeGrant } from './fakeApi'

const grants = [
  fakeGrant(1, { amount_usd: 40000 }),
  fakeGrant(2, { amount_usd: 5000, city: 'Fort Mill', purpose: 'ROOF REPLACEMENT' }),
  fakeGrant(3, { funder: 'Other Fund' }),
]

function renderAt(path: string, api: Api = fakeApi(grants)) {
  return render(
    <MemoryRouter initialEntries={[path]}>
      <App api={api} />
    </MemoryRouter>,
  )
}

describe('BridgeGrant website', () => {
  beforeEach(() => localStorage.clear())

  it('home shows totals and top lists', async () => {
    renderAt('/')
    expect(await screen.findByText('$60,000')).toBeInTheDocument()
    expect(screen.getByText('Top funders by amount')).toBeInTheDocument()
    expect(screen.getByText('Tax year 2024')).toBeInTheDocument()
    // One tax year: no picker.
    expect(screen.queryByRole('group', { name: 'Tax year' })).not.toBeInTheDocument()
  })

  it('home tax-year picker switches totals', async () => {
    const user = userEvent.setup()
    renderAt('/', fakeApi([...grants, fakeGrant(4, { tax_year: 2025, amount_usd: 7000 })]))
    expect(await screen.findByText('$67,000')).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: '2025' }))
    expect(screen.getByText('$7,000')).toBeInTheDocument()
    expect(screen.getByText('Places, funders, and recipients below include all tax years.')).toBeInTheDocument()
  })

  it('shows an error state with retry', async () => {
    renderAt('/', fakeApi(grants, { fail: true }))
    expect(await screen.findByText('Could not load grant data')).toBeInTheDocument()
    expect(screen.getByText('Check your internet connection and try again.')).toBeInTheDocument()
  })

  it('grant list searches purpose and opens details', async () => {
    const user = userEvent.setup()
    renderAt('/grants')
    expect(await screen.findByText('Recipient 1')).toBeInTheDocument()
    expect(screen.getByText('1–3 of 3')).toBeInTheDocument()

    await user.type(screen.getByPlaceholderText('Search funder, recipient, or purpose'), 'roof')
    await waitFor(() => expect(screen.queryByText('Recipient 1')).not.toBeInTheDocument())
    expect(screen.getByText('Recipient 2')).toBeInTheDocument()

    await user.click(screen.getByText('Recipient 2'))
    expect(await screen.findByText('Filing ID')).toBeInTheDocument()
    expect(screen.queryByText(/verif|independently confirmed/i)).not.toBeInTheDocument()
    expect(screen.getByText('ROOF REPLACEMENT')).toBeInTheDocument()
    const link = screen.getByRole('link', { name: /Open source filing/ })
    expect(link).toHaveAttribute('href', 'https://example.org/2.xml')
    expect(link).toHaveAttribute('rel', 'noopener noreferrer')
  })

  it('drill-down filter from URL shows a removable chip and empty state', async () => {
    const user = userEvent.setup()
    renderAt('/grants?funder=Nobody')
    expect(await screen.findByText('No matching records')).toBeInTheDocument()
    expect(screen.getByText('Funder: Nobody')).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Remove Funder: Nobody' }))
    expect(await screen.findByText('Recipient 1')).toBeInTheDocument()
  })

  it('places chart highlights the tapped bar', async () => {
    const user = userEvent.setup()
    renderAt('/places')
    const rock = await screen.findByRole('button', { name: 'Rock Hill: $60K' })
    expect(rock).toHaveAttribute('aria-pressed', 'true')
    const fort = screen.getByRole('button', { name: 'Fort Mill: $5,000' })
    await user.click(fort)
    expect(fort).toHaveAttribute('aria-pressed', 'true')
    expect(within(document.querySelector('.chart-tip-row')!).getByText('$5,000')).toBeInTheDocument()
  })

  it('help form validates and submits', async () => {
    const user = userEvent.setup()
    const api = fakeApi(grants)
    renderAt('/help', api)
    await user.click(screen.getByRole('button', { name: /Send request/ }))
    expect(screen.getByText('Enter your name.')).toBeInTheDocument()
    expect(screen.getByText('Choose at least one kind of help.')).toBeInTheDocument()
    expect(api.helpRequests).toHaveLength(0)

    await user.type(screen.getByLabelText('Full name *'), 'Jordan Lee')
    await user.type(screen.getByLabelText('Email *'), 'jordan@example.org')
    await user.click(screen.getByRole('button', { name: 'Grant writing' }))
    await user.click(screen.getByRole('button', { name: 'Starting a nonprofit' }))
    await user.click(screen.getByLabelText('I agree to be contacted about this request. *'))
    await user.click(screen.getByRole('button', { name: /Send request/ }))

    expect(await screen.findByText('Thank you!')).toBeInTheDocument()
    expect(api.helpRequests[0]).toMatchObject({
      fullName: 'Jordan Lee',
      email: 'jordan@example.org',
      helpTypes: ['start_nonprofit', 'grant_writing'],
    })
  })

  it('unknown routes show not found', () => {
    renderAt('/nope')
    expect(screen.getByText('Page not found')).toBeInTheDocument()
  })

  it('switches between light (Mint) and dark mode and remembers it', async () => {
    const user = userEvent.setup()
    renderAt('/')
    await screen.findByText('$60,000')
    expect(document.documentElement.dataset.theme).toBe('light')
    await user.click(screen.getByRole('button', { name: 'Switch to dark mode' }))
    expect(document.documentElement.dataset.theme).toBe('dark')
    expect(localStorage.getItem('bridgegrant-theme')).toBe('dark')
    await user.click(screen.getByRole('button', { name: 'Switch to light mode' }))
    expect(document.documentElement.dataset.theme).toBe('light')
  })

  it('shows no verification wording on any page', async () => {
    for (const path of ['/', '/grants', '/funders', '/recipients', '/places', '/help', '/privacy']) {
      const view = renderAt(path)
      await waitFor(() => expect(screen.queryByRole('status')).not.toBeInTheDocument())
      expect(document.body.textContent ?? '').not.toMatch(/verif|independently confirmed/i)
      view.unmount()
    }
  })

  it('county picker limits every page to one county and is remembered', async () => {
    const user = userEvent.setup()
    const api = fakeApi([...grants, fakeGrant(9, { city: 'Greenville', county: 'Greenville County', amount_usd: 7000 })])
    const view = renderAt('/', api)
    expect(await screen.findByText('$67,000')).toBeInTheDocument()

    const picker = screen.getByRole('combobox', { name: 'Show grants for' })
    await waitFor(() => expect(within(picker).getByRole('option', { name: 'Greenville County' })).toBeInTheDocument())
    await user.selectOptions(picker, 'Greenville County')
    expect(await screen.findByText('$7,000', { selector: '.hero-amount' })).toBeInTheDocument()
    expect(localStorage.getItem('bridgegrant-county')).toBe('Greenville County')
    view.unmount()

    // A new visit starts in the remembered county.
    renderAt('/grants', api)
    expect(await screen.findByText('Recipient 9')).toBeInTheDocument()
    expect(screen.queryByText('Recipient 1')).not.toBeInTheDocument()
  })

  it('privacy policy page is linked from the footer', async () => {
    const user = userEvent.setup()
    renderAt('/')
    await screen.findByText('$60,000')
    await user.click(screen.getByRole('link', { name: 'Privacy Policy' }))
    expect(screen.getByRole('heading', { name: 'Privacy Policy', level: 1 })).toBeInTheDocument()
    expect(screen.getByText('Questions in the Ask tab (iPhone app)')).toBeInTheDocument()
  })
})
