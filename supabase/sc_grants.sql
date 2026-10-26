-- Statewide South Carolina grant data (2020-2025) from the Python pipeline
-- (data/processed/bridgegrant.db), loaded by scripts/upload_to_supabase.py.
-- Separate from the app's own tables: the app, website and chatbot don't read
-- these. Row level security is on with no policies, so only the service role
-- (and the dashboard) can read or write them until you add a policy.
-- Safe to re-run: it drops and recreates the four sc_ tables.

begin;

drop table if exists public.sc_verification_evidence;
drop table if exists public.sc_grants;
drop table if exists public.sc_recipients;
drop table if exists public.sc_funders;

create table public.sc_funders (
    id bigint primary key,
    funder_ein text unique,
    funder_name text not null,
    funder_state text,
    funder_form_type text,
    funder_type text not null,
    years_active text,
    first_year bigint,
    last_year bigint,
    grants_all_types bigint not null,
    total_amount_all_types numeric not null,
    standard_grants bigint not null,
    standard_total_amount numeric not null,
    standard_median_grant numeric,
    standard_p25_grant numeric,
    standard_p75_grant numeric,
    standard_sc_recipients bigint not null,
    counties_served text,
    counties_served_count bigint not null,
    share_dollars_matching_gift numeric not null,
    share_dollars_individual numeric not null,
    share_dollars_in_kind numeric not null,
    likely_open_to_applicants boolean not null,
    rank_standard_grants bigint
);

create table public.sc_recipients (
    id bigint primary key,
    recipient_key text not null unique,
    recipient_ein text,
    recipient_name text,
    recipient_name_clean text,
    recipient_type text,
    recipient_city text,
    recipient_zip text,
    recipient_county text,
    county_status text,
    recipient_identity_verified boolean not null,
    recipient_exemption_revoked boolean not null
);

create table public.sc_grants (
    id bigint primary key,
    record_id text not null unique,
    funder_id bigint not null references public.sc_funders(id),
    recipient_id bigint not null references public.sc_recipients(id),
    funder_ein text,
    recipient_ein text,
    tax_year bigint not null,
    tax_year_status text not null,
    filing_id text not null,
    is_amended_return boolean not null,
    recipient_name text,
    recipient_street_address text,
    recipient_city text,
    recipient_state text not null,
    recipient_zip text,
    recipient_county text,
    county_status text not null,
    county_candidates text,
    cash_amount numeric,
    noncash_amount numeric,
    grant_amount numeric not null,
    is_mostly_noncash boolean not null,
    grant_purpose text,
    grant_type text not null,
    recipient_type text not null,
    funder_type text not null,
    source_type text not null,
    source_table text not null,
    source_url text,
    source_table_match boolean not null,
    irs_filing_check text not null,
    irs_filing_verified boolean not null,
    recipient_identity_verified boolean not null,
    sc_address_verified boolean not null,
    county_verified boolean not null,
    recipient_exemption_revoked boolean not null,
    verification_status text not null
);

create table public.sc_verification_evidence (
    id bigint primary key,
    grant_id bigint not null references public.sc_grants(id) on delete cascade,
    record_id text not null,
    check_name text not null,
    source_url text,
    check_date text not null,
    result text not null,
    notes text
);

create index sc_idx_grants_funder_ein on public.sc_grants(funder_ein);
create index sc_idx_grants_recipient_ein on public.sc_grants(recipient_ein);
create index sc_idx_grants_tax_year on public.sc_grants(tax_year);
create index sc_idx_grants_grant_amount on public.sc_grants(grant_amount);
create index sc_idx_grants_recipient_county on public.sc_grants(recipient_county);
create index sc_idx_grants_recipient_zip on public.sc_grants(recipient_zip);
create index sc_idx_grants_funder_id on public.sc_grants(funder_id);
create index sc_idx_grants_recipient_id on public.sc_grants(recipient_id);
create index sc_idx_funders_funder_ein on public.sc_funders(funder_ein);
create index sc_idx_recipients_recipient_ein on public.sc_recipients(recipient_ein);
create index sc_idx_recipients_recipient_zip on public.sc_recipients(recipient_zip);
create index sc_idx_recipients_recipient_county on public.sc_recipients(recipient_county);
create index sc_idx_evidence_grant_id on public.sc_verification_evidence(grant_id);
create index sc_idx_evidence_check_name on public.sc_verification_evidence(check_name);

alter table public.sc_funders enable row level security;
revoke all on public.sc_funders from anon, authenticated;

alter table public.sc_recipients enable row level security;
revoke all on public.sc_recipients from anon, authenticated;

alter table public.sc_grants enable row level security;
revoke all on public.sc_grants from anon, authenticated;

alter table public.sc_verification_evidence enable row level security;
revoke all on public.sc_verification_evidence from anon, authenticated;

commit;

-- Check after loading:
-- select 'grants', count(*) from public.sc_grants union all select 'funders', count(*) from public.sc_funders;
-- select pg_size_pretty(pg_database_size(current_database()));
