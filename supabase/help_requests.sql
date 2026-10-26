-- Help requests submitted from the BridgeGrant app.
-- Run once in the Supabase SQL Editor. Safe to re-run.
--
-- App users (anon key) can only INSERT the listed columns. Nobody can read,
-- update, or delete rows with the publishable key; review submissions in the
-- Supabase Table Editor or with a server-side key.

begin;

create table if not exists public.help_requests (
    id uuid primary key default gen_random_uuid(),
    created_at timestamptz not null default now(),
    full_name text not null,
    email text not null,
    phone text,
    npo_name text,
    stage text,
    help_types text[] not null,
    message text,
    consent boolean not null,
    status text not null default 'new'
);

alter table public.help_requests
    drop constraint if exists help_requests_full_name_check,
    drop constraint if exists help_requests_email_check,
    drop constraint if exists help_requests_phone_check,
    drop constraint if exists help_requests_npo_name_check,
    drop constraint if exists help_requests_stage_check,
    drop constraint if exists help_requests_help_types_check,
    drop constraint if exists help_requests_message_check,
    drop constraint if exists help_requests_consent_check,
    drop constraint if exists help_requests_status_check;

alter table public.help_requests
    add constraint help_requests_full_name_check
        check (char_length(btrim(full_name)) between 1 and 120),
    add constraint help_requests_email_check
        check (char_length(email) <= 254
               and email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
    add constraint help_requests_phone_check
        check (phone is null or (char_length(phone) <= 32
               and phone ~ '^[0-9+().[:space:]-]+$')),
    add constraint help_requests_npo_name_check
        check (npo_name is null or char_length(npo_name) <= 200),
    add constraint help_requests_stage_check
        check (stage is null
               or stage in ('idea', 'forming', 'applying', 'established')),
    add constraint help_requests_help_types_check
        check (cardinality(help_types) between 1 and 9
               and help_types <@ array[
                   'start_nonprofit', 'tax_exempt_status', 'find_funders',
                   'grant_writing', 'board_governance', 'fundraising',
                   'volunteers', 'mentorship', 'other'
               ]::text[]),
    add constraint help_requests_message_check
        check (message is null or char_length(message) <= 2000),
    add constraint help_requests_consent_check check (consent),
    add constraint help_requests_status_check
        check (status in ('new', 'contacted', 'closed'));

create index if not exists help_requests_created_at_idx
    on public.help_requests (created_at desc);

alter table public.help_requests enable row level security;

revoke all on table public.help_requests from anon, authenticated;
grant insert (full_name, email, phone, npo_name, stage, help_types, message,
              consent)
    on table public.help_requests to anon, authenticated;

drop policy if exists "App users can submit help requests"
    on public.help_requests;
create policy "App users can submit help requests"
    on public.help_requests
    for insert
    to anon, authenticated
    with check (status = 'new');

commit;
