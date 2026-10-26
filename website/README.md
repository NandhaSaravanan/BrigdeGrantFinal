# BridgeGrant website

React + TypeScript (Vite) site for exploring source-matched grant records. It
reads the same public Supabase views as the BridgeGrant mobile app and stores
help requests in the insert-only `help_requests` table.

## Pages

- `/` — totals with a tax-year picker, top places, funders, and recipients
- `/grants` — search (funder, recipient, purpose), filters, sort, pagination;
  all state is in the URL so views can be shared
- `/grants/:id` — grant record with source filing link
- `/funders`, `/recipients` — ranked lists with search and paging
- `/places` — bar chart and list by city or ZIP
- `/help` — nonprofit starter steps and the help request form

## Design

Light mode is the "Mint" design (mint and white, emerald and coral accents,
Manrope font self-hosted via `@fontsource`). Dark mode uses the same dark navy
colors as the BridgeGrant app. The site follows the visitor's system setting
until they use the sun/moon button in the header; the choice is remembered.
All colors are tokens in `src/theme.css`; layout is in `src/styles.css`.

## Help request emails

Help requests are stored in Supabase `help_requests`. A database trigger calls
the `notify-help-request` Edge Function, which emails each new request (from
the website or the app) to the BridgeGrant inbox. See the main project's
`supabase/functions/notify-help-request` and
`supabase/help_request_notifications.sql`.

## Configuration

Two environment variables (publishable key only — never a service-role or
`sb_secret_` key; the site refuses to start with one):

| Variable                 | Value                                  |
| ------------------------ | -------------------------------------- |
| `VITE_SUPABASE_URL`      | `https://<project-ref>.supabase.co`    |
| `VITE_SUPABASE_ANON_KEY` | Supabase publishable (anon) key        |

For local work, copy `.env.example` to `.env.local` (git-ignored).

## Develop

```sh
npm install
npm run dev        # http://localhost:5173
npm test           # unit + page tests (no network)
npm run lint
npm run build      # type-check + production build into dist/
```

## Deploy to Vercel

1. Push the repository to GitHub, then in Vercel choose **Add New → Project**
   and import it.
2. Set **Root Directory** to `website` (if the repo root is the Flutter app).
   Framework preset: **Vite** (also set in `vercel.json`).
3. Add `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` under
   **Settings → Environment Variables** for Production and Preview.
4. Deploy. `vercel.json` sends all page routes to `index.html` (so deep links
   like `/grants/123` work) and adds security headers, including a Content
   Security Policy that only allows API calls to `*.supabase.co`.

Or from this folder with the Vercel CLI:

```sh
npx vercel           # first run links the project and makes a preview deploy
npx vercel --prod    # production deploy
```
