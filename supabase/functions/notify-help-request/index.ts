// Emails each new help request (from the app or the website) to the
// BridgeGrant inbox. Called by the help_requests insert trigger in
// supabase/help_request_notifications.sql with {"id": "<request id>"}.
//
// Safety: the caller only supplies an id. The function loads the row with the
// service role and "claims" it by setting notified_at, so each real request
// is emailed at most once and nobody can use this endpoint to send arbitrary
// email.
//
// Secrets (Supabase → Edge Functions → Secrets, or `supabase secrets set`):
//   RESEND_API_KEY  required — API key from https://resend.com
//   NOTIFY_EMAIL    optional — recipient (default below)
//   NOTIFY_FROM     optional — sender (default uses Resend's test sender,
//                   which can only send to the Resend account's own email)

import { createClient } from 'npm:@supabase/supabase-js@2'

const NOTIFY_EMAIL = Deno.env.get('NOTIFY_EMAIL') ?? 'nandhasaravanan2000@gmail.com'
const NOTIFY_FROM = Deno.env.get('NOTIFY_FROM') ?? 'BridgeGrant <onboarding@resend.dev>'

const HELP_TYPES: Record<string, string> = {
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

const STAGES: Record<string, string> = {
  idea: 'Just an idea',
  forming: 'Forming / incorporating',
  applying: 'Applying for tax-exempt status',
  established: 'Established nonprofit',
}

interface HelpRequestRow {
  id: string
  created_at: string
  full_name: string
  email: string
  phone: string | null
  npo_name: string | null
  stage: string | null
  help_types: string[]
  message: string | null
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

/** Escapes visitor-entered text before placing it in HTML. */
const escapeHtml = (s: string) =>
  s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!)

/** Removes line breaks so visitor text cannot add lines to the subject. */
const oneLine = (s: string) => s.replace(/[\r\n]+/g, ' ').trim()

function buildEmail(r: HelpRequestRow) {
  const help = r.help_types.map((k) => HELP_TYPES[k] ?? k).join(', ')
  const fields: [string, string][] = [
    ['Name', r.full_name],
    ['Email', r.email],
    ['Phone', r.phone ?? '—'],
    ['Nonprofit', r.npo_name ?? '—'],
    ['Stage', r.stage ? (STAGES[r.stage] ?? r.stage) : '—'],
    ['Help needed', help],
    ['Submitted', new Date(r.created_at).toUTCString()],
  ]
  const message = r.message ?? '(no message)'

  const subject = oneLine(
    `BridgeGrant help request: ${r.full_name}${r.npo_name ? ` – ${r.npo_name}` : ''}`,
  ).slice(0, 150)

  const text = [
    'New help request from BridgeGrant',
    '',
    ...fields.map(([k, v]) => `${k}: ${v}`),
    '',
    'Message:',
    message,
    '',
    'Reply to this email to contact the requester.',
  ].join('\n')

  const rows = fields
    .map(
      ([k, v]) =>
        `<tr><td style="padding:4px 12px 4px 0;color:#5f7169;vertical-align:top">${escapeHtml(k)}</td>` +
        `<td style="padding:4px 0">${escapeHtml(v)}</td></tr>`,
    )
    .join('')
  const html =
    `<div style="font-family:system-ui,sans-serif;color:#14261f">` +
    `<h2 style="color:#0d7a5f;margin:0 0 12px">New help request</h2>` +
    `<table style="border-collapse:collapse">${rows}</table>` +
    `<h3 style="margin:16px 0 4px">Message</h3>` +
    `<p style="white-space:pre-wrap;margin:0">${escapeHtml(message)}</p>` +
    `<p style="color:#5f7169;font-size:12px;margin-top:16px">Reply to this email to contact the requester.</p>` +
    `</div>`

  return { subject, text, html }
}

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } })

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json(405, { error: 'method not allowed' })

  let id: unknown
  try {
    ;({ id } = await req.json())
  } catch {
    return json(400, { error: 'invalid body' })
  }
  if (typeof id !== 'string' || !UUID.test(id)) return json(400, { error: 'invalid id' })

  const apiKey = Deno.env.get('RESEND_API_KEY')
  if (!apiKey) return json(500, { error: 'RESEND_API_KEY is not set' })

  const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: { persistSession: false, autoRefreshToken: false },
  })

  // Claim the request so it is emailed at most once.
  const { data: row, error } = await db
    .from('help_requests')
    .update({ notified_at: new Date().toISOString(), notify_error: null })
    .eq('id', id)
    .is('notified_at', null)
    .select('id, created_at, full_name, email, phone, npo_name, stage, help_types, message')
    .maybeSingle<HelpRequestRow>()
  if (error) return json(500, { error: 'could not load request' })
  if (!row) return json(200, { skipped: true })

  const { subject, text, html } = buildEmail(row)
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      from: NOTIFY_FROM,
      to: [NOTIFY_EMAIL],
      reply_to: row.email,
      subject,
      text,
      html,
    }),
  })

  if (!res.ok) {
    const detail = (await res.text()).slice(0, 500)
    // Release the claim and record why, so the email can be retried.
    await db
      .from('help_requests')
      .update({ notified_at: null, notify_error: `Resend ${res.status}: ${detail}` })
      .eq('id', id)
    return json(502, { error: 'email failed' })
  }
  return json(200, { sent: true })
})
